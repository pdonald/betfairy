should   = require 'should'
betfairy = require '../index'

settings =
  username: ''
  password: ''
  appKey: ''

describe 'api', ->
  describe 'login', ->
    session = null

    beforeEach ->
      session = new betfairy.Session settings

    it 'should login with `options`', (done) ->
      session.login username: settings.username, password: settings.password, (err) ->
        should.not.exist err
        should.exist session.sessionToken
        done()

    it 'should login with function parameters', (done) ->
      session.login settings.username, settings.password, (err) ->
        should.not.exist err
        should.exist session.sessionToken
        done()

  describe 'betting', ->
    session = null

    before (done) ->
      session = new betfairy.Session settings
      session.login settings, done

    beforeEach ->
      session.locale = null
      session.currency = null

    describe 'listEventTypes', ->
      it 'should work', (done) ->
        session.listEventTypes filter: {}, (err, sports) ->
          should.not.exist err
          should.exist sports
          (sport for sport in sports when sport.eventType.name is 'Soccer').should.have.length 1
          (sport for sport in sports when sport.eventType.name is 'Tennis').should.have.length 1
          for sport in sports
            should.exist sport.marketCount
            should.exist sport.eventType
            should.exist sport.eventType.id
            should.exist sport.eventType.name
          done()

      it 'should use locale', (done) ->
        session.locale = 'it'
        session.listEventTypes filter: {}, (err, sports) ->
          should.not.exist err
          should.exist sports
          (sport for sport in sports when sport.eventType.name is 'Calcio').should.have.length 1
          done()

    describe 'listEvents', ->
      it 'should work', (done) ->
        session.listEvents filter: eventTypeIds: [ 2 ], (err, events) ->
          should.not.exist err
          should.exist events
          events.length.should.be.above 0
          for event in events
            should.exist event.marketCount
            should.exist event.event
            should.exist event.event.id
            should.exist event.event.name
            #should.exist event.event.countryCode
            #should.exist event.event.timezone
            #should.exist event.event.venue
            #should.exist event.event.openDate
          done()

    describe 'listCompetitions', ->
      it 'should work', (done) ->
        session.listCompetitions filter: eventTypeIds: [ 1 ], (err, competitions) ->
          should.not.exist err
          should.exist competitions
          competitions.length.should.be.above 0
          for competition in competitions
            should.exist competition.marketCount
            should.exist competition.competition
            should.exist competition.competition.id
            should.exist competition.competition.name
          done()

    describe 'listCountries', ->
      it 'should work', (done) ->
        session.listCountries filter: eventTypeIds: [ 1 ], (err, countries) ->
          should.not.exist err
          should.exist countries
          countries.length.should.be.above 0
          (country for country in countries when country.countryCode is 'GB').should.have.length 1
          for country in countries
            should.exist country.countryCode
            should.exist country.marketCount
          done()

    describe 'listVenues', ->
      it 'should work', (done) ->
        session.listVenues filter: {}, (err, venues) ->
          should.not.exist err
          should.exist venues
          venues.length.should.be.above 0
          for venue in venues
            should.exist venue.venue
            should.exist venue.marketCount
          done()

    describe 'listTimeRanges', ->
      it 'should work', (done) ->
        session.listTimeRanges filter: {}, granularity: 'HOURS', (err, ranges) ->
          should.not.exist err
          should.exist ranges
          ranges.length.should.be.above 0
          for range in ranges
            should.exist range.marketCount
            should.exist range.timeRange
            should.exist range.timeRange.from
            should.exist range.timeRange.to
            new Date(range.timeRange.to).should.be.above new Date(range.timeRange.from)
          done()

    describe 'listMarketTypes', ->
      it 'should work', (done) ->
        session.listMarketTypes filter: {}, (err, types) ->
          should.not.exist err
          should.exist types
          types.length.should.be.above 0
          (type for type in types when type.marketType is 'MATCH_ODDS').should.have.length 1
          for type in types
            should.exist type.marketType
            should.exist type.marketCount
          done()

      it 'should use locale but have no effect', (done) ->
        session.listMarketTypes filter: {}, locale: 'it', (err, types) ->
          should.not.exist err
          should.exist types
          (type for type in types when type.marketType is 'MATCH_ODDS').should.have.length 1
          done()

    describe 'listMarketCatalogue', ->
      params = null

      beforeEach ->
        params =
          filter:
            eventTypeIds: [ 1 ]
            marketTypeCodes: [ 'MATCH_ODDS' ]
          maxResults: 10

      it 'should work', (done) ->
        session.listMarketCatalogue params, (err, markets) ->
          should.not.exist err
          should.exist markets
          markets.should.be.an.instanceOf Array
          markets.should.have.length 10
          market.marketName.should.equal 'Match Odds' for market in markets
          done()

      it 'should use locale', (done) ->
        session.locale = 'it'
        session.listMarketCatalogue params, (err, markets) ->
          market.marketName.should.equal 'Esito Finale' for market in markets
          done()

      it 'should use prefer params locale over session locale', (done) ->
        session.locale = 'it'
        params.locale = 'es'
        session.listMarketCatalogue params, (err, markets) ->
          market.marketName.should.equal 'Cuotas de partido' for market in markets
          done()

      it 'should not modify params', (done) ->
        params.locale = 'es'
        origParams = JSON.stringify params
        session.listMarketCatalogue params, (err, markets) ->
          market.marketName.should.equal 'Cuotas de partido' for market in markets
          origParams.should.equal JSON.stringify params
          done()

  describe 'invocation', ->
    session = null

    params =
      filter:
        eventTypeIds: [ 1 ]
        marketTypeCodes: [ 'MATCH_ODDS' ]
      maxResults: 2

    before (done) ->
      session = new betfairy.Session settings
      session.login settings, done

    it 'should return invocation', (done) ->
      invocation = session.listMarketCatalogue params, (err, markets) ->
        should.not.exist err
        should.exist invocation.method
        should.exist invocation.params
        invocation.params.should.eql params
        should.exist invocation.request
        should.exist invocation.response
        should.exist invocation.sent
        should.exist invocation.received
        should.exist invocation.duration
        should.not.exist invocation.error
        should.exist invocation.data
        invocation.data.should.eql markets
        done()

    it 'should bind invocation to this', (done) ->
      session.listMarketCatalogue params, (err) ->
        should.not.exist err
        should.exist @duration
        done()