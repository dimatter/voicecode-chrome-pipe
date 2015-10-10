// Generated by CoffeeScript 1.10.0
(function() {
  var ALWAYS_SHOW_TEXTLESS_HINTS, BESTMATCH, CLEAN, FreeTextBrowsing, KeyboardController, MULTIPLE_MATCHES, NORMAL, OPEN_A_NEW_TAB, OPEN_INCOGNITO, OPEN_IN_CURRENT_TAB, OPEN_IN_NEW_WINDOW, Settings;

  OPEN_IN_CURRENT_TAB = true;

  OPEN_A_NEW_TAB = true;

  OPEN_IN_NEW_WINDOW = true;

  OPEN_INCOGNITO = true;

  CLEAN = true;

  ALWAYS_SHOW_TEXTLESS_HINTS = true;

  BESTMATCH = true;

  NORMAL = true;

  MULTIPLE_MATCHES = true;

  KeyboardController = (function() {
    var instance;

    instance = null;

    function KeyboardController() {
      if (instance != null) {
        return this;
      }
      instance = this;
      this.listener = new window.keypress.Listener;
    }

    KeyboardController.prototype.registerCombo = function() {
      var alphabet, combo, keysOfInterest, modifiers;
      alphabet = 'qwertyuiopasdfghjklzxcvbnm123456789'.split(' ');
      modifiers = ['space', 'escape'];
      keysOfInterest = alphabet.concat(modifiers);
      combo = {
        "keys": keysOfInterest,
        "on_keydown": this.onKeyDownHandler,
        "on_keyup": this.onKeyUpHandler,
        "on_release": this.onReleaseHandler,
        "this": this,
        "prevent_default": true,
        "prevent_repeat": true,
        "is_unordered": true,
        "is_counting": false,
        "is_exclusive": false,
        "is_solitary": false,
        "is_sequence": false
      };
      return this.listener.register_combo(combo);
    };

    KeyboardController.prototype.toggleAllMarkers = function() {
      debugger;
      return console.error('EPIC WIN');
    };

    KeyboardController.prototype.dispatchKeypress = (function() {
      var debounced, keypressQueue;
      keypressQueue = '';
      debounced = null;
      return function(keys) {
        keypressQueue += keys;
        if (debounced == null) {
          debounced = _.debounce(function() {
            voiceCodeForeground.backendMessage('FreeTextBrowsing', {
              callbackName: 'eventBrowserKeypress',
              callbackArguments: {
                keys: keypressQueue.toLowerCase()
              }
            });
            keypressQueue = '';
            return debounced = null;
          }, 100);
        }
        return debounced();
      };
    })();

    KeyboardController.prototype.onKeyDownHandler = function(event) {
      if (!freeTextBrowsing.isActive) {
        return true;
      }
    };

    KeyboardController.prototype.onKeyUpHandler = function(event) {
      if (!freeTextBrowsing.isActive) {
        return true;
      }
      if (event.keyCode === 27) {
        if (freeTextBrowsing.state === MULTIPLE_MATCHES) {
          freeTextBrowsing.restoreViewportState();
          freeTextBrowsing.clearRemoteSearchQuery();
          freeTextBrowsing.state = NORMAL;
        } else {
          freeTextBrowsing.deactivate();
        }
        return true;
      }
      return this.dispatchKeypress(String.fromCharCode(event.keyCode));
    };

    KeyboardController.prototype.onReleaseHandler = function(event) {
      if (!freeTextBrowsing.isActive) {
        return true;
      }
    };

    return KeyboardController;

  })();

  Settings = {
    get: function(setting) {
      return true;
    }
  };

  FreeTextBrowsing = (function() {
    var debouncedProcessViewport, debouncedReset, instance;

    instance = null;

    debouncedProcessViewport = null;

    debouncedReset = null;

    function FreeTextBrowsing() {
      if (instance != null) {
        return this;
      }
      instance = this;
      this.isActive = false;
      this.matchingMode = BESTMATCH;
      this.state = NORMAL;
      this.keyboardController = new window.KeyboardController;
      this.keyboardController.registerCombo();
      this.viewportMode = CLEAN;
      if (!Settings.get('ALWAYS_SHOW_TEXTLESS_HINTS' === false)) {
        this.viewportMode = ALWAYS_SHOW_TEXTLESS_HINTS;
      }
    }

    FreeTextBrowsing.prototype.deactivate = function() {
      this.clearRemoteSearchQuery();
      this.hideMarkers();
      return this.isActive = false;
    };

    FreeTextBrowsing.prototype.activate = function() {
      if (this.isActive) {
        return;
      }
      this.createMarkerContainer();
      this.processViewport();
      console.debug('linkList: ', this.linkList);
      return this.isActive = true;
    };

    FreeTextBrowsing.prototype.reset = function(delay) {
      var _reset;
      if (delay == null) {
        delay = 0;
      }
      _reset = function() {
        this.clearRemoteSearchQuery();
        this.purgeMarkerContainer();
        this.resetHintDispenser();
        this.isActive = false;
        this.activate();
        return debouncedReset = null;
      };
      if (debouncedReset == null) {
        debouncedReset = _.bind(_.debounce(_reset, delay), this);
      }
      return debouncedReset();
    };

    FreeTextBrowsing.prototype.clearRemoteSearchQuery = function() {
      return voiceCodeForeground.backendMessage('FreeTextBrowsing', {
        callbackName: 'clearSearchQuery'
      });
    };

    FreeTextBrowsing.prototype.processViewport = function(delay) {
      var _processViewport;
      if (delay == null) {
        delay = 0;
      }
      _processViewport = function() {
        var length, next, nonnumeric, numeric, ref;
        console.warn('processViewport');
        DomUtilities.textContent.reset();
        this.linkList = {};
        this.labelMap = {};
        this.generateLabelMap();
        this.linkList = this.getVisibleClickableElements();
        length = function(el) {
          var ref, ref1;
          return (ref = (ref1 = el.element.innerHTML) != null ? ref1.length : void 0) != null ? ref : 0;
        };
        this.linkList.sort(function(a, b) {
          return length(a) - length(b);
        });
        this.linkList = _.map(this.linkList, (function(_this) {
          return function(link) {
            link.id = _this.generateId();
            link.text = _this.getLinkText(link.element);
            if (link.text == null) {
              link.text = '';
            }
            return link;
          };
        })(this));
        this.linkList = _.indexBy(this.linkList, 'id');
        ref = _.partition(this.linkList, function(link) {
          return link.text.match(/^\d+$/) != null;
        }), numeric = ref[0], nonnumeric = ref[1];
        next = _.bind(this.createMarkers, this, nonnumeric);
        this.createNumericMarkers(numeric, next);
        this.dispatchLinkList(nonnumeric);
        return debouncedProcessViewport = null;
      };
      if (debouncedProcessViewport == null) {
        debouncedProcessViewport = _.bind(_.debounce(_processViewport, delay), this);
      }
      return debouncedProcessViewport();
    };

    FreeTextBrowsing.prototype.createNumericMarkers = function(linkList, next) {
      if (next == null) {
        next = null;
      }
      if (!linkList.length) {
        return next();
      }
      next = _.after(linkList.length, next);
      return _.each(linkList, (function(_this) {
        return function(link) {
          return _this.reserveLinkHint(link.id, link.text, (function(link, _this, next) {
            return function(reservations) {
              link = _.extend(link, _.findWhere(reservations, {
                id: link.id
              }));
              link.isNumeric = true;
              _this.linkList[link.id] = link;
              _this.createMarker(link);
              return next();
            };
          })(link, _this, next));
        };
      })(this));
    };

    FreeTextBrowsing.prototype.dispatchLinkList = function(linkList) {
      linkList = _.reject(linkList, function(link) {
        return _.isEmpty(link.text);
      });
      linkList = _(linkList).map(function(arg) {
        var id, text;
        id = arg.id, text = arg.text;
        return {
          id: id,
          text: text
        };
      });
      return voiceCodeForeground.backendMessage('FreeTextBrowsing', {
        callbackName: 'setLinkList',
        callbackArguments: {
          linkList: linkList
        }
      }, null);
    };

    FreeTextBrowsing.prototype.formatText = function(text) {
      text = text.replace(/^\W+$/g, '');
      text = text.replace(/[\n\r\t\s]+/g, ' ');
      text = text.replace(/^\s+/g, '');
      text = text.replace(/\s+$/g, '');
      text = text.replace(/^\s+$/g, '');
      text = text.replace(/^\W+(\d+)$/, '$1');
      text = text.replace(/^(\d+)\W+$/, '$1');
      text = text.replace(/^\W+(\d+)\W+$/, '$1');
      return text;
    };

    FreeTextBrowsing.prototype.generateId = function() {
      var s4;
      s4 = function() {
        return Math.floor((1 + Math.random()) * 0x10000).toString(16).substring(1);
      };
      return 'id' + s4() + s4() + '-' + s4() + '-' + s4();
    };

    FreeTextBrowsing.prototype.shouldShowMarkerFor = function(link) {
      if (link.text === '' && this.viewportMode === ALWAYS_SHOW_TEXTLESS_HINTS) {
        return true;
      }
      if ((link.isNumeric != null) && link.overwritten) {
        return true;
      }
      return false;
    };

    FreeTextBrowsing.prototype.generateLabelMap = function() {
      var forElement, j, label, labelText, labels, len, results;
      labels = document.querySelectorAll("label");
      results = [];
      for (j = 0, len = labels.length; j < len; j++) {
        label = labels[j];
        forElement = label.getAttribute("for");
        if (forElement) {
          labelText = label.textContent.trim();
          if (labelText[labelText.length - 1] === ":") {
            labelText = labelText.substr(0, labelText.length - 1);
          }
          results.push(this.labelMap[forElement] = labelText);
        } else {
          results.push(void 0);
        }
      }
      return results;
    };

    FreeTextBrowsing.prototype.getVisibleClickable = function(element) {
      var areas, areasAndRects, clientRect, imgClientRects, isClickable, j, jsactionRule, jsactionRules, len, map, mapName, onlyHasTabIndex, ref, ref1, ref2, ref3, ref4, ref5, ref6, ref7, ref8, ref9, ruleSplit, tabIndex, tabIndexValue, tagName, visibleElements;
      if (element.nodeType === 3) {
        return [];
      }
      tagName = element.tagName.toLowerCase();
      isClickable = false;
      onlyHasTabIndex = false;
      visibleElements = [];
      if (tagName === "img") {
        mapName = element.getAttribute("usemap");
        if (mapName) {
          imgClientRects = element.getClientRects();
          mapName = mapName.replace(/^#/, "").replace("\"", "\\\"");
          map = document.querySelector("map[name=\"" + mapName + "\"]");
          if (map && imgClientRects.length > 0) {
            areas = map.getElementsByTagName("area");
            areasAndRects = DomUtilities.getClientRectsForAreas(imgClientRects[0], areas);
            visibleElements.push.apply(visibleElements, areasAndRects);
          }
        }
      }
      if (((ref = (ref1 = element.getAttribute("aria-hidden")) != null ? ref1.toLowerCase() : void 0) === "" || ref === "true") || ((ref2 = (ref3 = element.getAttribute("aria-disabled")) != null ? ref3.toLowerCase() : void 0) === "" || ref2 === "true")) {
        return [];
      }
      if (this.checkForAngularJs == null) {
        this.checkForAngularJs = (function() {
          var angularElements, j, k, len, len1, ngAttributes, prefix, ref4, ref5, separator;
          angularElements = document.getElementsByClassName("ng-scope");
          if (angularElements.length === 0) {
            return function() {
              return false;
            };
          } else {
            ngAttributes = [];
            ref4 = ['', 'data-', 'x-'];
            for (j = 0, len = ref4.length; j < len; j++) {
              prefix = ref4[j];
              ref5 = ['-', ':', '_'];
              for (k = 0, len1 = ref5.length; k < len1; k++) {
                separator = ref5[k];
                ngAttributes.push(prefix + "ng" + separator + "click");
              }
            }
            return function(element) {
              var attribute, l, len2;
              for (l = 0, len2 = ngAttributes.length; l < len2; l++) {
                attribute = ngAttributes[l];
                if (element.hasAttribute(attribute)) {
                  return true;
                }
              }
              return false;
            };
          }
        })();
      }
      isClickable || (isClickable = this.checkForAngularJs(element));
      if (element.hasAttribute("onclick") || ((ref4 = (ref5 = element.getAttribute("role")) != null ? ref5.toLowerCase() : void 0) === "button" || ref4 === "link") || ((ref6 = element.getAttribute("class")) != null ? ref6.toLowerCase().indexOf("button") : void 0) >= 0 || ((ref7 = (ref8 = element.getAttribute("contentEditable")) != null ? ref8.toLowerCase() : void 0) === "" || ref7 === "contentEditable" || ref7 === "true")) {
        isClickable = true;
      }
      if (element.hasAttribute("jsaction")) {
        jsactionRules = element.getAttribute("jsaction").split(";");
        for (j = 0, len = jsactionRules.length; j < len; j++) {
          jsactionRule = jsactionRules[j];
          ruleSplit = jsactionRule.split(":");
          isClickable || (isClickable = ruleSplit[0] === "click" || (ruleSplit.length === 1 && ruleSplit[0] !== "none"));
        }
      }
      switch (tagName) {
        case "a":
          isClickable = true;
          break;
        case "textarea":
          isClickable || (isClickable = !element.disabled && !element.readOnly);
          break;
        case "input":
          isClickable || (isClickable = !(((ref9 = element.getAttribute("type")) != null ? ref9.toLowerCase() : void 0) === "hidden" || element.disabled || (element.readOnly && DomUtilities.isSelectable(element))));
          break;
        case "button":
        case "select":
          isClickable || (isClickable = !element.disabled);
          break;
        case "label":
          isClickable || (isClickable = (element.control != null) && (this.getVisibleClickable(element.control)).length === 0);
      }
      tabIndexValue = element.getAttribute("tabindex");
      tabIndex = tabIndexValue === "" ? 0 : parseInt(tabIndexValue);
      if (!(isClickable || isNaN(tabIndex) || tabIndex < 0)) {
        isClickable = onlyHasTabIndex = true;
      }
      if (isClickable) {
        clientRect = DomUtilities.getVisibleClientRect(element, true);
        if (clientRect !== null) {
          visibleElements.push({
            element: element,
            rect: clientRect,
            secondClassCitizen: onlyHasTabIndex
          });
        }
      }
      return visibleElements;
    };

    FreeTextBrowsing.prototype.getLinkHint = (function() {
      var allCallbacks, debounced, funky;
      allCallbacks = [];
      debounced = null;
      funky = function(callback, count) {
        voiceCodeForeground.backgroundMessage('invokeBound', {
          namespace: 'HintDispenser',
          method: 'getHints',
          argumentsObject: {
            count: count
          }
        }, callback);
        return debounced = null;
      };
      return function(callback) {
        allCallbacks.push(callback);
        if (debounced == null) {
          debounced = _.debounce(funky, 10);
        }
        return debounced(function(arg) {
          var hints;
          hints = arg.hints;
          return _.each(hints, function(hint) {
            return (allCallbacks.shift())(hint);
          });
        }, allCallbacks.length);
      };
    })();

    FreeTextBrowsing.prototype.reserveLinkHint = (function() {
      var allCallbacks, debounced, funky, reservations;
      allCallbacks = [];
      reservations = [];
      debounced = null;
      funky = function(callback, reservations) {
        voiceCodeForeground.backgroundMessage('invokeBound', {
          namespace: 'HintDispenser',
          method: 'reserveHints',
          argumentsObject: {
            reservations: reservations
          }
        }, callback);
        return debounced = null;
      };
      return function(id, desiredInteger, callback) {
        allCallbacks.push(callback);
        reservations.push({
          id: id,
          desiredInteger: desiredInteger
        });
        if (debounced == null) {
          debounced = _.debounce(funky, 10);
        }
        return debounced(function(arg) {
          var reservations;
          reservations = arg.reservations;
          return _.each(reservations, function() {
            return (allCallbacks.pop())(reservations);
          });
        }, reservations);
      };
    })();

    FreeTextBrowsing.prototype.resetHintDispenser = function() {
      return voiceCodeForeground.backgroundMessage('invokeBound', {
        namespace: 'HintDispenser',
        method: 'reset'
      });
    };

    FreeTextBrowsing.prototype.getLinkText = function(element) {
      var linkText, nodeName;
      linkText = '';
      nodeName = element.nodeName.toLowerCase();
      if (nodeName === "input") {
        if (this.labelMap[element.id]) {
          linkText = this.labelMap[element.id];
        } else if (element.type !== "password") {
          linkText = element.value;
          if (!linkText && 'placeholder' in element) {
            linkText = element.placeholder;
          }
        }
        if (linkText == null) {
          linkText = '';
        }
      } else if (nodeName === "a" && !element.textContent.trim() && element.firstElementChild && element.firstElementChild.nodeName.toLowerCase() === "img") {
        linkText = element.firstElementChild.alt || element.firstElementChild.title;
      } else if ($(element).attr('aria-label') != null) {
        linkText = $(element).attr('aria-label');
      } else {
        linkText = DomUtilities.textContent.get(element);
      }
      if (linkText !== '') {
        return this.formatText(linkText.substring(0, 2000));
      }
    };

    FreeTextBrowsing.prototype.getVisibleClickableElements = function(elements) {
      var element, j, k, len, len1, negativeRect, nonOverlappingElements, rects, ref, visibleElement, visibleElements;
      if (elements == null) {
        elements = null;
      }
      if (elements == null) {
        elements = document.documentElement.getElementsByTagName("*");
      }
      visibleElements = [];
      for (j = 0, len = elements.length; j < len; j++) {
        element = elements[j];
        visibleElement = this.getVisibleClickable(element);
        visibleElements.push.apply(visibleElements, visibleElement);
      }
      nonOverlappingElements = [];
      visibleElements = visibleElements.reverse();
      while (visibleElement = visibleElements.pop()) {
        rects = [visibleElement.rect];
        for (k = 0, len1 = visibleElements.length; k < len1; k++) {
          negativeRect = visibleElements[k].rect;
          rects = (ref = []).concat.apply(ref, rects.map(function(rect) {
            return Rect.subtract(rect, negativeRect);
          }));
        }
        if (rects.length > 0) {
          nonOverlappingElements.push({
            element: visibleElement.element,
            rect: rects[0]
          });
        } else {
          if (!visibleElement.secondClassCitizen) {
            nonOverlappingElements.push(visibleElement);
          }
        }
      }
      return nonOverlappingElements;
    };

    FreeTextBrowsing.prototype.purgeMarkerContainer = function() {
      return $('#voicecodeMarkerContainer').empty();
    };

    FreeTextBrowsing.prototype.createMarkerContainer = function() {
      var container;
      if ($('#voicecodeMarkerContainer')[0] != null) {
        return;
      }
      container = $('<div>');
      container.attr('id', 'voicecodeMarkerContainer');
      container.addClass('voicecodeMarkerContainer voicecodeReset');
      return $('body').append(container);
    };

    FreeTextBrowsing.prototype.createMarkerElement = function(link) {
      var child, marker;
      if (link.secondClassCitizen) {
        console.error('ENCOUNTERED SECOND-CLASS CITIZEN');
      }
      marker = $('<div>');
      marker.addClass("voicecodeReset internalVoiceCodeHintMarker voicecodeHintMarker");
      marker.attr('data-vc-marker-for', link.id);
      child = $('<span>').addClass('voicecodeReset voicecodeHint');
      child.text(link.hint + ': ' + link.text);
      child.on('click', function() {
        var id;
        id = $(this).parent().attr('data-vc-marker-for');
        return console.debug($("\#" + id));
      });
      marker.append(child);
      marker.css('left', link.rect.left + window.scrollX + "px");
      marker.css('top', link.rect.top + window.scrollY + "px");
      marker.hide();
      return marker;
    };

    FreeTextBrowsing.prototype.createMarkers = function(linkList) {
      if (linkList == null) {
        linkList = this.linkList;
      }
      return _.each(linkList, (function(_this) {
        return function(link) {
          return _this.createMarker(link);
        };
      })(this));
    };

    FreeTextBrowsing.prototype.createMarker = function(link) {
      var _this;
      if (link.hint != null) {
        this.appendMarkerElement(this.createMarkerElement(link));
        if (this.shouldShowMarkerFor(link)) {
          return this.showMarkerFor(link);
        }
      } else {
        _this = this;
        return this.getLinkHint((function(link, _this) {
          return function(arg) {
            var hint;
            hint = arg.hint;
            link.hint = hint;
            _this.linkList[link.id] = link;
            _this.appendMarkerElement(_this.createMarkerElement(link));
            if (_this.shouldShowMarkerFor(link)) {
              return _this.showMarkerFor(link);
            }
          };
        })(link, _this));
      }
    };

    FreeTextBrowsing.prototype.appendMarkerElement = function(marker) {
      return $('#voicecodeMarkerContainer').append(marker);
    };

    FreeTextBrowsing.prototype.removeMarkerFor = function(link) {
      return $('#voicecodeMarkerContainer').find("div[data-vc-marker-for='" + link.id + "']").remove();
    };

    FreeTextBrowsing.prototype.hideMarkerFor = function(link) {
      return $('#voicecodeMarkerContainer').find("div[data-vc-marker-for='" + link.id + "']").hide();
    };

    FreeTextBrowsing.prototype.showMarkerFor = function(link, opacity) {
      if (opacity == null) {
        opacity = 1;
      }
      return $('#voicecodeMarkerContainer').find("div[data-vc-marker-for='" + link.id + "']").css('opacity', opacity).show();
    };

    FreeTextBrowsing.prototype.showMarkers = function(linkList, opacity) {
      if (linkList == null) {
        linkList = this.linkList;
      }
      if (opacity == null) {
        opacity = 1;
      }
      return _.each(linkList, (function(_this) {
        return function(link) {
          return _this.showMarkerFor(link, opacity);
        };
      })(this));
    };

    FreeTextBrowsing.prototype.hideMarkers = function(linkList) {
      if (linkList == null) {
        linkList = this.linkList;
      }
      return _.each(linkList, (function(_this) {
        return function(link) {
          return _this.hideMarkerFor(link);
        };
      })(this));
    };

    FreeTextBrowsing.prototype.getUrlTexts = function(linkList) {
      var expression, urlTexts;
      expression = new RegExp(/^(?:(?:https?|ftp):\/\/)(?:\S+(?::\S*)?@)?(?:(?!(?:10|127)(?:\.\d{1,3}){3})(?!(?:169\.254|192\.168)(?:\.\d{1,3}){2})(?!172\.(?:1[6-9]|2\d|3[0-1])(?:\.\d{1,3}){2})(?:[1-9]\d?|1\d\d|2[01]\d|22[0-3])(?:\.(?:1?\d{1,2}|2[0-4]\d|25[0-5])){2}(?:\.(?:[1-9]\d?|1\d\d|2[0-4]\d|25[0-4]))|(?:(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)(?:\.(?:[a-z\u00a1-\uffff0-9]-*)*[a-z\u00a1-\uffff0-9]+)*(?:\.(?:[a-z\u00a1-\uffff]{2,}))\.?)(?::\d{2,5})?(?:[\/?#]\S*)?$/i);
      urlTexts = _.filter(linkList, function(link, id) {
        return link.text.match(expression);
      });
      if (urlTexts.length) {
        return console.error(urlTexts);
      }
    };

    FreeTextBrowsing.prototype.registerMutationObserver = function() {
      return observer.observe(document, {
        attributes: true,
        childList: true,
        characterData: true,
        subtree: true
      });
    };

    FreeTextBrowsing.prototype.activateLink = function(linkId) {
      var link, ref;
      link = this.linkList[linkId];
      if (DomUtilities.isSelectable(link.element)) {
        return DomUtilities.simulateSelect(link.element);
      } else {
        if (link.element.nodeName.toLowerCase() === "input" && ((ref = link.element.type) !== "button" && ref !== "submit")) {
          link.element.focus();
        }
        DomUtilities.flashRect(link.rect);
        return DomUtilities.simulateClick(link.element);
      }
    };

    FreeTextBrowsing.prototype.updateMatchedLinks = function(arg) {
      var matchedLinks;
      matchedLinks = arg.matchedLinks;
      console.dir(matchedLinks);
      if (_.isEmpty(matchedLinks)) {
        $('body').shake();
        this.clearRemoteSearchQuery();
        console.error('NOTHING FOUND!');
        return;
      }
      return _.each(matchedLinks, (function(_this) {
        return function(links, measure) {
          var opacity;
          opacity = Math.round(measure * 1) / 10;
          if (_this.matchingMode === BESTMATCH && links.length === 1) {
            _this.activateLink(links[0].id);
            console.warn(voiceCodeForeground.getIdentity());
            _this.clearRemoteSearchQuery();
          } else {
            _this.state = MULTIPLE_MATCHES;
            _this.captureViewportState().hide();
            return _this.showMarkers(links);
          }
        };
      })(this));
    };

    FreeTextBrowsing.prototype.getPreviousViewportState = function() {
      return this.capturedViewportStates.pop();
    };

    FreeTextBrowsing.prototype.captureViewportState = function() {
      return this.capturedViewportStates.push($('#voicecodeMarkerContainer').find('div.voicecodeHintMarker:visible'));
    };

    FreeTextBrowsing.prototype.restoreViewportState = function() {
      var previousViewportState;
      previousViewportState = this.getPreviousViewportState();
      if (previousViewportState != null) {
        $('#voicecodeMarkerContainer').find('div.voicecodeHintMarker:visible').hide();
        previousViewportState.show();
        return this.coapturedViewportState = null;
      }
    };

    return FreeTextBrowsing;

  })();

  this.FreeTextBrowsing = FreeTextBrowsing;

  this.KeyboardController = KeyboardController;

  this.Settings = Settings;

  jQuery.fn.shake = function() {
    this.each(function(i) {
      var x;
      $(this).css({
        'position': 'relative'
      });
      x = 1;
      while (x <= 3) {
        $(this).animate({
          left: -25
        }, 10).animate({
          left: 0
        }, 50).animate({
          left: 25
        }, 10).animate({
          left: 0
        }, 50);
        x++;
      }
    });
    return this;
  };

}).call(this);