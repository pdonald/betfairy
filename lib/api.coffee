http   = require 'request'
async  = require 'async'

clone = (obj) ->
  try
    JSON.parse JSON.stringify obj
  catch err
    obj

# TODO: reconnect
# TODO: parallel requests + timeout/retries
# TODO: throttling/priorities
class Session
  services =
    betting: prefix: 'SportsAPING', version: 'v1.0', url: 'https://beta-api.betfair.com/betting/json-rpc'
    account: prefix: 'AccountAPING', version: 'v1.0', url: 'https://beta-api.betfair.com/account/json-rpc'
    auth: 'https://identitysso-api.betfair.com/api/certlogin'

  constructor: (options) ->
    # Properties that describe the session
    @appKey       = options?.appKey       ? null
    @appName      = options?.appName      ? null
    @sessionToken = options?.sessionToken ? null
    # User preferences for this session
    @locale       = options?.locale       ? null
    @currency     = options?.currency     ? null

    @lastInvocationId = 0

    # Options for this session
    @options =
      maxWeightPerRequest: options?.maxWeightPerRequest ? 200

    if options.auth?
      @auth = options.auth
    if options.username? or options.password? or options.key? or options.cert?
      @auth         ?= {}
      @auth.username = options.username ? null
      @auth.password = options.password ? null
      @auth.key      = options.key      ? null
      @auth.cert     = options.cert     ? null

    # Aliases
    @betting =
      listEventTypes: @listEventTypes
      listEvents: @listEvents
      listCompetitions: @listCompetitions
      listCountries: @listCountries
      listVenues: @listVenues
      listTimeRanges: @listTimeRanges
      listMarketTypes: @listMarketTypes
      listMarketCatalogue: @listMarketCatalogue
      invokeMethod: (method, params, callback) => @invokeMethod 'betting', method, params, callback

    @account =
      createDeveloperAppKeys: @createDeveloperAppKeys
      getDeveloperAppKeys: @getDeveloperAppKeys
      getAccountFunds: @getAccountFunds
      getAccountDetails: @getAccountDetails
      invokeMethod: (method, params, callback) => @invokeMethod 'account', method, params, callback

  login: () =>
    login = @auth        if arguments.length is 0 # no arguments, use @auth
    login = @auth        if arguments.length is 1 and typeof arguments[0] is 'function' # only callback, use @auth
    login = arguments[0] if arguments.length is 2 # options & callback
    callback = arguments[arguments.length - 1] if arguments.length > 0

    request =
      url: services.auth
      strictSSL: true
      rejectUnauthorized: true
      key: login?.key ? null
      cert: login?.cert ? null
      json: true
      headers:
        'X-Application': @appName ? ''
      form:
        username: login?.username ? ''
        password: login?.password ? ''

    http.post request, (err, response, body) =>
      return callback? new Error err, response: response if err
      return callback? new Error 'Invalid response', response: response if not body?.loginStatus?
      return callback? new Error body.loginStatus, response: response if body?.loginStatus isnt 'SUCCESS'
      return callback? new Error 'Missing sessionToken', response: response if not body?.sessionToken?
      @sessionToken = body.sessionToken
      callback? null, @

    @

  listEventTypes: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listEventTypes', params, callback

  listEvents: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listEvents', params, callback

  listCompetitions: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listCompetitions', params, callback

  listCountries: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listCountries', params, callback

  listVenues: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listVenues', params, callback

  listTimeRanges: (params, callback)=>
    params = clone params
    @invokeMethod 'betting', 'listTimeRanges', params, callback

  listMarketTypes: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listMarketTypes', params, callback

  listMarketCatalogue: (params, callback) =>
    params = clone params
    params.locale ?= @locale if @locale?
    @invokeMethod 'betting', 'listMarketCatalogue', params, callback

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
    @invokeMethod 'betting', 'listMarketBook', params, callback

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

  getAccountFunds: (callback) =>
    @invokeMethod 'account', 'getAccountFunds', null, callback

  getAccountDetails: (callback) =>
    @invokeMethod 'account', 'getAccountDetails', null, callback

  createDeveloperApp: (params, callback) =>
    @invokeMethod 'account', 'createDeveloperApp', params, callback

  getDeveloperAppKeys: (callback) =>
    @invokeMethod 'account', 'getDeveloperAppKeys', null, callback

  invokeMethod: (service, method, params, callback) =>
    @lastInvocationId += 1
    id = @lastInvocationId

    invocation =
      id: id
      service: service
      method: method
      params: params
      request:
        url: services[service].url
        strictSSL: true
        rejectUnauthorized: true
        json:
          id: id
          jsonrpc: '2.0'
          method: services[service].prefix + '/' + services[service].version + '/' + method
          params: params
        headers:
          'X-Application': @appKey
          'X-Authentication': @sessionToken
          'Accept': 'application/json'
      sent: new Date()

    http.post invocation.request, (err, response) ->
      invocation.received = new Date()
      invocation.duration = invocation.received - invocation.sent
      invocation.response = response
      invocation.responseId = response.body?.id
      invocation.result = response.body?.result

      if err or response.statusCode isnt 200 or response.body?.error?
        err = new Error err, invocation
        invocation.error = err

      callback?.bind?(invocation)(err, invocation.result)

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

class Error
  constructor: (@error, invocation) ->
    this.constructor.prototype.__proto__ = global.Error.prototype
    global.Error.call @
    global.Error.captureStackTrace this, this.constructor

    @name = 'BetfairError'

    if @error?
      @message = @error + ''
    else if invocation?.response?.body?.error?.code?
      @code = invocation?.response.body.error.code
      @message = invocation?.response.body.error.message
    else if invocation?.response?.body?.error?.APINGException?
      @exception = invocation.response.body.error.APINGException
      @message = @exception.errorCode + (if @exception.errorDetails? then ': ' + @exception.errorDetails else '')
    else
      switch invocation?.response?.statusCode
        when 500 then @message = 'API is down'
        when 404 then @message = 'API method was not found'
        when 400 then @message = 'Bad API request'
        when 200 then @message = 'Weird, got 200 OK'
        else          @message = invocation.response.statusText ? 'API response HTTP status code: ' + invocation.response.statusCode

exports.Session = Session
exports.Error = Error