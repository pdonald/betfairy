fs = require 'fs'

module.exports =
  username: ''
  password: ''
  appKey: ''
  key: fs.readFileSync ''
  cert: fs.readFileSync ''
