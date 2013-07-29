async        = require 'async'
{Invocation} = require './invocation'

clone = (obj) ->
  try
    JSON.parse JSON.stringify obj
  catch err
    obj

class Session
  services =
    betting: prefix: 'SportsAPING', version: 'v1.0', url: 'https://api.betfair.com/exchange/betting/json-rpc/v1'
    account: prefix: 'AccountAPING', version: 'v1.0', url: 'https://api.betfair.com/exchange/account/json-rpc/v1'
    auth: 'https://identitysso-api.betfair.com/api/certlogin'

  constructor: (options) ->
    # Properties that describe the session
    @appKey       = options?.appKey       ? null
    @appName      = options?.appName      ? null
    @sessionToken = options?.sessionToken ? null

    # User preferences for this session
    @locale       = options?.locale       ? null
    @currency     = options?.currency     ? null

    # Connection properties
    @lastInvocationId = 0
    @throttle = {}

    # Auth details
    if options.auth?
      @auth = options.auth
    if options.username? or options.password? or options.key? or options.cert? or options.pfx? or options.passphrase?
      @auth ?= {}
      @auth.username   = options.username ? null
      @auth.password   = options.password ? null
      @auth.key        = options.key        if options.key?
      @auth.cert       = options.cert       if options.cert?
      @auth.pfx        = options.pfx        if options.pfx?
      @auth.passphrase = options.passphrase if options.passphrase?

    # Misc
    @options =
      maxWeightPerRequest: options?.maxWeightPerRequest ? 200

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
    auth = @auth        if arguments.length is 0 # no arguments, use @auth
    auth = @auth        if arguments.length is 1 and typeof arguments[0] is 'function' # only callback, use @auth
    auth = arguments[0] if arguments.length is 2 # options & callback
    callback = arguments[arguments.length - 1] if arguments.length > 0

    request =
      url: services.auth
      method: 'POST'
      headers:
        'X-Application': @appName ? ''
        'Content-Type': 'application/x-www-form-urlencoded'
        'Accept': 'application/json'
      body: 'username=' + encodeURIComponent(auth.username ? '') + '&password=' + encodeURIComponent(auth.password ? '')
    request.key = auth.key if auth.key?
    request.cert = auth.cert if auth.cert?
    request.pfx = auth.pfx if auth.pfx?
    request.passphrase = auth.passphrase if auth.passphrase?
    request.agent = false

    session = @

    invocation = new Invocation request, ++@lastInvocationId
    invocation.name = 'LoginInvocation'
    invocation.auth = auth
    invocation.processResponse = ->
      # todo: status code
      if @error?
        return
      if not @response.body?.loginStatus?
        @error = @response.error = new Error 'Invalid response', @
        return
      if @response.body.loginStatus isnt 'SUCCESS'
        @error = @response.error = new Error @response.body.loginStatus, @
        return
      if not @response.body.sessionToken?
        @error = @response.error = new Error 'No session token', @
        return
      session.sessionToken = @response.body.sessionToken
      @result = @response.body.sessionToken if not callback?
      @result = session if callback?
    invocation.execute callback if callback?
    invocation

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
    id = ++@lastInvocationId
    request =
      url: services[service].url
      method: 'POST'
      headers:
        'X-Application': @appKey
        'X-Authentication': @sessionToken
      body:
        id: id
        jsonrpc: '2.0'
        method: services[service].prefix + '/' + services[service].version + '/' + method
        params: params
    invocation = new Invocation request, id
    invocation.name = 'MethodInvocation'
    invocation.service = services[service]
    invocation.service.name = service
    invocation.method = method
    invocation.params = params
    invocation.processResponse = ->
      if @error?
        return
      if @response.body?.error?
        @error = @response.error = new Error null, @
        return
      if not @response.body?.result?
        @error = @response.error = new Error 'No result', @
        return
      @result = @response.body?.result
    invocation.execute callback.bind(invocation) if callback?
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
    else if invocation?.response?.body?.error?.data?.APINGException?
      @exception = invocation.response.body.error.data.APINGException
      @message = @exception.errorCode + (if @exception.errorDetails? then ': ' + @exception.errorDetails else '')
      @code = @exception.errorCode
    else if invocation?.response?.body?.error?.code?
      @code = invocation?.response.body.error.code
      @message = invocation?.response.body.error.message
    else if invocation?.response?.statusCode?
      @code = invocation.response.statusCode
      switch invocation.response.statusCode
        when 500 then @message = 'API is down'
        when 404 then @message = 'API method was not found'
        when 400 then @message = 'Bad API request'
        when 200 then @message = 'Weird, got 200 OK'
        else          @message = invocation.response.statusText ? 'API response HTTP status code: ' + invocation.response.statusCode

exports.Session = Session
exports.Error = Error