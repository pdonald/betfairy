betfairy = require '../'
config   = require '../config'

params =
  filter: { eventTypeIds: [ 2 ]} # Tennis
  marketProjection: [ 'MARKET_DESCRIPTION', 'RUNNER_METADATA' ]

priceParams =
  priceProjection: priceData: ['EX_ALL_OFFERS']

betfairy.login config, (err, session) ->
  if err then throw err
  session.listMarketCatalogueAll params, (err, markets) ->
    if err then throw err

    duration = @reduce ((prev, i) -> prev + i.duration), 0
    console.log "Got %d markets", markets.length
    console.log "Took %d api calls (min possible: %d, overhead: %d)", @length, @minPossibleRequests, @overhead
    console.log "Weight per api call: %d, markets per api call: %d", @weightPerRequest, @marketsPerRequest
    console.log "Time: %d ms, avg: %d ms", duration, Math.round(duration/@length)

    priceParams.marketIds = markets.map (m) -> m.marketId

    session.listMarketBookAll priceParams, (err, prices) ->
      if err then throw err
      console.log "Got prices for %d markets", prices.length
      console.log "Took %d api calls", @length
      console.log "Weight per api call: %d, markets per api call: %d", @weightPerRequest, @marketsPerRequest
      console.log "Time: %d ms, avg: %d ms", duration, Math.round(duration/@length)
