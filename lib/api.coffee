http   = require 'request'
async  = require 'async'
xml2js = require 'xml2js'

clone = (obj) ->
  try
    JSON.parse JSON.stringify obj
  catch err
    obj

# TODO: reconnect
# TODO: parallel requests
# TODO: timeout
# TODO: priorities
class BetfairSession
  services =
    rest: 'https://beta-api.betfair.com/rest/v1.0/'
    global: 'https://api.betfair.com/global/v3/BFGlobalService'

  constructor: (options) ->
    # Properties that describe the session
    @appKey       = options?.appKey       ? null
    @sessionToken = options?.sessionToken ? null
    @locale       = options?.locale       ? null
    @currency     = options?.currency     ? null

    # Options for this session
    @options =
      maxWeightPerRequest: options?.maxWeightPerRequest ? 200

    # It's possible to override service addresses
    services.rest   = options.services.rest   if options?.services?.rest?
    services.global = options.services.global if options?.services?.global?

  login: () =>
    login = @options     if arguments.length is 0 # no arguments, use @options
    login = @options     if arguments.length is 1 and typeof arguments[0] is 'function' # only callback, use @options
    login = arguments[0] if arguments.length is 2 # options & callback

    login                 ?= {}
    login.username         = arguments[0] if arguments.length >= 3 # username, password, callback
    login.password         = arguments[1] if arguments.length >= 3 # username, password, callback
    login.vendorSoftwareId = arguments[2] if arguments.length >= 4 # username, password, vendorId, callback
    login.productId        = arguments[3] if arguments.length >= 5 # username, password, vendorId, productId, callback
    login.locationId       = arguments[4] if arguments.length >= 6 # username, password, vendorId, productId, locationId, callback
    callback = arguments[arguments.length - 1] # callback is  always the last parameter

    # use the free api if not set
    login.productId = 82 unless login.productId? or login.vendorSoftwareId

    request =
      url: services.global
      headers: 'SOAPAction': 'login'
      body: '<?xml version="1.0" encoding="utf-8"?>' +
            '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">' +
            '    <soap:Body>' +
            '        <login xmlns="http://www.betfair.com/publicapi/v3/BFGlobalService/">' +
            '            <request>' +
            '                <username xmlns="">' + (login.username ? '') + '</username>' +
            '                <password xmlns="">' + (login.password ? '') + '</password>' +
            '                <vendorSoftwareId xmlns="">' + (login.vendorSoftwareId ? 0) + '</vendorSoftwareId>' +
            '                <productId xmlns="">' + (login.productId ? 0) + '</productId>' +
            '                <locationId xmlns="">' + (login.locationId ? 0) + '</locationId>' +
            '            </request>' +
            '        </login>' +
            '    </soap:Body>' +
            '</soap:Envelope>'

    http request, (err, response, body) =>
      return callback? 'Error making SOAP request', err, response if err
      return callback? 'Service didn\'t return 200 OK', response if response.statusCode isnt 200

      xml2js.parseString body, (err, result) =>
        return callback? 'Error parsing SOAP response', err, result, response if err
        loginResp = result?['soap:Envelope']?['soap:Body']?[0]?['n:loginResponse']?[0]?['n:Result']?[0]
        return callback? 'Invalid SOAP response', result, response if not loginResp?
        errorCode = loginResp?.errorCode?[0]?['_']
        return callback? 'Login failed', errorCode, loginResp, response if errorCode isnt 'OK'
        headerErrorCode = loginResp?.header?[0]?.errorCode?[0]?['_']
        return callback? 'Login failed', headerErrorCode, loginResp, response if headerErrorCode isnt 'OK'
        sessionToken = loginResp?.header?[0]?.sessionToken?[0]?['_']
        return callback? 'Missing session token', loginResp, response if not sessionToken?
        @sessionToken = sessionToken
        callback? null, @

    @

  listEventTypes: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listEventTypes', params, callback

  listEvents: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listEvents', params, callback

  listCompetitions: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listCompetitions', params, callback

  listCountries: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listCountries', params, callback

  listVenues: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listVenues', params, callback

  listTimeRanges: (params, callback)=>
    params = clone params
    @invokeMethod 'listTimeRanges', params, callback

  listMarketTypes: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listMarketTypes', params, callback

  listMarketCatalogue: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'listMarketCatalogue', params, callback

  listMarketCatalogueByMarketIds: (marketIds, params, doneCallback, eachCallback) =>
    params = clone params

    # All markets that were loaded by this function
    # It will be passed to the callback
    loadedMarkets = []

    # Calculate the weight of marketProjection
    weight  = 0
    weight += 2 if 'RUNNER_DESCRIPTION' in params.marketProjection
    weight += 2 if 'RUNNER_METADATA'    in params.marketProjection
    weight += 3 if 'MARKET_DESCRIPTION' in params.marketProjection

    # How many markets we can retrieve in one request
    marketsPerRequest = Math.floor @options.maxWeightPerRequest / weight

    # Split all marketId's into chunks so that the weight of each chunk is less than
    # the maximum allowed weight per one request
    chunks = splitIntoChunks marketIds, marketsPerRequest

    loadChunk = (ids, done) =>
      params.filter = marketIds: ids
      params.maxResults = marketsPerRequest

      @listMarketCatalogue params, (err, markets) =>
        if err
          eachCallback?.apply @, Array.prototype.slice.call arguments
          done arguments # Tell async that we've finished loading this chunk with an error
          return
        loadedMarkets.push market for market in markets
        eachCallback? null, markets
        done() # Tell async that we've finished loading this chunk

    # Report all loaded markets or errors when we're done
    done = (err) =>
      if err
        doneCallback.apply @, Array.prototype.slice.call err # err is all arguments from @listMarketCatalogue
      else
        doneCallback null, loadedMarkets

    # Load all chunks, 5 at a time
    async.forEachLimit chunks, 5, loadChunk, done
    @

  listMarketBook: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    params.currencyCode ?= @currency if @currency?
    @invokeMethod 'listMarketBook', params, callback

  listMarketBookAll: (marketIds, params, doneCallback, eachCallback) =>
    params = clone params

    # Loaded markets
    loadedMarkets = []

    # Calculate the weight of priceProjection
    weight  = 0
    weight += 17 if 'EX_ALL_OFFERS'  in params?.priceProjection?.priceData
    weight += 5  if 'EX_BEST_OFFERS' in params?.priceProjection?.priceData and not ('EX_ALL_OFFERS' in params?.priceProjection?.priceData)
    weight += 17 if 'EX_TRADED'      in params?.priceProjection?.priceData
    weight += 7  if 'SP_TRADED'      in params?.priceProjection?.priceData
    weight += 3  if 'SP_AVAILABLE'   in params?.priceProjection?.priceData

    # How many markets we can retrieve in one request
    marketsPerRequest = Math.floor @options.maxWeightPerRequest / weight

    # Split all marketId's into chunks so that the weight of each chunk is less than
    # the maximum allowed weight per one request
    chunks = splitIntoChunks marketIds, marketsPerRequest

    loadChunk = (ids, done) =>
      params.marketIds = ids

      @listMarketBook params, (err, markets) =>
        if err
          eachCallback?.apply @, Array.prototype.slice.call arguments
          done arguments # Tell async that we've finished loading this chunk with an error
          return
        loadedMarkets.push market for market in markets
        eachCallback? null, markets
        done() # Tell async that we've finished loading this chunk

    # Report all loaded markets or errors when we're done
    done = (err) =>
      if err
        doneCallback.apply @, Array.prototype.slice.call err # err is all arguments from @listMarketCatalogue
      else
        doneCallback null, loadedMarkets

    # Load all chunks, 5 at a time
    async.forEachLimit chunks, 5, loadChunk, done
    @

  invokeMethod: (method, params, callback) =>
    invocation =
      method: method
      params: params
      request:
        url: services.rest + method + '/'
        json: params
        headers:
          'X-Application': @appKey
          'X-Authentication': @sessionToken
          'Accept': 'application/json'
      sent: new Date()

    http.post invocation.request, (err, response, data) ->
      invocation.received = new Date()
      invocation.duration = invocation.received - invocation.sent
      invocation.response = response
      invocation.data = data

      if err or response.statusCode isnt 200
        err = new BetfairError err, response, invocation.request
        invocation.error = err

      callback?.bind?(invocation)(err, data)

    invocation

  # Splits an array into smaller arrays
  # with at most "max" number of elements in each array
  splitIntoChunks = (array, max) ->
    return [] if array.length is 0
    for i in [0..Math.ceil(array.length/max)-1]
      from = i * max
      to = from + max
      to = array.length if to >= array.length
      array[from..to-1]

class BetfairError extends Error
  constructor: (@error, @response, @request) ->
    @name = 'BetfairError'
    @message = @error

    if not @error
      switch @response.statusCode
        when 500 then @message = 'API is down'
        when 404 then @message = 'API method was not found'
        when 400 then @message = 'Bad API request'
        else          @message = @response.statusText or 'API response HTTP status code: ' + @response.statusCode

    if @response?.body?.detail?.APINGException?
      @exception = @response.body.detail.APINGException
      @message = @exception.errorCode + (if @exception.errorDetails? then ': ' + @exception.errorDetails else '')

exports.BetfairSession = BetfairSession
exports.BetfairError = BetfairError