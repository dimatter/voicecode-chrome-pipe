class DomCache
  instance = null
  constructor: ->
    return instance if instance?
    @visibleTextNodes = []
    voiceCodeForeground.installListener window, 'resize', => @rescan()
    voiceCodeForeground.installListener window, 'scroll', => @rescan()
    DomUtilities.documentReady => @rescan()
    instance = @
  rescan: ->
    @clear()
    @searchVisibleTextNodes()
  clear: ->
    @visibleTextNodes = []
  searchVisibleTextNodes: ->
    visitedNodes = []
    treeWalker = document.createTreeWalker document.body, NodeFilter.SHOW_TEXT
    #   acceptNode: (node) ->
    #     empty = node.textContent.match /^\s+$/
    #     return NodeFilter.FILTER_REJECT if empty?
    #     return NodeFilter.FILTER_ACCEPT
    # }, true
    while node = treeWalker.nextNode()
      continue unless node.nodeType == 3
      continue if node in visitedNodes
      text = node.data.trim()
      continue unless 0 < text.length
      visitedNodes.push node
      if DomUtilities.getVisibleClientRect node.parentNode
        @visibleTextNodes.push node

###*
 * type: String: select/extend
###
class SelectionController
  instance = null
  constructor: ->
    return instance if instance?
    instance = @
    @cache = {}
    @currentPosition = {}
    @previousSearchTerm = null
    voiceCodeForeground.installListener window, 'click', (event) =>
      @reset()
  select: (argumentsObject) ->
    {target, direction, mode} = _.extend {
      direction: 'forward'
      mode: 'select'
    }, argumentsObject

    if target is null
      target = @previousSearchTerm

    unless target?
      console.error "Nothing to search for!"
      return
    # if mode is 'select' and not _.isEmpty @currentPosition
    #   @currentPosition = {}
    #   @deselectAll()

    if document.getSelection().type is 'Range' and _.isEmpty @currentPosition
      starter = null
      _.find domCache.visibleTextNodes, (node, position) ->
        if document.getSelection().focusNode is node
          starter = position
          return true
        return false
      if document.getSelection().extentNode isnt document.getSelection().baseNode
        ender = null
        _.find domCache.visibleTextNodes.reverse(), (node, position) ->
          if document.getSelection().extentNode is node
            ender = position
            return true
          return false
        domCache.visibleTextNodes.reverse()
      else
        ender = starter
      if starter? and ender?
        @range = document.getSelection().getRangeAt(0)
        @reset()
        @currentPosition =
          forward: starter
          backward: ender

    found = null
    funky = (node, position) =>
      if direction is 'forward'
        expression = target
      else
        expression = "(#{target})(?![\\s\\S]*#{target}[\\s\\S]*)"
        # expression = target
      # if we're searching for the same thing again and we currently have a selection
      if target is @previousSearchTerm and not _.isEmpty @currentPosition
        if direction is 'forward'
          if node is @range.endContainer
            leftEdgePush = @range.endOffset
            expression = "([\\s\\S]{#{leftEdgePush},})#{target}"
        else
          # expression = "(#{target})[\\s\\S]*#{target}"
          if node is @range.startContainer
            rightEdgePush = node.textContent.length - @range.startOffset
            expression = "#{target}[\\s\\S]{#{rightEdgePush},}$"
          # if node is @range.endContainer
          #   expression.lastIndex = @range.endOffset
      expression = new RegExp expression, 'mi'


      findings = expression.exec node.textContent
      # debugger
      if findings?
        found = {node, position, offset: findings.index}
        return true
      return false
    if direction is 'forward'
      startFrom = @currentPosition[direction] || 0
      wheneverFound = (found) =>
        @currentPosition[direction] ?= 0
        @currentPosition[direction] += found.position
      _.find domCache.visibleTextNodes[startFrom..], funky
    else
      startFrom = @currentPosition[direction] || @currentPosition['forward'] + 1 || _.size domCache.visibleTextNodes
      wheneverFound = (found) =>
        @currentPosition[direction] ?= @currentPosition['forward'] || _.size domCache.visibleTextNodes
        @currentPosition[direction] -= found.position
      _.find domCache.visibleTextNodes[0...startFrom].reverse(), funky
    if found?
      wheneverFound found
      if mode is 'select'
        @deselectAll()
        @range = document.createRange()
        @range.setStart found.node, found.offset
        @range.setEnd found.node, (found.offset + target.length)
      else
        if direction is 'forward'
          @range.setEnd found.node, (found.offset + target.length)
        else
          # if found.node is
          @range.setStart found.node, found.offset
      document.getSelection().addRange @range
      @previousSearchTerm = target

  extend: (argumentsObject) ->
    @select _.extend argumentsObject, mode: 'extend'

  reset: ->
    # @deselectAll()
    @currentPosition = {}

  deselectAll: ->
    document.getSelection().removeAllRanges()



window.SelectionController = new SelectionController
window.domCache = new DomCache
