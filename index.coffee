api     = require './lib/api'
monitor = require './lib/monitor'

exports.BetfairSession = exports.Session = api.BetfairSession
exports.BetfairError   = exports.Error   = api.BetfairError
exports.MarketMonitor  = exports.Monitor = monitor.MarketMonitor

exports.openSession = exports.newSession = exports.createSession = (options, cb) ->
  session = new api.BetfairSession options
  cb? session
  session

exports.login = exports.connect = (options, cb) ->
  session = new api.BetfairSession options
  session.login cb
  session