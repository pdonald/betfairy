https    = require 'https'
url      = require 'url'
zlib     = require 'zlib'
{Buffer} = require 'buffer'

clone = (obj) ->
  try
    JSON.parse JSON.stringify obj
  catch err
    obj

# TODO: reconnect
# TODO: parallel requests + timeout/retries
# TODO: throttling/priorities

class Invocation
  constructor: (@request, @id) ->

  execute: (callback) =>
    done = false

    if @request.host? or @request.hostname?
      options = @request
    else
      options = url.parse @request.url
      options[key] = value for key, value of @request

    options.headers ?= {}
    options.headers['Accept-Encoding'] = 'gzip' if not @request.headers['Accept-Encoding']? and not @request.noCompression?

    if options.body? and typeof options.body isnt 'string'
      try
        options.body = JSON.stringify @request.body
        @request.bodyRaw = options.body
        options.headers['Content-Length'] = options.body.length
        #options.headers['Content-Type'] = 'application/json'
      catch e
        callback? e # todo
        return

    handleError = (err) =>
      return if done
      done = true
      @error = err
      @request.raw.abort() if @request?.raw?
      @response.raw.destroy() if @response?.raw?
      finalize()

    handleSuccess = =>
      return if done
      done = true
      finalize()

    finalize = =>
      @request.finished = new Date() if @request? and not @request.finished?
      @response.finished = new Date() if @response? and not @response.finished?
      @request.duration = @request.finished - @request.started if @request.finished?
      @response.duration = @response.finished - @response.started if @response and @response.finished?
      @duration = @response.finished - @request.started if @response?.finished? and @request.started
      @duration = @request.finished - @request.started if not @response
      result = @processResponse()
      callback? @error, result

    handleResponse = (res) =>
      return if done

      @response = {}
      @response.started = new Date()
      @response.raw = res
      @response.headers = res.headers
      @response.statusCode = res.statusCode
      @response.statusText = res.statusText

      stream = res

      if res.headers['content-encoding'] is 'gzip'
        stream = res.pipe zlib.createGunzip()
        @response.compressed = true
      else
        @response.compressed = false

      buffer = []
      length = 0
      rawLength = 0

      res.on 'data', (chunk) ->
        rawLength += chunk.length

      stream.on 'data', (chunk) ->
        return if done
        buffer.push chunk
        length += chunk.length

      stream.on 'end', =>
        return if done

        @response.finished = new Date()
        @response.bodyRaw = @response.body = Buffer.concat(buffer, length).toString()
        @response.compressionRatio = length / rawLength if @response.compressed

        if @response.headers['content-type']?.split(';')[0] is 'application/json'
          try
            @response.body = JSON.parse @response.bodyRaw
          catch e
            @response.error = e
            handleError e
            return

        handleSuccess()

      res.once 'error', (err) =>
        return if done
        @response.error = err
        handleError err
      stream.once 'error', (err) =>
        return if done
        @response.error = err
        handleError err

    if @request.timeout?
      cancel = =>
        @request.raw.abort() if @request?.raw?
        @response.raw.destroy() if @response?.raw?
        e = new Error 'ETIMEDOUT'
        e.code = 'ETIMEDOUT'
        handleError e

      setTimeout cancel, @request.timeout

    @request.started = new Date()
    @request.raw = https.request options, handleResponse
    @request.raw.setNoDelay true if not @request.noDelay? or @request.noDelay
    @request.raw.once 'error', (err) =>
      return if done
      @request.error = err
      handleError err
    @request.raw.once 'finish', =>
      return if done
      @request.finished = new Date()
    @request.raw.write options.body
    @request.raw.end()
    @

  processResponse: =>
    return if @error?
    @response.body

  multiply: (n) =>
    for i in [1..n]
      do =>
        inv = new Invocation clone @request
        inv.id = @.id + '.' + i
        inv

  race: (n, callback, each) =>
    finished = false
    done = ->
      if finished is false
        finished = true
        callback?.apply @, arguments
      each?.apply @, arguments

    for i in [1..n]
      do =>
        inv = new Invocation clone @request
        inv.id = @.id + '.' + i
        inv.execute done.bind inv
        inv

  timeout: (millis, callback) =>
    @request.timeout = millis
    @execute callback

  retry: () =>

exports.Invocation = Invocation
