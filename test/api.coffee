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

  describe 'listMarketCatalogue', ->
    session = null

    params =
      filter:
        eventTypeIds: [ 1 ]
        marketTypeCodes: [ 'MATCH_ODDS' ]
      maxResults: 10

    before (done) ->
      session = new betfairy.Session settings
      session.login settings, done

    beforeEach ->
      session.locale = null

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

    it 'should not modify params', (done) ->
      origParams = JSON.stringify params
      session.locale = 'es'
      session.listMarketCatalogue params, (err, markets) ->
        market.marketName.should.equal 'Cuotas de partido' for market in markets
        origParams.should.equal JSON.stringify params
        done()