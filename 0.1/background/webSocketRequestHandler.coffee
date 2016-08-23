class WebSocketRequestHandler
  constructor: (@socket, data) ->
    @parse data
  parse: (data) ->
    try
      data = JSON.parse data
      console.info '<<<<', data
      {request, parameters} = data
      # console.log request
      # console.log parameters
      switch request
        when 'backgroundMethod'
          {method, argumentsObject} = parameters
          vc[method].call @, argumentsObject

        when 'tabMessage'
          {tabId, message, callbackName, callbackArguments} = parameters
          chrome.tabs.sendMessage tabId, message, () =>
            return false unless callbackName?
            if callbackArguments? and callbackArguments.length
              _callbackArguments = _.object(callbackArguments, _.toArray arguments)
            else
              _callbackArguments = _.toArray arguments

            @socket.send
              type: 'tabMessageCallback'
              parameters: {tabId, callbackName, callbackArguments: _callbackArguments}

        when 'chromeApi'
          {namespace, method, argumentList, callbackName, callbackArguments} = parameters
          if callbackName?
            argumentList.push () =>
              if callbackArguments? and callbackArguments.length
                _callbackArguments = _.object(callbackArguments, _.toArray arguments)
              else
                _callbackArguments = _.toArray arguments

              @socket.send
                type: 'executionCallback'
                parameters: {namespace, method, callbackName, callbackArguments: _callbackArguments}
          chrome[namespace][method].apply @, argumentList

        when 'eventListener'
          {namespace, method, callbackName, callbackArguments} = parameters
          chrome[namespace][method].addListener =>
            if not @socket.alive
              chrome[namespace][method].removeListener(@)
              return
            return unless callbackName?
            if callbackArguments? and callbackArguments.length
              _callbackArguments = _.object(callbackArguments, _.toArray arguments)
            else
              _callbackArguments = _.toArray arguments
            @socket.send
              type: 'eventListenerCallback'
              parameters: {namespace, event: method, callbackName, callbackArguments: _callbackArguments}
    catch error
      console.error error
      @socket.send
        type: 'error'
        parameters:
          callbackName: 'browserError'
          callbackArguments: {error}



window.WebSocketRequestHandler = WebSocketRequestHandler
