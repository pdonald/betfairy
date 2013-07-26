api     = require './lib/api'
monitor = require './lib/monitor'

exports.Session = api.Session
exports.Error   = api.Error
exports.MarketMonitor  = exports.Monitor = monitor.MarketMonitor

exports.openSession = exports.newSession = exports.createSession = (options, cb) ->
  session = new api.Session options
  cb? session
  session

exports.login = exports.connect = (options, cb) ->
  session = new api.Session options
  session.login cb
  session