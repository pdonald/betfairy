api     = require './lib/api'
fluent  = require './lib/fluent'
monitor = require './lib/monitor'

exports.Session       = api.Session
exports.Error         = api.Error
exports.Fluent        = fluent.Fluent
exports.MarketMonitor = monitor.MarketMonitor

exports.openSession = exports.newSession = exports.createSession = (options, cb) ->
  session = new api.Session options
  cb? session
  session

exports.login = exports.connect = (options, cb) ->
  session = new api.Session options
  session.login cb
  session

exports.Session::fluent = (cb) ->
  fluent = new fluent.Fluent @
  cb? fluent
  fluent

exports.fluent = (options, cb) ->
  session = exports.openSession options
  session.fluent cb

exports.monitor = exports.createMonitor = (options, cb) ->
  monitor = new monitor.MarketMonitor options
  cb? monitor
  monitor