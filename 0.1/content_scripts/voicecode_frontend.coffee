class VoiceCodeForeground
  instance = null
  frameId = null
  tabId = null
  constructor: ->
    return instance if instance?
    @debug = true
    instance = @
    @

  shouldActivate: ->
    return false if window.innerWidth < 3 or window.innerHeight < 3
    return true

  loadComplete: ->
    return unless @shouldActivate()
    console.warn 'loadComplete'
    # window.keyboardController = new KeyboardController
    # window.keyboardController.registerCombo()
    # window.freeTextBrowsing = new FreeTextBrowsing

    # freeTextBrowsing.activate()
    # @installListener window, 'resize', _.bind freeTextBrowsing.reset, freeTextBrowsing, 400
    # @installListener window, 'scroll', _.bind freeTextBrowsing.reset, freeTextBrowsing, 400

  urlChanged: ->
    console.warn 'urlChanged' if @debug
    # freeTextBrowsing?.reset()

  installListener: (element, event, callback) ->
    element.addEventListener(event, (eventObject) ->
      callback eventObject
    , true)

  message: (destination, type, parameters, callback = null) ->
    do (callback) ->
      payload =
        destination: destination
        type: type
        parameters: parameters
      console.debug 'outgoing >>>>', payload if @debug
      chrome.runtime.sendMessage payload, (response) ->
        return false unless callback?
        callback.call @, response

  tabMessage: -> _.partial(@message, 'tab').apply window, arguments

  backendMessage: -> _.partial(@message, 'backend').apply window, arguments

  backgroundMessage: -> _.partial(@message, 'background').apply window, arguments

  log: ->
    if @debug
      console.log.apply console, arguments

  getIdentity: ->
    {frameId, tabId}

  setIdentity: ({tabId: _tabId, frameId: _frameId}) ->
    frameId = _frameId unless frameId?
    tabId = _tabId unless tabId?

chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  console.warn 'onMessage', voiceCodeForeground.getIdentity(), request
  _sendResponse = sendResponse
  {type, namespace, method, argumentsObject} = request
  funky = window[namespace][method]
  switch request.type
    when 'invoke'
      funky argumentsObject
    when 'invokeBound'
      funky.call eval(namespace), argumentsObject
    else
      console.error "DON'T KNOW HOW TO HANDLE", request
  true # asynchronous sendResponse


@voiceCodeForeground = new VoiceCodeForeground
if voiceCodeForeground.shouldActivate()
  voiceCodeForeground.installListener window, 'click', (event) ->
    # freeTextBrowsing.reset()
    true
  voiceCodeForeground.installListener window, 'focus', (event) ->
    if event.target is window
      voiceCodeForeground.backendMessage('domEvent', {event: event.type, target: 'window'}, voiceCodeForeground.log)
    true
  voiceCodeForeground.installListener window, 'blur', (event) ->
    if event.target is window
      voiceCodeForeground.backendMessage('domEvent', {event: event.type, target: 'window'}, voiceCodeForeground.log)
    true


  $(document).ready ->
    # textInputTypes = [ "text", "search", "email", "url", "number", "password", "date", "tel" ]
    $('input, textarea').each ->
      for eventName in ['blur', 'focus']
        voiceCodeForeground.installListener $(@)[0], eventName, (event) ->
          if event.type is 'focus'
            # freeTextBrowsing.deactivate()
          else
            # freeTextBrowsing.activate()
          voiceCodeForeground.backendMessage('domEvent', {event: event.type, target: event.target}, voiceCodeForeground.log)
          true

@voiceCodeForeground.backgroundMessage 'invoke',
    namespace: 'voiceCodeBackground'
    method: 'getIdentity'
 , @voiceCodeForeground.setIdentity
