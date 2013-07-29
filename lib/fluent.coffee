events = require 'events'

# todo: custom filter
# todo: result chaining => fluent.events().filter().types()

class Fluent extends events.EventEmitter
  constructor: (@session) ->
    super

    @events.types = @sports

    @markets.types = (filter, callback) =>
      if arguments.length is 1
        callback = filter
        filter = {}

      inv = @session.listMarketTypes filter: filter, (err, types) =>
        if err then return @emit 'error', err, inv
        if not Array.isArray types then types = []; @emit 'error', 'Not an array', inv # todo
        if typeof callback is 'function'
          callback.bind(inv)((result.marketType for result in types when result.marketType?))

  sports: (filter, callback) =>
    if arguments.length is 1
      callback = filter
      filter = {}

    inv = @session.listEventTypes filter: filter, (err, eventTypes) =>
      if err then return @emit 'error', err, inv
      if not Array.isArray eventTypes then eventTypes = []; @emit 'error', 'Not an array', inv # todo
      if typeof callback is 'function'
        callback.bind(inv)((result.eventType for result in eventTypes when result.eventType?))

  events: (filter, callback) =>
    if arguments.length is 1
      callback = filter
      filter = {}

    inv = @session.listEvents filter: filter, (err, events) =>
      if err then return @emit 'error', err, inv
      if not Array.isArray events then events = []; @emit 'error', 'Not an array', inv # todo
      events = (result.event for result in events when result.event?)
      for event in events when event.openDate?
        event.openDate = new Date(event.openDate)
      if typeof callback is 'function'
        callback.bind(inv) events

  competitions: (filter, callback) =>
    if arguments.length is 1
      callback = filter
      filter = {}

    inv = @session.listCompetitions filter: filter, (err, competitions) =>
      if err then return @emit 'error', err, inv
      if not Array.isArray competitions then competitions = []; @emit 'error', 'Not an array', inv # todo
      if typeof callback is 'function'
        callback.bind(inv) (result.competition for result in competitions when result.competition?)

  countries: (filter, callback) =>
    if arguments.length is 1
      callback = filter
      filter = {}

    inv = @session.listCountries filter: filter, (err, countries) =>
      if err then return @emit 'error', err, inv
      if not Array.isArray countries then countries = []; @emit 'error', 'Not an array', inv # todo
      if typeof callback is 'function'
        callback.bind(inv) (result.countryCode for result in countries)

  venues: (filter, callback) =>
    if arguments.length is 1
      callback = filter
      filter = {}

    inv = @session.listVenues filter: filter, (err, venues) =>
      if err then return @emit 'error', err, inv
      if not Array.isArray venues then venues = []; @emit 'error', 'Not an array', inv # todo
      if typeof callback is 'function'
        callback.bind(inv) (result.venue for result in venues)

  markets: (filter, callback) =>
    @

  account:
    balance: =>
    funds: =>
    details: =>

exports.Fluent = Fluent