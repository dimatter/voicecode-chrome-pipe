class VoiceCodeBackground
  instance = null
  constructor: ->
    return instance if instance?
    instance = @
  getIdentity: ->

class HintDispenser
  instance = null
  ledger = {}

  register = (tabId, frameId, hint) ->
    ledger[tabId] ?= {}
    ledger[tabId][frameId] ?= []

    ledger[tabId][frameId].push parseInt hint

  constructor: ->
    return instance if instance?
    instance = @

  getAggregate: (tabId) ->
    ledger[tabId] ?= {}
    _.flatten _.toArray ledger[tabId]

  getHints: ({tabId, frameId, count}) ->
    hints = _.times count, => @getHint {tabId, frameId}
    {hints: _.flatten hints}

  getHint: ({tabId, frameId}) =>
    ledger[tabId] ?= {}
    ledger[tabId][frameId] ?= []

    hint = 0
    while @alreadyTaken hint, tabId
      ++hint
    register tabId, frameId, hint
    {hint}

  reset: ({tabId, frameId}) ->
    if frameId?
      ledger[tabId][frameId] = []
      return
    ledger[tabId] = {}

  reserveHints: ({tabId, frameId, reservations}) ->
    reservations = _.map reservations, ({desiredInteger, id}) =>
      @reserveHint({tabId, frameId, desiredInteger, id})
    {reservations}

  alreadyTaken: (desiredInteger, tabId) ->
    parseInt(desiredInteger) in @getAggregate tabId

  reserveHint: ({tabId, frameId, desiredInteger, id}) =>
    unless @alreadyTaken desiredInteger, tabId
      register tabId, frameId, desiredInteger
      return {id, hint: desiredInteger, overwritten: false}
    return {id, hint: (@getHint({tabId, frameId})).hint, overwritten: true}


chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) =>
  if changeInfo.url?
    message =
      type: 'invokeBound'
      namespace: 'voiceCodeForeground'
      method: 'urlChanged'
    chrome.tabs.sendMessage tabId, message

  if changeInfo.status is 'complete'
    message =
      type: 'invokeBound'
      namespace: 'voiceCodeForeground'
      method: 'loadComplete'
    chrome.tabs.sendMessage tabId, message

  if changeInfo.status is 'loading'
    hintDispenser.reset {tabId}
  #   @socket.send
  #     type: 'FreeTextBrowsing'
  #     parameters:
  #       callbackName: 'clearSearchQuery'
  #       callbackArguments: {tabId}
throttledMethods =
  'clearSearchQuery'

chrome.runtime.onMessage.addListener (request, sender, sendResponse) =>
  # console.group 'onMessage @ background'
  console.debug '<', request, sender
  senderInfo =
    frameId: sender.frameId
    tabId: sender.tab.id
    windowId: sender.tab.windowId

  switch request.destination
    when 'tab'
      {tabId = null} = request.parameters
      tabId ?= senderInfo.tabId
      request.parameters.argumentsObject ?= {}
      chrome.tabs.sendMessage tabId, _.extend request.parameters, {type: request.type}
      # TODO: implement callback?
    when 'backend'
      return false if method in throttledMethods and parseInt(frameId) isnt 0
      request.parameters.callbackArguments ?= {}
      request.parameters.callbackArguments = _.extend request.parameters.callbackArguments, senderInfo
      @socket.send
        type: request.type
        parameters: request.parameters
    when 'background'
      {namespace, method, argumentsObject} = request.parameters
      argumentsObject ?= {}
      argumentsObject = _.extend argumentsObject, senderInfo
      switch request.type
        when 'invoke'
          results = @[namespace][method].call @ , argumentsObject
        when 'invokeBound'
          instance = new @[namespace]
          results = instance[method].call instance, argumentsObject
      sendResponse _.extend (results || {}), senderInfo
  false

@socket = new WebSocketWrapper
@hintDispenser = new HintDispenser
@voiceCodeBackground = new VoiceCodeBackground
@HintDispenser = HintDispenser
