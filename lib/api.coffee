async        = require 'async'
fs           = require 'fs'
{Invocation} = require './invocation'

clone = (obj) ->
  # todo
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
    if auth.key?  then request.key  = (if Buffer.isBuffer auth.key  then auth.key  else fs.readFileSync auth.key)
    if auth.cert? then request.cert = (if Buffer.isBuffer auth.cert then auth.cert else fs.readFileSync auth.cert)
    if auth.pfx?  then request.pfx  = (if Buffer.isBuffer auth.pfx  then auth.pfx  else fs.readFileSync auth.pfx)
    if auth.passphrase? then request.passphrase = auth.passphrase
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
    invocation.execute if callback? then callback.bind(invocation) else (->)
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

  listMarketCatalogueAll: (params, doneCallback, eachCallback) =>
    # Calculate the weight of marketProjection
    weight  = 0
    if params.marketProjection?
      weight += 2 if 'RUNNER_DESCRIPTION' in params.marketProjection
      weight += 2 if 'RUNNER_METADATA'    in params.marketProjection
      weight += 3 if 'MARKET_DESCRIPTION' in params.marketProjection

    # How many markets we can retrieve in one request
    marketsPerRequest = if weight > 0 then Math.floor @options.maxWeightPerRequest / weight else 1000

    # API calls that will be made
    invocations = []
    invocations.marketsPerRequest = marketsPerRequest
    invocations.weightPerRequest = weight
    invocations.maxWeightPerRequest = @options.maxWeightPerRequest

    # All markets that will be returned
    loadedMarkets = []

    load = (filters) =>
      async.forEachLimit filters, 5, partial, (err) =>
        invocations.requests = invocations.length
        invocations.minPossibleRequests = Math.ceil loadedMarkets.length / marketsPerRequest
        invocations.overhead = invocations.requests - invocations.minPossibleRequests
        doneCallback?.call invocations, err, loadedMarkets

    partial = (filter, done) =>
      p = clone params
      p.filter[key] = value for key, value of filter
      p.maxResults = marketsPerRequest

      invocations.push @listMarketCatalogue p, (err, markets) =>
        eachCallback?.call @, err, markets
        loadedMarkets.push market for market in markets if not err
        done err

    if params.maxResults <= marketsPerRequest
      # Everything fits in one request
      load [ params.filter ]
    else if params.filter?.marketIds?.length > 0
      # Split all marketIds into several requests
      load splitIntoChunks(params.filter.marketIds, marketsPerRequest).map (ids) -> marketIds: ids
    else
      invocations.push @listEvents params, (err, events) =>
        if err then return doneCallback?.call invocations, err

        # Sort events by market count in an ascending order
        events.sort (a, b) -> a.marketCount - b.marketCount
        # Split all events with at most marketsPerRequests markets in one request
        chunks = []
        chunk = []
        chunkMarketCount = 0
        for event in events
          # todo: if event.marketCount > marketsPerRequest
          if event.marketCount > marketsPerRequest
            doneCallback?.call invocations, 'Too many markets in one event, this is not implemented yet'
            return
          if chunkMarketCount + event.marketCount > marketsPerRequest
            chunks.push chunk
            chunk = []
            chunkMarketCount = 0
          chunkMarketCount += event.marketCount
          chunk.push event.event.id
        chunks.push chunk

        load chunks.map (ids) -> eventIds: ids
    invocations

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
    marketsPerRequest = Math.floor @options.maxWeightPerRequest / weight # todo: weight = 0

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
      if @response?.body?.error?
        @error = @response.error = new Error null, @
        return
      if not @response?.body?.result?
        @error = @response.error = new Error 'No result', @
        return
      @result = @response?.body?.result
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
      @code = invocation.response.body.error.code
      @message = invocation.response.body.error.message
      if not @message?
        switch @code
          when -32700 then @message = 'Invalid JSON was received by the server. An error occurred on the server while parsing the JSON text.'
          when -32601 then @message = 'Method not found'
          when -32602 then @message = 'Problem parsing the parameters, or a mandatory parameter was not found'
          when -32603 then @message = 'Internal JSON-RPC error'
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