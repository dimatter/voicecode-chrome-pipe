config =
  host: 'localhost'
  port: 4445
  heartbeat: 10000

class WebSocketWrapper
  constructor: ->
    @heartbeat = null
    @socket = new WebSocket 'ws://' + config.host + ':' + config.port + '/'
    @alive = false
    @socket.onopen = =>
      console.info "Connected to voicecode!"
      @alive = true
      @heartbeat = setInterval =>
        @send
          type: 'heartbeat'
          parameters: {}
      , config.heartbeat
    @socket.onmessage = (event) =>
      new WebSocketRequestHandler @, event.data
    @socket.onerror = =>
      @socket.close()
    @socket.onclose = =>
      @close()

  send: (payload) ->
    if not @alive
      console.error 'Cannot send while socket is dead!'
      return
    console.info '>>>>', payload
    @socket.send JSON.stringify payload

  close: ->
    console.error 'Socket closed...'
    clearInterval @heartbeat
    @alive = false
    for attribute in ['heartbeat', 'socket']
      delete @[attribute]
    delete window.socket
    setTimeout ->
      window.socket = new WebSocketWrapper
    , config.heartbeat



window.WebSocketWrapper = WebSocketWrapper
