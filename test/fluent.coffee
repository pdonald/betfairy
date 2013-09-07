should   = require 'should'
betfairy = require '..'
config   = require '../config'

describe 'fluent', ->
  fluent = null

  before (done) ->
    fluent = new betfairy.fluent config
    fluent.on 'error', (err) -> throw err
    fluent.session.login done

  describe 'sports', ->
    cb = (sports) ->
      should.exist sports
      sports.should.be.an.instanceOf Array
      (sport for sport in sports when sport.name is 'Soccer').should.have.length 1
      (sport for sport in sports when sport.name is 'Tennis').should.have.length 1
      for sport in sports
        should.exist sport.id
        should.exist sport.name
      should.exist @duration
      should.not.exist @error

    it 'should work without filter', (done) ->
      fluent.sports (sports) -> cb.bind(@)(sports); done()

    it 'should work with filter', (done) ->
      fluent.sports eventTypeIds: [ 1, 2 ], (sports) -> cb.bind(@)(sports); done()

  describe 'events', ->
    cb = (events) ->
      should.exist events
      events.should.be.an.instanceOf Array
      for event in events
        should.exist event.id
        should.exist event.name
      should.exist @duration
      should.not.exist @error

    it 'should work without filter', (done) ->
      fluent.events (events) -> cb.bind(@)(events); done()

    it 'should work with filter', (done) ->
      fluent.events eventTypeIds: [ 2 ], (events) -> cb.bind(@)(events); done()

  describe 'competitions', ->
    cb = (competitions) ->
      should.exist competitions
      competitions.should.be.an.instanceOf Array
      competitions.should.not.be.empty
      for comp in competitions
        should.exist comp.id
        should.exist comp.name
      should.exist @duration
      should.not.exist @error

    it 'should work without filter', (done) ->
      fluent.competitions (competitions) -> cb.bind(@)(competitions); done()

    it 'should work with filter', (done) ->
      fluent.competitions eventTypeIds: [ 1 ], (competitions) -> cb.bind(@)(competitions); done()

  describe 'countries', ->
    cb = (countries) ->
      should.exist countries
      countries.should.be.an.instanceOf Array
      countries.should.not.be.empty
      for country in countries
        country.should.have.lengthOf 2
      should.exist @duration
      should.not.exist @error

    it 'should work without filter', (done) ->
      fluent.countries (countries) -> cb.bind(@)(countries); done()

    it 'should work with filter', (done) ->
      fluent.countries eventTypeIds: [ 1 ], (countries) -> cb.bind(@)(countries); done()

  describe 'venues', ->
    cb = (venues) ->
      should.exist venues
      venues.should.be.an.instanceOf Array
      venues.should.not.be.empty
      for venue in venues
        venue.length.should.be.above 1
      should.exist @duration
      should.not.exist @error

    it 'should work without filter', (done) ->
      fluent.venues (venues) -> cb.bind(@)(venues); done()

    it 'should work with filter', (done) ->
      fluent.venues eventTypeIds: [ 7 ], (venues) ->  cb.bind(@)(venues); done()

  describe 'market types', ->
    cb = (names) ->
      should.exist names
      names.should.be.an.instanceOf Array
      names.should.not.be.empty
      should.equal true, 'MATCH_ODDS' in names

    it 'should work without filter', (done) ->
      fluent.markets.types (names) -> cb.bind(@)(names); done()

    it 'should work with filter', (done) ->
      fluent.markets.types eventTypeIds: [ 1 ], (names) -> cb.bind(@)(names); done()
