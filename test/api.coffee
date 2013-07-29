should   = require 'should'
betfairy = require '../index'
config   = require './config'

describe 'api', ->
  describe 'login', ->
    orig = config

    beforeEach -> config = JSON.parse JSON.stringify orig

    it 'should work', (done) ->
      session = new betfairy.Session config
      session.login (err, s) ->
        if err then throw err
        should.not.exist err
        should.exist s
        should.exist s.sessionToken
        s.should.equal session
        done()

    it 'should login with local options', (done) ->
      session = new betfairy.Session appKey: config.appKey
      session.login config, (err) ->
        if err then throw err
        should.not.exist err
        should.exist session.sessionToken
        done()

    it 'should work with auth key & cert paths', (done) ->
      config.key.should.be.a 'string'
      config.cert.should.be.a 'string'
      delete config.pfx
      should.not.exist config.pfx

      session = new betfairy.Session config
      session.login (err) ->
        if err then throw err
        should.exist session.sessionToken
        done()

    it 'should work with auth key & cert buffers', (done) ->
      config.key.should.be.a 'string'
      config.cert.should.be.a 'string'
      config.key = require('fs').readFileSync config.key
      config.cert = require('fs').readFileSync config.cert
      delete config.pfx
      should.not.exist config.pfx

      session = new betfairy.Session config
      session.login (err) ->
        if err then throw err
        should.exist session.sessionToken
        done()

    it 'should work with auth pfx path', (done) ->
      delete config.key
      delete config.cert
      should.not.exist config.key
      should.not.exist config.cert
      config.pfx.should.be.a 'string'

      session = new betfairy.Session config
      session.login (err) ->
        if err then throw err
        should.exist session.sessionToken
        done()

    it 'should work with auth pfx buffer', (done) ->
      delete config.key
      delete config.cert
      should.not.exist config.key
      should.not.exist config.cert
      config.pfx.should.be.a 'string'
      config.pfx = require('fs').readFileSync config.pfx

      session = new betfairy.Session config
      session.login (err) ->
        if err then throw err
        should.exist session.sessionToken
        done()

  describe 'betting', ->
    session = null

    before (done) ->
      session = new betfairy.Session config
      session.login done

    beforeEach ->
      session.locale = null
      session.currency = null

    describe 'listEventTypes', ->
      it 'should work', (done) ->
        session.listEventTypes filter: {}, (err, sports) ->
          if err then throw err
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
          if err then throw err
          should.not.exist err
          should.exist sports
          (sport for sport in sports when sport.eventType.name is 'Calcio').should.have.length 1
          done()

    describe 'listEvents', ->
      it 'should work', (done) ->
        session.listEvents filter: eventTypeIds: [ 2 ], (err, events) ->
          if err then throw err
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
          if err then throw err
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
          if err then throw err
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
          if err then throw err
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
          if err then throw err
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
          if err then throw err
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
          if err then throw err
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
          if err then throw err
          should.not.exist err
          should.exist markets
          markets.should.be.an.instanceOf Array
          markets.should.have.length 10
          market.marketName.should.include 'Match Odds' for market in markets
          done()

      it 'should use locale', (done) ->
        session.locale = 'it'
        session.listMarketCatalogue params, (err, markets) ->
          if err then throw err
          market.marketName.should.include 'Esito Finale' for market in markets
          done()

      it 'should use prefer params locale over session locale', (done) ->
        session.locale = 'it'
        params.locale = 'es'
        session.listMarketCatalogue params, (err, markets) ->
          if err then throw err
          market.marketName.should.include 'Cuotas de partido' for market in markets
          done()

      it 'should not modify params', (done) ->
        params.locale = 'es'
        origParams = JSON.stringify params
        session.listMarketCatalogue params, (err, markets) ->
          if err then throw err
          market.marketName.should.include 'Cuotas de partido' for market in markets
          origParams.should.equal JSON.stringify params
          done()

  describe 'accounts', ->
    session = null

    before (done) ->
      session = new betfairy.Session config
      session.login done

    describe 'getAccountFunds', ->
      it 'should work', (done) ->
        session.getAccountFunds (err, funds) ->
          if err then throw err
          should.not.exist err
          should.exist funds
          should.exist funds.availableToBetBalance
          funds.availableToBetBalance.should.be.a 'number'
          should.exist funds.exposure
          funds.exposure.should.be.a 'number'
          should.exist funds.retainedCommission
          funds.retainedCommission.should.be.a 'number'
          should.exist funds.exposureLimit
          funds.exposureLimit.should.be.a 'number'
          done()

    describe 'getAccountDetails', ->
      it 'should work', (done) ->
        session.getAccountDetails (err, details) ->
          if err then throw err
          should.not.exist err
          should.exist details
          should.exist details.currencyCode
          details.currencyCode.should.have.length 3
          should.exist details.firstName
          should.exist details.lastName
          should.exist details.localeCode
          details.localeCode.should.have.length 2
          should.exist details.region
          should.exist details.timezone
          should.exist details.discountRate
          details.discountRate.should.be.a 'number'
          done()

    describe 'getDeveloperAppKeys', ->
      it 'should work', (done) ->
        session.getDeveloperAppKeys (err, apps) ->
          if err then throw err
          should.not.exist err
          should.exist apps
          done()

  describe 'invocation', ->
    session = null

    params =
      filter:
        eventTypeIds: [ 1 ]
        marketTypeCodes: [ 'MATCH_ODDS' ]
      maxResults: 2

    before (done) ->
      session = new betfairy.Session config
      session.login done

    it 'should return invocation', (done) ->
      invocation = session.listMarketCatalogue params, (err, markets) ->
        if err then throw err
        should.not.exist err
        should.not.exist invocation.error
        should.exist invocation.service
        should.exist invocation.method
        should.exist invocation.params
        invocation.params.should.eql params
        should.exist invocation.request
        should.exist invocation.response
        should.exist invocation.duration
        should.not.exist invocation.error
        should.exist invocation.result
        invocation.result.should.equal markets
        done()

    it 'should bind invocation to this', (done) ->
      session.listMarketCatalogue params, (err) ->
        if err then throw err
        should.not.exist err
        should.exist @duration
        done()

    it 'should not be excuted if there is no callback', (done) ->
      invocation = session.listMarketCatalogue params
      should.exist invocation
      should.exist invocation.request
      should.exist invocation.params
      invocation.params.should.eql params
      should.not.exist invocation.response
      setTimeout (->
        should.not.exist invocation.response
        invocation.execute (err, result) ->
          if err then throw err
          should.not.exist err
          should.not.exist invocation.error
          should.exist invocation.response
          should.exist invocation.result
          invocation.result.should.equal result
          done()
      ), 500

    it 'should increase call id', (done) ->
      count = 3
      prev = null
      [1..count].forEach ->
        inv = session.listMarketCatalogue params, (err) ->
          if err then throw err
          should.not.exist err
          should.exist @id
          should.exist @response.body.id
          @id.should.equal @response.body.id
          inv.id.should.equal @id
          inv.id.should.equal @response.body.id
          count--
          done() if count is 0

        inv.id.should.equal prev + 1 if prev?
        prev = inv.id