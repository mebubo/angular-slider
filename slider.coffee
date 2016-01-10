# CONSTANTS

MODULE_NAME = 'ui.slider'
SLIDER_TAG  = 'slider'

# HELPER FUNCTIONS
angularize    = (element) -> angular.element element
pixelize      = (position) -> "#{position}px"
hide          = (element) -> element.css opacity: 0
show          = (element) -> element.css opacity: 1
offset        = (element, position) -> element.css left: position
halfWidth     = (element) -> element[0].offsetWidth / 2
offsetLeft    = (element) -> element[0].offsetLeft
width         = (element) -> element[0].offsetWidth
gap           = (element1, element2) ->
  offsetLeft(element2) - offsetLeft(element1) - width(element1)

contain       = (value) ->
  return value if isNaN value
  Math.min Math.max(0, value), 100

roundStep     = (value, precision, step, floor = 0) ->
  step ?= 1 / Math.pow(10, precision)
  remainder = (value - floor) % step
  steppedValue =
    if remainder > (step / 2)
    then value + step - remainder
    else value - remainder
  decimals = Math.pow 10, precision
  roundedValue = steppedValue * decimals / decimals
  parseFloat roundedValue.toFixed precision

events =
  mouse:
    start: 'mousedown'
    move:  'mousemove'
    end:   'mouseup'
  touch:
    start: 'touchstart'
    move:  'touchmove'
    end:   'touchend'

sliderDirective = ($timeout) ->
  restrict: 'E'
  scope:
    floor:        '@'
    ceiling:      '@'
    values:       '=?'
    step:         '@'
    highlight:    '@'
    precision:    '@'
    buffer:       '@'
    ngModel:      '=?'
    change:       '&'
  template: '''
    <div class="bar"><div class="selection"></div></div>
    <div class="handle low"></div>
'''
  compile: (element, attributes) ->

    range = false

    # Scope values to watch for changes
    watchables = ['floor', 'ceiling', 'values', 'ngModel']

    post: (scope, element, attributes) ->
      # Get references to template elements
      [bar, handle] = (angularize(e) for e in element.children())
      selection = angularize bar.children()[0]

      bound = false
      ngDocument = angularize document
      handleHalfWidth = barWidth = minOffset = maxOffset = minValue = maxValue = valueRange = offsetRange = undefined

      dimensions = ->
        # roundStep the initial score values
        scope.step ?= 1
        scope.floor ?= 0
        scope.precision ?= 0
        scope.ngModelLow = scope.ngModel unless range
        scope.ceiling ?= scope.values.length - 1 if scope.values?.length

        for value in watchables
          scope[value] = roundStep(
            parseFloat(scope[value]),
            parseInt(scope.precision),
            parseFloat(scope.step),
            parseFloat(scope.floor)
          ) if typeof value is 'number'

        # Commonly used measurements
        handleHalfWidth = halfWidth handle
        barWidth = width bar

        minOffset = 0
        maxOffset = barWidth - width(handle)

        minValue = parseFloat scope.floor
        maxValue = parseFloat scope.ceiling

        valueRange = maxValue - minValue
        offsetRange = maxOffset - minOffset

      updateDOM = ->
        dimensions()

        # Translation functions
        percentOffset = (offset) -> contain ((offset - minOffset) / offsetRange) * 100
        percentValue = (value) -> contain ((value - minValue) / valueRange) * 100
        pixelsToOffset = (percent) -> pixelize percent * offsetRange / 100

        setPointers = ->
          newLowValue = percentValue scope['ngModel']
          offset handle, pixelsToOffset newLowValue
          offset selection, pixelize(offsetLeft(handle) + handleHalfWidth)

          switch true
            when attributes.highlight is 'right'
              selection.css width: pixelsToOffset 110 - newLowValue
            when attributes.highlight is 'left'
              selection.css width: pixelsToOffset newLowValue
              offset selection, 0

        bind = (handle, ref, events) ->
          currentRef = ref
          changed = false
          onEnd = ->
            handle.removeClass 'active'
            ngDocument.unbind events.move
            ngDocument.unbind events.end
            currentRef = ref
            scope.$apply()

            if changed
              scope.$eval scope.change

          onMove = (event) ->
            eventX = event.clientX or event.touches?[0].clientX or event.originalEvent?.changedTouches?[0].clientX or 0
            newOffset = eventX - element[0].getBoundingClientRect().left - handleHalfWidth
            newOffset = Math.max(Math.min(newOffset, maxOffset), minOffset)
            newPercent = percentOffset newOffset
            newValue = minValue + (valueRange * newPercent / 100.0)
            newValue = roundStep(newValue, parseInt(scope.precision), parseFloat(scope.step), parseFloat(scope.floor))
            changed = scope[currentRef] != newValue
            scope.$apply()
            setPointers()
            scope[currentRef] = newValue

            if changed
              scope.$eval scope.change

          onStart = (event) ->
            dimensions()
            handle.addClass 'active'
            setPointers()
            event.stopPropagation()
            event.preventDefault()
            ngDocument.bind events.move, onMove
            ngDocument.bind events.end, onEnd
          handle.bind events.start, onStart

        setBindings = ->
          for method in ['touch', 'mouse']
            bind handle, 'ngModel', events[method]
          bound = true

        setBindings() unless bound
        setPointers()

      $timeout updateDOM
      scope.$watch w, updateDOM, true for w in watchables
      window.addEventListener 'resize', updateDOM

qualifiedDirectiveDefinition = [
  '$timeout'
  sliderDirective
]

module = (window, angular) ->
  angular
    .module(MODULE_NAME, [])
    .directive(SLIDER_TAG, qualifiedDirectiveDefinition)

module window, window.angular
