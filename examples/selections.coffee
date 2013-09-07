betfairy = require '..'
config   = require '../config'

params =
  filter:
    eventTypeIds: [ 1 ]
    marketTypeCodes: [ 'MATCH_ODDS' ]
  marketProjection: [ 'COMPETITION', 'RUNNER_DESCRIPTION' ]

leagues = {}

session = new betfairy.Session config
session.login (err) ->
  if err then throw err
  session.listMarketCatalogueAll params, (err, markets) ->
    if err then throw err

    for market in markets
      continue unless market.competition # missing competition for this event

      league = leagues[market.competition.id] ?=
        id: market.competition.id,
        name: market.competition.name,
        selections: {}

      for selection in market.runners
        continue if selection.runnerName is 'The Draw' # ignore draw
        league.selections[selection.selectionId] = selection.runnerName

    console.log "Got everything in " + @length + " api calls"
    console.log leagues
