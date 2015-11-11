# activation modes
OPEN_IN_CURRENT_TAB = {}
OPEN_IN_NEW_WINDOW = {}
OPEN_INCOGNITO = {}
# viewport modes
CLEAN = {}
ALWAYS_SHOW_TEXTLESS_HINTS = {}
# matching modes
BESTMATCH = {}
# state
NORMAL = {}
MULTIPLE_MATCHES = {}
SHOWING_ALL_MARKERS = {}

class KeyboardController
  instance = null
  previousEvent = null
  keypressQueue = ''
  _onCharacterKeypress = null
  _onIntegerKeypress = null
  integerKeypressQueue  = ''
  characterKeypressQueue = ''

  constructor: ->
    return @ if instance?
    @listener = new window.keypress.Listener
    instance = @

  registerCombo: ->
    alphabet = 'qwertyuiopasdfghjklzxcvbnm1234567890-/\\_!*[]'.split('')
    modifiers = ['space', 'escape', 'enter']

    keysOfInterest = alphabet.concat modifiers
    _.each keysOfInterest, (key) =>
      combo =
        "keys" : key
        "on_keydown" : @onKeyDownHandler
        "on_keyup" : @onKeyUpHandler
        "on_release" : @onReleaseHandler
        "this" : @
        "prevent_default" : true
        "prevent_repeat" : true
        "is_unordered" : true
        "is_counting" : false
        "is_exclusive" : false
        "is_solitary" : false
        "is_sequence" : false
      @listener.register_combo combo

  onIntegerKeypress: (key) ->
    integerKeypressQueue += key
    _onIntegerKeypress ?= _.debounce ->
      voiceCodeForeground.tabMessage 'invokeBound',
        namespace: 'freeTextBrowsing'
        method: 'handleHintKeypress'
        argumentsObject: {keys: integerKeypressQueue}
      integerKeypressQueue = ''
      _onIntegerKeypress = null
    , 100
    do _onIntegerKeypress

  onCharacterKeypress: (key) ->
    characterKeypressQueue += key
    _onCharacterKeypress ?= _.debounce ->
      voiceCodeForeground.backendMessage 'FreeTextBrowsing',
        callbackName: 'eventBrowserKeypress'
        callbackArguments: {keys: characterKeypressQueue.toLowerCase()}
      characterKeypressQueue = ''
      _onCharacterKeypress = null
    , 100
    do _onCharacterKeypress

  onKeyDownHandler: (event) ->
    return true unless freeTextBrowsing.isActive
    # console.log 'onKeyDown', event

  onKeyUpHandler: (event) ->
    return true unless freeTextBrowsing.isActive
    # console.error event.keyCode
    if event.keyCode in [48..57]
      key = String.fromCharCode event.keyCode
      console.error key
      @onIntegerKeypress key
      return false

    if event.keyCode is 27 # escape key pressed
      voiceCodeForeground.tabMessage 'invokeBound',
        namespace: 'keyboardController'
        method: 'onEscapeKey'

      previousEvent = event
      return true

    unless event.keyCode is 32 and previousEvent?.keyCode in [48..57] # exclude space that follows an integer
      @onCharacterKeypress String.fromCharCode event.keyCode
      previousEvent = event
    false

  onEscapeKey: ->
    if freeTextBrowsing.state in [MULTIPLE_MATCHES, SHOWING_ALL_MARKERS]
      freeTextBrowsing.restoreViewportState()
      freeTextBrowsing.changeViewportState NORMAL, false
      freeTextBrowsing.clearRemoteSearchQuery()
    else
      freeTextBrowsing.deactivate()
    previousEvent = event

  onReleaseHandler: (event) ->
    return true unless freeTextBrowsing.isActive
    # console.log 'onRelease', event

Settings =
  get: (setting) ->
    true

class FreeTextBrowsing
  instance = null
  debouncedProcessViewport = null
  debouncedReset = null

  constructor: ->
    return @ if instance?
    @isActive = false
    @matchingMode = BESTMATCH
    @state = NORMAL
    @viewportMode = CLEAN
    if Settings.get 'ALWAYS_SHOW_TEXTLESS_HINTS'
      @viewportMode = ALWAYS_SHOW_TEXTLESS_HINTS
    instance = @

  deactivate: ->
    @clearRemoteSearchQuery()
    @hideMarkers()
    @isActive = false

  handleHintKeypress: ({keys}) ->
    possibleCandidates = _.filter @linkList, (link, id) ->
      ("#{link.hint}").indexOf(keys) is 0
    if possibleCandidates.length is 1
      @activateLink possibleCandidates.pop()
      return
    @changeViewportState MULTIPLE_MATCHES unless @state is MULTIPLE_MATCHES
    @showMarkers possibleCandidates

  activate: ->
    return if @isActive
    @createMarkerContainer()
    @processViewport()
    console.debug 'linkList: ', @linkList

    # @getUrlTexts @linkList
    # @registerMutationObserver()
    @isActive = true

  reset: (delay = 0) ->
    _reset = ->
      @clearRemoteSearchQuery()
      @purgeMarkerContainer()
      @resetHintDispenser()
      @isActive = false
      @activate()
      debouncedReset = null
    unless debouncedReset?
      debouncedReset = _.bind (_.debounce _reset, delay), @
    do debouncedReset

  clearRemoteSearchQuery: ->
    voiceCodeForeground.backendMessage 'FreeTextBrowsing', callbackName: 'clearSearchQuery'

  processViewport: (delay = 0) ->
    _processViewport = ->
      console.warn 'processViewport'
      DomUtilities.textContent.reset()
      @linkList = {}
      @labelMap = {}
      @generateLabelMap()

      @linkList = @getVisibleClickableElements()
      length = (el) -> el.element.innerHTML?.length ? 0
      @linkList.sort (a,b) -> length(a) - length b

      @linkList = _.map @linkList, (link) =>
        link.id = @generateId()
        link.text = @getLinkText link.element
        # debugger if link.text is null TODO: handle this
        unless link.text?
          link.text = ''
        link

      @linkList = _.indexBy @linkList, 'id'

      [numeric, nonnumeric] = _.partition @linkList, (link) ->
        link.text.match(/^\d+$/)?

      next = _.bind @createMarkers, @, nonnumeric
      @createNumericMarkers numeric, next
      @dispatchLinkList nonnumeric
      debouncedProcessViewport = null

    unless debouncedProcessViewport?
      debouncedProcessViewport = _.bind (_.debounce _processViewport, delay), @
    do debouncedProcessViewport

  createNumericMarkers: (linkList, next = null) ->
    return do next unless linkList.length
    next = _.after linkList.length, next
    _.each linkList, (link) =>
        @reserveLinkHint link.id, link.text, do (link, _this, next) ->
          (reservations) ->
            link = _.extend link, _.findWhere reservations, {id: link.id}
            link.isNumeric = true
            _this.linkList[link.id] = link
            _this.createMarker link
            do next

  dispatchLinkList: (linkList) ->
    linkList = _.reject linkList, (link) -> _.isEmpty link.text
    linkList = _(linkList).map ({id, text}) -> {id, text} # voicecode only needs id:text pairs

    voiceCodeForeground.backendMessage 'FreeTextBrowsing', {
      callbackName: 'setLinkList'
      callbackArguments: {linkList}
      }, null

  formatText: (text) ->
    text = text.replace /^\W+$/g, '' # collapse completely if only non-word characters
    text = text.replace /[\n\r\t\s]+/g, ' ' # replace all whitespace characters with 1 space
    text = text.replace /^\s+/g, '' # remove white spaces in the beginning of the string
    text = text.replace /\s+$/g, '' # remove white spaces in the end of the string
    text = text.replace /^\s+$/g, '' # collapse completely if only spaces

    text = text.replace /^\W+(\d+)$/, '$1' # non-word characters followed by integers: leave integer only
    text = text.replace /^(\d+)\W+$/, '$1' # integers followed by non-word characters: leave integers only
    text = text.replace /^\W+(\d+)\W+$/, '$1' # integers wrapped by non-word characters

    text

  generateId: ->
    s4 = ->
      Math.floor((1 + Math.random()) * 0x10000).toString(16).substring 1
    'id' + s4() + s4() + '-' + s4() + '-' + s4() #+ '-' + s4() + '-' + s4() + s4() + s4()

  shouldShowMarkerFor: (link) ->
    if link.text is '' and @viewportMode is ALWAYS_SHOW_TEXTLESS_HINTS
      return true
    if link.isNumeric? and link.overwritten
      return true
    return false

  generateLabelMap: ->
    labels = document.querySelectorAll("label")
    for label in labels
      forElement = label.getAttribute("for")
      if (forElement)
        labelText = label.textContent.trim()
        # remove trailing : commonly found in labels
        if (labelText[labelText.length-1] == ":")
          labelText = labelText.substr(0, labelText.length-1)
        @labelMap[forElement] = labelText
  #
  # Determine whether the element is visible and clickable. If it is, find the rect bounding the element in
  # the viewport.  There may be more than one part of element which is clickable (for example, if it's an
  # image), therefore we always return a array of element/rect pairs (which may also be a singleton or empty).
  #
  getVisibleClickable: (element) ->
    return [] if element.nodeType is 3
    tagName = element.tagName.toLowerCase()
    isClickable = false
    onlyHasTabIndex = false
    visibleElements = []

    # Insert area elements that provide click functionality to an img.
    if tagName == "img"
      mapName = element.getAttribute "usemap"
      if mapName
        imgClientRects = element.getClientRects()
        mapName = mapName.replace(/^#/, "").replace("\"", "\\\"")
        map = document.querySelector "map[name=\"#{mapName}\"]"
        if map and imgClientRects.length > 0
          areas = map.getElementsByTagName "area"
          areasAndRects = DomUtilities.getClientRectsForAreas imgClientRects[0], areas
          visibleElements.push areasAndRects...

    # Check aria properties to see if the element should be ignored.
    if (element.getAttribute("aria-hidden")?.toLowerCase() in ["", "true"] or
        element.getAttribute("aria-disabled")?.toLowerCase() in ["", "true"])
      return [] # This element should never have a link hint.

    # Check for AngularJS listeners on the element.
    @checkForAngularJs ?= do ->
      angularElements = document.getElementsByClassName "ng-scope"
      if angularElements.length == 0
        -> false
      else
        ngAttributes = []
        for prefix in [ '', 'data-', 'x-' ]
          for separator in [ '-', ':', '_' ]
            ngAttributes.push "#{prefix}ng#{separator}click"
        (element) ->
          for attribute in ngAttributes
            return true if element.hasAttribute attribute
          false

    isClickable ||= @checkForAngularJs element

    # Check for attributes that make an element clickable regardless of its tagName.
    if (element.hasAttribute("onclick") or
        element.hasAttribute("mouseup") or
        element.hasAttribute("mousedown") or
        element.hasAttribute("dblclick") or
        element.getAttribute("role")?.toLowerCase() in ["button", "link"] or
        element.getAttribute("class")?.toLowerCase().indexOf("button") >= 0 or
        element.getAttribute("contentEditable")?.toLowerCase() in ["", "contentEditable", "true"])
      isClickable = true

    # Check for jsaction event listeners on the element.
    if element.hasAttribute "jsaction"
      jsactionRules = element.getAttribute("jsaction").split(";")
      for jsactionRule in jsactionRules
        ruleSplit = jsactionRule.split ":"
        isClickable ||= ruleSplit[0] == "click" or (ruleSplit.length == 1 and ruleSplit[0] != "none")

    # Check for tagNames which are natively clickable.
    switch tagName
      when "a"
        isClickable = true
      when "textarea"
        isClickable ||= not element.disabled and not element.readOnly
      when "input"
        isClickable ||= not (element.getAttribute("type")?.toLowerCase() == "hidden" or
                             element.disabled or
                             (element.readOnly and DomUtilities.isSelectable element))
      when "button", "select"
        isClickable ||= not element.disabled
      when "label"
        isClickable ||= element.control? and (@getVisibleClickable element.control).length == 0

    # Elements with tabindex are sometimes useful, but usually not. We can treat them as second class
    # citizens when it improves UX, so take special note of them.
    tabIndexValue = element.getAttribute("tabindex")
    tabIndex = if tabIndexValue == "" then 0 else parseInt tabIndexValue
    unless isClickable or isNaN(tabIndex) or tabIndex < 0
      isClickable = onlyHasTabIndex = true

    if isClickable
      clientRect = DomUtilities.getVisibleClientRect element, true
      if clientRect != null
        visibleElements.push {element: element, rect: clientRect, secondClassCitizen: onlyHasTabIndex}

    visibleElements

  getLinkHint: do ->
    allCallbacks = []
    debounced = null
    funky = (callback, count) ->
      voiceCodeForeground.backgroundMessage 'invokeBound',
        namespace: 'HintDispenser'
        method: 'getHints'
        argumentsObject: {count}
      , callback
      debounced = null
    (callback) ->
      allCallbacks.push callback
      unless debounced?
        debounced = _.debounce funky, 10
      debounced ({hints}) ->
        _.each hints, (hint) ->
          return unless allCallbacks?
          (allCallbacks.shift())(hint)
      , allCallbacks.length

  # WELCOME TO HELL
  reserveLinkHint: do ->
    allCallbacks = []
    _reservations = []
    debounced = null
    clearReservations = null
    funky = (callback, reservations) ->
      voiceCodeForeground.backgroundMessage 'invokeBound',
        namespace: 'HintDispenser'
        method: 'reserveHints'
        argumentsObject: {reservations}
      , callback
      debounced = null
    (id, desiredInteger, callback) ->
      allCallbacks.push callback
      _reservations.push {id, desiredInteger}
      unless debounced?
        debounced = _.debounce funky, 10
      debounced ({reservations}) ->
        _.each reservations, ->
          return unless allCallbacks?
          (allCallbacks.pop())(reservations)
          clearReservations ?= _.after reservations.length, ->
            _reservations = []
            clearReservations = null
          clearReservations()
      , _reservations

  resetHintDispenser: ->
    voiceCodeForeground.backgroundMessage 'invokeBound',
      namespace: 'HintDispenser'
      method: 'reset'
    , ->
      # console.warn 'resetHintDispenser'

  getLinkText: (element) ->
    linkText = ''
    # toLowerCase is necessary as html documents return "IMG" and xhtml documents return "img"
    nodeName = element.nodeName.toLowerCase()

    if (nodeName == "input")
      if (@labelMap[element.id])
        linkText = @labelMap[element.id]
      else if (element.type != "password")
        linkText = element.value
        if not linkText and 'placeholder' of element
          linkText = element.placeholder
      linkText = '' unless linkText?
      # check if there is an image embedded in the <a> tag
    else if (nodeName == "a" && !element.textContent.trim() &&
        element.firstElementChild &&
        element.firstElementChild.nodeName.toLowerCase() == "img")
      linkText = element.firstElementChild.alt || element.firstElementChild.title
    else if $(element).attr('aria-label')?
      linkText = $(element).attr('aria-label')
    # else if $(element).attr('title')?
    #   linkText = $(element).attr('title')
    else
      linkText = DomUtilities.textContent.get element

    @formatText linkText.substring(0, 2000) unless linkText is ''
  #
  # Returns all clickable elements that are not hidden and are in the current viewport, along with rectangles
  # at which (parts of) the elements are displayed.
  # In the process, we try to find rects where elements do not overlap so that link hints are unambiguous.
  # Because of this, the rects returned will frequently *NOT* be equivalent to the rects for the whole
  # element.
  #
  getVisibleClickableElements: (elements = null)->
    unless elements?
      elements = document.documentElement.getElementsByTagName "*"
    visibleElements = []

    # The order of elements here is important; they should appear in the order they are in the DOM, so that
    # we can work out which element is on top when multiple elements overlap. Detecting elements in this loop
    # is the sensible, efficient way to ensure this happens.
    # NOTE(mrmr1993): Our previous method (combined XPath and DOM traversal for jsaction) couldn't provide
    # this, so it's necessary to check whether elements are clickable in order, as we do below.
    for element in elements
      visibleElement = @getVisibleClickable element
      visibleElements.push visibleElement...

    # TODO(mrmr1993): Consider z-index. z-index affects behviour as follows:
    #  * The document has a local stacking context.
    #  * An element with z-index specified
    #    - sets its z-order position in the containing stacking context, and
    #    - creates a local stacking context containing its children.
    #  * An element (1) is shown above another element (2) if either
    #    - in the last stacking context which contains both an ancestor of (1) and an ancestor of (2), the
    #      ancestor of (1) has a higher z-index than the ancestor of (2); or
    #    - in the last stacking context which contains both an ancestor of (1) and an ancestor of (2),
    #        + the ancestors of (1) and (2) have equal z-index, and
    #        + the ancestor of (1) appears later in the DOM than the ancestor of (2).
    #
    # Remove rects from elements where another clickable element lies above it.
    nonOverlappingElements = []
    # Traverse the DOM from first to last, since later elements show above earlier elements.
    visibleElements = visibleElements.reverse()
    while visibleElement = visibleElements.pop()
      rects = [visibleElement.rect]
      for {rect: negativeRect} in visibleElements
        # Subtract negativeRect from every rect in rects, and concatenate the arrays of rects that result.
        rects = [].concat (rects.map (rect) -> Rect.subtract rect, negativeRect)...
      if rects.length > 0
        nonOverlappingElements.push {element: visibleElement.element, rect: rects[0]}
      else
        # Every part of the element is covered by some other element, so just insert the whole element's
        # rect. Except for elements with tabIndex set (second class citizens); these are often more trouble
        # than they're worth.
        # TODO(mrmr1993): This is probably the wrong thing to do, but we don't want to stop being able to
        # click some elements that we could click before.
        nonOverlappingElements.push visibleElement unless visibleElement.secondClassCitizen

    nonOverlappingElements

  purgeMarkerContainer: ->
    $('#voicecodeMarkerContainer').empty()

  createMarkerContainer: ->
    return if $('#voicecodeMarkerContainer')[0]?
    container = $('<div>')
    container.attr 'id', 'voicecodeMarkerContainer'
    container.addClass 'voicecodeMarkerContainer voicecodeReset'
    $('body').append container

  createMarkerElement: (link) ->
    if link.secondClassCitizen
      console.error 'ENCOUNTERED SECOND-CLASS CITIZEN'
    marker = $('<div>')
    marker.addClass "voicecodeReset internalVoiceCodeHintMarker voicecodeHintMarker"
    marker.attr 'data-vc-marker-for', link.id
    child = $('<span>').addClass 'voicecodeReset voicecodeHint'
    childText = link.hint
    childText += ": #{link.text}" unless _.isEmpty link.text
    child.text childText
    child.on 'click', ->
      id = $(@).parent().attr 'data-vc-marker-for'
      console.debug $("\##{id}")

    marker.append child
    marker.css 'left', link.rect.left + window.scrollX + "px"
    marker.css 'top', link.rect.top  + window.scrollY  + "px"
    marker.css 'with', link.rect.with # TODO: fix(?)
    marker.hide()
    marker

  createMarkers: (linkList = @linkList) ->
    _.each linkList, (link) =>
      @createMarker link

  createMarker: (link) ->
    if link.hint?
      @appendMarkerElement @createMarkerElement link
      @showMarkerFor link if @shouldShowMarkerFor link
    else
      _this = @
      @getLinkHint do (link, _this) ->
        ({hint}) ->
          link.hint = hint
          _this.linkList[link.id] = link
          _this.appendMarkerElement _this.createMarkerElement link
          _this.showMarkerFor link if _this.shouldShowMarkerFor link

  appendMarkerElement: (marker) ->
    $('#voicecodeMarkerContainer').append marker

  removeMarkerFor: (link) ->
    $('#voicecodeMarkerContainer').find("div[data-vc-marker-for='#{link.id}']").remove()

  hideMarkerFor: (link) ->
    $('#voicecodeMarkerContainer').find("div[data-vc-marker-for='#{link.id}']").hide()

  showMarkerFor: (link, opacity = 1) ->
    $('#voicecodeMarkerContainer').find("div[data-vc-marker-for='#{link.id}']").css('opacity', opacity).show()

  showMarkers: (linkList = @linkList, opacity = 1) ->
    _.each linkList, (link) =>
      @showMarkerFor link, opacity

  hideMarkers: (linkList = @linkList) ->
    _.each linkList, (link) =>
      @hideMarkerFor link

  getUrlTexts: (linkList) ->
    # https://gist.github.com/dperini/729294
    expression = new RegExp /^(?:(?:https?|ftp):\/\/)(?:\S+(?::\S*)?@)?(?:(?!(?:10|127)(?:\.\d{1,3}){3})(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,}))\.?)(?::\d{2,5})?(?:[/?#]\S*)?$/i
    urlTexts = _.filter linkList, (link, id) ->
      link.text.match expression
    console.error urlTexts if urlTexts.length

  registerMutationObserver: ->
    # observer = new WebKitMutationObserver (mutations) =>
    #   _.each mutations, (mutation) =>
    #     console.log mutation unless mutation.type is 'attributes'
        # if mutation.addedNodes.length
        #   newClickableElements = @getVisibleClickableElements mutation.addedNodes
        #   if newClickableElements.length
        #     DomUtilities.textContent.reset()
        #     @labelMap = {}
        #     @generateLabelMap()
        #
        #     _.each newClickableElements, (link) =>
        #       unless @linkList[link.id]?
        #         unless link.element.id? and link.element.id isnt ''
        #           link.element.id = @generateId() # DOM change, might not be needed
        #         link.id = link.element.id
        #         # and getting link text
        #         link.text = @getLinkText link.element
        #
        #         @getLinkHint =>
        #           @setLinkHint link.id, (_.toArray arguments)[0]
        #         @linkList[link.id] = link
        #         console.warn "Appending new element: ", link
                # TODO: dispatch additions 2 node
        # TODO: handle removals?
        # return unless mutation.removedNodes.length


    # observer.observe document,
    #   attributes: true
    #   childList: true
    #   characterData: true
    #   subtree: true
  #
  # When only one link hint remains, this function activates it in the appropriate way.
  #
  activateLink: (link) ->
    if (DomUtilities.isSelectable(link.element))
      DomUtilities.simulateSelect(link.element)
    else
      # TODO figure out which other input elements should not receive focus
      if (link.element.nodeName.toLowerCase() == "input" and link.element.type not in ["button", "submit"])
        link.element.focus()
      DomUtilities.flashRect(link.rect)
      DomUtilities.simulateClick link.element

  updateMatchedLinks: ({matchedLinks}) ->
    return unless @isActive? and @isActive
    console.dir matchedLinks
    # TODO: filter out links that belong to other frames
    if _.isEmpty matchedLinks
      $('a [href="/"]').shake()
      @clearRemoteSearchQuery()
      console.error 'NOTHING FOUND!'
      return
    _.each matchedLinks, (links, measure) =>
      opacity = Math.round(measure*1) / 10
      if @matchingMode is BESTMATCH and links.length is 1
        id = links.pop().id
        return unless @linkList[id]?
        @activateLink @linkList[id]
        console.warn voiceCodeForeground.getIdentity()
        @clearRemoteSearchQuery()
        return
      else
        @changeViewportState MULTIPLE_MATCHES
        @showMarkers links

  toggleAllMarkers: ->
    if @state is SHOWING_ALL_MARKERS
      @restoreViewportState()
      @changeViewportState NORMAL, false
      return
    @changeViewportState SHOWING_ALL_MARKERS
    @showMarkers @linkList

  changeViewportState: (state, preservePrevious = true) ->
    return unless state?
    @captureViewportState().hide() if preservePrevious
    @state = state

  getPreviousViewportState: ->
    if @capturedViewportStates.length
      return @capturedViewportStates.pop()
    return null

  captureViewportState: ->
    @capturedViewportStates ?= []
    @capturedViewportStates.push $('#voicecodeMarkerContainer').find('div.voicecodeHintMarker:visible')
    @capturedViewportStates[..].pop()

  restoreViewportState: ->
    previousViewportState = @getPreviousViewportState()
    if previousViewportState?
      $('#voicecodeMarkerContainer').find('div.voicecodeHintMarker:visible').hide()
      previousViewportState.show()

@FreeTextBrowsing = FreeTextBrowsing
@KeyboardController = KeyboardController
@Settings = Settings



jQuery.fn.shake = ->
  @each (i) ->
    $(this).css 'position': 'relative'
    x = 1
    while x <= 3
      $(this).animate({ left: -25 }, 10).animate({ left: 0 }, 50).animate({ left: 25 }, 10).animate { left: 0 }, 50
      x++
    return
  this
