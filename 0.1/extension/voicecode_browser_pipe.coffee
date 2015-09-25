config =
  host: 'localhost'
  port: 7441
  heartbeat: 10000

class requestHandler
  validRequests = [
    'ping'
    'getState'
  ]
  constructor: (@socket, @data) ->
    @parse @data
  parse: (data) ->
    try
      {request, parameters} = JSON.parse data
      console.log request
      console.log parameters
      switch request
        when 'execute'
          {namespace, method, argumentList, callbackName, callbackArguments} = parameters
          try
            argumentList.push () =>
              if callbackArguments? and callbackArguments.length
                callbackArguments = _.object(callbackArguments, arguments)
              else
                callbackArguments = arguments

              @socket.send
                type: 'executionCallback'
                parameters: {namespace, method, callbackName, callbackArguments}
            chrome[namespace][method].apply @, argumentList
          catch error

        when 'eventListener'
          {namespace, method, callbackArguments} = parameters
          chrome[namespace][method].addListener =>
            if not @socket.alive
              chrome[namespace][method].removeListener(@)
              return

            if callbackArguments? and callbackArguments.length
              callbackArguments = _.object(callbackArguments, arguments)
            else
              callbackArguments = arguments

            @socket.send
              type: 'eventListenerCallback'
              parameters: {namespace, event: method, callbackArguments}

    catch error
      @socket.send
        type: 'error'
        parameters: {error}

class webSocketWrapper
  constructor: ->
    @heartbeat = null
    @socket = new WebSocket 'ws://' + config.host + ':' + config.port + '/'
    @alive = false
    @socket.onopen = =>
      console.log "Connected!"
      @alive = true
      @heartbeat = setInterval =>
        @send
          type: 'heartbeat'
          parameters: {}
      , config.heartbeat
    @socket.onmessage = (event) =>
      new requestHandler @, event.data
    @socket.onerror = =>
      @socket.close()
    @socket.onclose = =>
      @close()

  send: (payload) ->
    @socket.send JSON.stringify payload

  close: ->
    console.log 'Socket closed'
    clearInterval @heartbeat
    @alive = false
    for attribute in ['heartbeat', 'socket']
      delete @[attribute]
    delete window.socket
    setTimeout ->
      window.socket = new webSocketWrapper
    , config.heartbeat

window.socket = new webSocketWrapper
