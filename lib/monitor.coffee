events = require 'events'
crypto = require 'crypto'

class MarketMonitor extends events.EventEmitter
  constructor: (@options) ->
    # Loaded markets
    # marketId => market
    @markets = {}
    # IDs of markets that have been removed
    # and can't be accidentally added again
    # marketId => true
    @ignored = {}
    # Subscribed markets
    # Markets for which to periodically fetch prices
    # marketId => params
    @subscriptions = {}
    # Status
    @status = 
      updated: null, # last updated 
      loading: false # loading in progress

    @session = @options.session

    @options.filter ?= {}
    @options.interval ?= -1
    @options.parallelLoadFullMarketsRequests ?= 5
    @options.timerLoopInterval ?= 100

    if @options.autoSubscribe?
      @on 'add', (market) =>
        if not @options.autoSubscribe.test? or @options.autoSubscribe.test market
          @subscribe market, @options.autoSubscribe.interval, @options.autoSubscribe.params

    for event in ['load', 'add', 'remove', 'update', 'subscribe', 'unsubscribe']
      @on event, @options.on?[event] if @options.on?[event]?

    @start() if @options.autoStart

  timerLoop: =>
    @emit 'debug:loop', 'Timer loop'

    # Get markets
    interval = @options.interval?() ? @options.interval
    timeSinceLastUpdate = new Date() - @status.updated
    if interval is 0 or (interval > 0 and (not @status.updated or timeSinceLastUpdate >= interval))
      if not @status.loading
        @status.loading = true
        @load =>
          @status.updated = new Date()
          @status.loading = false
      else
        @emit 'debug:loop', 'Skipping fetching markets because loading already in progress'
    else
      @emit 'debug:loop', "Skipping fetching markets: interval: #{interval}, since last update: #{(if @status.updated? then timeSinceLastUpdate else '-')}, update in: #{(if @status.updated? then interval-timeSinceLastUpdate else '-')}"

    # Get prices
    groups = {}
    for marketId, sub of @subscriptions when not @subscriptions[marketId].loading and not @ignored[marketId]?
      interval = sub.interval?(@markets[marketId], sub) ? sub.interval
      timeSinceLastUpdate = new Date() - sub.updated
      if interval >= 0 and (not sub.updated or timeSinceLastUpdate >= interval)
        (groups[sub.paramsKey] ?= []).push marketId

    for sub, marketIds of groups
      params = @subscriptions[marketIds[0]].params
      @emit 'debug:loop', "Fetching prices for #{marketIds.length} markets", params
      do (marketIds) =>
        @subscriptions[marketId].loading = true for marketId in marketIds # mark them as loading
        completed = => @subscriptions[marketId].loading = false for marketId in marketIds when @subscriptions[marketId]?
        partial = (err) => if not err then @subscriptions[marketId].updated = new Date() for marketId in marketIds when @subscriptions[marketId]?
        @loadPrices marketIds, params, completed, partial
    @

  subscribe: (market, interval, params, callback) =>
    paramsKey = (params) ->
      # TODO: reset values to defaults where not applicable
      s = JSON.stringify
        priceProjection:
          priceData: if params.priceProjection.priceData? then params.priceProjection.priceData?[..].sort() else []
          exBestOffersOverrides:
            bestPricesDepth: params.priceProjection.exBestOffersOverrides.bestPricesDepth ? 3
            rollupModel: params.priceProjection.rollupModel ? 'STAKE'
            rollupLimit: params.priceProjection.rollupLimit ? ''
            rollupLiabilityThreshold: params.priceProjection.rollupLiabilityThreshold ? ''
            rollupLiabilityFactor: params.priceProjection.rollupLiabilityFactor ? ''
          virtualise: params.priceProjection?.virtualise ? false
          rolloverStakes: params.priceProjection?.rolloverStakes ? false
        orderProjection: params.orderProjection ? 'ALL'
        matchProjection: params.matchProjection ? 'NO_ROLLUP'

      # create a hash so that the paramsKey is shorter
      crypto.createHash('sha1').update(s).digest('hex')

    marketId = market?.marketId ? market
    if @ignored[marketId]? then return
    if not @subscriptions[marketId]?
      @subscriptions[marketId] =
        paramsKey: ''
        updated: null
        loading: false
    if interval?
      @subscriptions[marketId].interval = interval
    if params?
      @subscriptions[marketId].params = params
      @subscriptions[marketId].paramsKey = paramsKey params
    if callback?
      @subscriptions[marketId].callback = callback

    @emit 'subscribe', marketId, @subscriptions[marketId]
    @

  unsubscribe: (market) =>
    marketId = market?.marketId ? market
    if @subscriptions[marketId]?
      @emit 'unsubscribe', marketId, @subscriptions[marketId]
      delete @subscriptions[marketId]
    @

  ignore: (market) =>
    marketId = market?.marketId ? market
    @unsubscribe marketId
    @emit 'ignore', marketId
    delete @markets[marketId]
    @ignored[marketId] = true
    @

  start: ->
    if @timer? then @stop()
    @status.loading = false
    @emit 'debug', "Started, interval: #{@options.timerLoopInterval}"
    @timer = setInterval @timerLoop, @options.timerLoopInterval
    @timerLoop()
    @

  stop: =>
    if @timer?
      clearInterval @timer
      @timer = null
      @emit 'debug', 'Stopped'
    @

  load: (callback) =>
    params =
      filter: @options.filter?() ? @options.filter ? {}
      marketProjection: [] # marketId, marketName
      maxResults: 1000 # TODO: detect if there's more

    @emit 'debug', "Loading markets (id's)", params
    # First, get just marketId (and also marketName)
    @session.listMarketCatalogue params, (err, markets) =>
      # stop() was called
      if not @timer? and @status.loading
        @emit 'debug', "Aborting load markets (id's) because the instance was stopped"
        return
      if err
        @emit 'error', err
        callback? err
        @timerLoop() if @timer?
        return

      loadedMarketIds  = (market.marketId for market in markets)
      newMarketIds     = (marketId for marketId in loadedMarketIds when not @markets[marketId]? and not @ignored[marketId]?)
      removedMarketIds = (marketId for marketId of @markets when not marketId in loadedMarketIds and not @ignored[marketId]?)
      # todo: expiredMarketIds which are not being updated right now <- ????????
      @emit 'debug', "Loaded markets (id's): #{markets.length}, new: #{newMarketIds.length}, removed: #{removedMarketIds.length}"

      # Second, get full market data
      params = marketProjection: [ 'COMPETITION', 'EVENT', 'EVENT_TYPE', 'MARKET_START_TIME', 'MARKET_DESCRIPTION', 'RUNNER_DESCRIPTION' ]
      @session.listMarketCatalogueByMarketIds newMarketIds, params, (err, fullMarkets) =>
        # stop() was called
        if not @timer? and @status.loading
          @emit 'debug', 'Aborting load markets (data) because the instance was stopped'
          return
        if err
          @emit 'error', err
          callback? err
          @timerLoop() if @timer?
          return

        # Add new markets first
        # so that 'load' event listeners can access them
        for market in fullMarkets
          @markets[market.marketId] = market
          @emit 'add', market, market.marketId

        # Announce that we've loaded all markets
        @emit 'load', @markets, newMarketIds, removedMarketIds

        # Remove closed markets last
        # after 'load' event listeners have had their chance to access them
        for marketId in removedMarketIds
          @emit 'remove', @markets[marketId], marketId

        callback? null, @markets, newMarketIds, removedMarketIds
        @timerLoop() if @timer?

  loadPrices: (markets, params, callback, partialCallback) =>
    # markets can be an array of market or an array of ids
    marketIds = ((if market.marketId? then market.marketId else market) for market in markets)

    partial = (err, markets) =>
      # todo: stop() was called
      #if not @timer? and @status.loading
        #@emit 'debug', 'Aborting fetching prices because the instance was stopped'
        #return
      if err
        @emit 'error', err
        partialCallback? err
        return

      @emit 'debug', "Fetched prices (partial) for #{markets.length} markets"

      partialCallback? null, markets

      for marketPrices in markets when @markets[marketPrices.marketId]?
        marketId = marketPrices.marketId
        prevPrices = @markets[marketId].prices
        @markets[marketId].prices = marketPrices
        @emit 'update', @markets[marketId].prices, prevPrices, @markets[marketId], @subscriptions[marketId]

    completed = (err, markets) =>
      # todo: stop() was called
      if err
        @emit 'error', err
        callback? err, markets
        @timerLoop() if @timer?
        return

      @emit 'debug', "Fetched prices for #{markets.length} markets"
      callback? null, markets
      @timerLoop() if @timer?

    @session.listMarketBookAll marketIds, params, completed, partial
    @

exports.MarketMonitor = MarketMonitor