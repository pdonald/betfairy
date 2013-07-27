api     = require './lib/api'
monitor = require './lib/monitor'

exports.Session        = api.Session
exports.Error          = api.Error
exports.MarketMonitor  = monitor.MarketMonitor

exports.openSession = exports.newSession = exports.createSession = (options, cb) ->
  session = new api.Session options
  cb? session
  session

exports.login = exports.connect = (options, cb) ->
  session = new api.Session options
  session.login cb
  session

exports.monitor = exports.createMonitor = (options, cb) ->
  monitor = new monitor.MarketMonitor options
  cb? monitor
  monitor