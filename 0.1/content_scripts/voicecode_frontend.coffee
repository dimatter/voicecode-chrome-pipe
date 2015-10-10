class VoiceCodeForeground
  instance = null
  frameId = null
  tabId = null
  constructor: ->
    return instance if instance?
    instance = @

  shouldActivate: ->
    return false if window.innerWidth < 3 or window.innerHeight < 3
    return true

  loadComplete: ->
    console.warn 'loadComplete'
    @freeTextBrowsing = new FreeTextBrowsing
    freeTextBrowsing.activate()
    voiceCodeForeground.installListener window, 'resize', _.bind freeTextBrowsing.reset, freeTextBrowsing, 400
    voiceCodeForeground.installListener window, 'scroll', _.bind freeTextBrowsing.reset, freeTextBrowsing, 400

  urlChanged: ->
    console.warn 'urlChanged'
    freeTextBrowsing.reset()

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
      console.debug '>>>>', payload
      chrome.runtime.sendMessage payload, (response) ->
        return false unless callback?
        callback.call @, response

  backendMessage: -> _.partial(@message, 'backend').apply window, arguments

  backgroundMessage: -> _.partial(@message, 'background').apply window, arguments

  log: ->
    console.log.apply console, arguments

  getIdentity: ->
    {frameId, tabId}

  setIdentity: ({tabId: _tabId, frameId: _frameId}) ->
    frameId = _frameId unless frameId?
    tabId = _tabId unless tabId?

  # buildTree: (visibleLinks) ->
  #   tree = {}
  #   _.each visibleLinks, (link) ->
  #     tokenArray = link.text.split ' '
  #     parent = null
  #     _.each tokenArray, (token) ->
  #       tree[token] ?= {}
  #       tree[token].belongsTo ?= []
  #       tree[token].belongsTo.push link.elementId unless link.elementId in tree[token].belongsTo
  #       if parent?
  #         tree[parent].children ?= []
  #         tree[parent].children.push token unless link.elementId in tree[parent].children
  #       parent = token
  #   tree

  # searchLinks: (searchQuery, tree = vc.tree) ->
  #   owners = []
  #   getOwnersFor = (token, childToken, restOfTokens) ->
  #     # console.log.apply console, arguments
  #     return owners if not tree[token]?
  #     if owners.length isnt 0
  #       owners = _.intersection owners, tree[token].belongsTo
  #     else
  #       owners = tree[token].belongsTo
  #     return owners if not childToken? and restOfTokens.length is 0
  #     if childToken in tree[token].children
  #       token = childToken
  #       [childToken, restOfTokens...] = restOfTokens
  #       owners = getOwnersFor token, childToken, restOfTokens
  #     owners
  #
  #   [token, childToken, restOfTokens...] = searchQuery.split ' '
  #   getOwnersFor token, childToken, restOfTokens
  #
  #
  # updateTree: (event) ->
  #   console.log "updateTree invoked by: #{event.type}" if event.type?
  #   visibleLinks = []
  #   $('#vc-markers').remove()
  #   markerContainer = $('<div>')
  #   markerContainer.attr 'id', 'vc-markers'
  #   $('body').append markerContainer
  #   counter = 0
  #   DomUtils.textContent.reset()
  #   $('a, button').each ->
  #     elementId = $(@).attr('id')
  #     unless elementId?
  #       elementId = 'link' + Math.random().toString(36).replace('.', '')
  #       $(@).attr 'id', elementId
  #
  #     rectangle = DomUtils.getVisibleClientRect $(@)[0], true
  #     if rectangle
  #       text = DomUtils.textContent.get $(@)[0]
  #       visibleLinks.push {elementId, text, rectangle, integerId: counter++}
  #
  #   visibleLinks = _.map visibleLinks, (link) ->
  #     value = link.text
  #     value = value.replace /[\n\r\t]+/g, ' '
  #     value = value.replace /\W+/g, ' ' # remove any non-word characters
  #     value = value.replace /(\d+)\s+(\d+)/, "$1$2"
  #     # value = value.replace /[^a-zA-Z0-9]+/g, ''
  #     value = value.replace /\s+/g, ' ' # remove white spaces in the beginning of the string
  #     value = value.replace /^\s+/g, '' # remove white spaces in the beginning of the string
  #     value = value.replace /\s+$/g, '' # remove white spaces in the end of the string
  #     if value isnt ''
  #       # marker = $('<div>')
  #       # marker = marker.addClass 'vc-marker'
  #       # marker = marker.attr 'id', 'marker' + $('#'+link.elementId).attr('id')
  #       # marker = marker.append($('<span>'))
  #       # $(marker).find('span').first().text value.toLowerCase()
  #       # _.each link.rectangle, (value, key)  ->
  #       #   marker = marker.css key, "#{value}px"
  #       # $('#vc-markers').append(marker)
  #
  #       link.text = value.toLowerCase()
  #       link
  #     else
  #       null
  #
  #   visibleLinks = _.compact visibleLinks
  #   vc.tree = vc.buildTree visibleLinks
  #   console.log vc.tree
  #
chrome.runtime.onMessage.addListener (request, sender, sendResponse) ->
  console.warn 'onMessage', request
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
  voiceCodeForeground.installListener window, 'focus', (event) ->
    if event.target is window
      voiceCodeForeground.backendMessage('domEvent', {event: event.type, target: 'window'}, voiceCodeForeground.log)
    true
  voiceCodeForeground.installListener window, 'blur', (event) ->
    if event.target is window
      voiceCodeForeground.backendMessage('domEvent', {event: event.type, target: 'window'}, voiceCodeForeground.log)
    true

  # for type in [ "keydown", "keypress", "keyup", "click", "focus", "blur", "mousedown", "scroll" ]
  #   do (type) -> installListener window, type, (event) -> handlerStack.bubbleEvent type, event
  # installListener document, "DOMActivate", (event) -> handlerStack.bubbleEvent 'DOMActivate', event


  $(document).ready ->
    # textInputTypes = [ "text", "search", "email", "url", "number", "password", "date", "tel" ]
    $('input, textarea').each ->
      for eventName in ['blur', 'focus']
        voiceCodeForeground.installListener $(@)[0], eventName, (event) ->
          if event.type is 'focus'
            freeTextBrowsing.deactivate()
          else
            freeTextBrowsing.activate()
          voiceCodeForeground.backendMessage('domEvent', {event: event.type, target: event.target}, voiceCodeForeground.log)
          true

@voiceCodeForeground.backgroundMessage 'invoke',
    namespace: 'voiceCodeBackground'
    method: 'getIdentity'
 , @voiceCodeForeground.setIdentity
