test = require 'tape'
coffee = require 'coffee-script'
interlace = require './interlace.js'

testCases = '''
require() is variadic
---
rotate debug
---
context.rotate(console.debug);
===
Processes require() when resolved
---
rotate bar
---
context.rotate(bar);
===
Does not affect identifiers when unresolved
---
rotate2 bar
---
rotate2(bar);
===

Affects functions
---
rotate bar
---
context.rotate(bar);
===

Affects vars
---
fillStyle = bar
---
context.fillStyle = bar;
===

Affects objects
---
canvas.width = bar
---
context.domElement.width = bar;
===

Affects functions in blocks
---
foo -> bar -> rotate bar
---
foo(function () {
    return bar(function () {
        return context.rotate(bar);
    });
});
===

Does not affect function params
---
foo -> bar (fillStyle) -> rotate 10
---
foo(function () {
    return bar(function (fillStyle) {
        return context.rotate(10);
    });
});
===

Does not affect locals in functions
---
foo -> bar (fillStyle) -> rotate fillStyle
---
foo(function () {
    return bar(function (fillStyle) {
        return context.rotate(fillStyle);
    });
});
===

Affects vars in blocks
---
foo -> bar -> fillStyle = bar
---
foo(function () {
    return bar(function () {
        return context.fillStyle = bar;
    });
});
===

Affects objects in blocks
---
foo -> bar -> canvas.width = bar
---
foo(function () {
    return bar(function () {
        return context.domElement.width = bar;
    });
});
===

Affects functions in arguments
---
rotate round PI
---
context.rotate(Math.round(Math.PI));
===

Affects arguments
---
rotate PI
---
context.rotate(Math.PI);
===

Affects objects in arguments
---
rotate canvas.angle
---
context.rotate(context.domElement.angle);
===

Qualifies member chains
---
x = latLng 10, 20
---
var x;
x = foo.bar.baz.maps.LatLng(10, 20);
===

Aliases functions
---
rotate foo
---
context.rotate(foo);
===

Aliases vars
---
canvas = bar
---
context.domElement = bar;
===

Aliases objects
---
canvas.width = bar
---
context.domElement.width = bar;
===

Does not affect functions with aliased names
---
setTransform foo
---
setTransform(foo);
===

Does not affect vars with aliased names
---
domElement = bar
---
var domElement;
domElement = bar;
===

Does not affect object methods
---
foo.rotate bar
---
foo.rotate(bar);
===

Does not affect object members
---
foo.fillStyle bar
---
foo.fillStyle(bar);
===

Does not affect object chains
---
foo.canvas.foo = bar
---
foo.canvas.foo = bar;
===

Affects object literal values
---
x = target: canvas
---
var x;
x = { target: context.domElement };
===

Does not affect object literal keys
---
x = canvas: 'bar'
---
var x;
x = { canvas: 'bar' };
===

Transforms functions to invocations
---
shift foo
push foo, bar
push foo, bar, baz, qux
push [], bar, baz, qux
push (foo), bar, baz, qux
push ([]), bar, baz, qux
---
foo.shift();
foo.push(bar);
foo.push(bar, baz, qux);
[].push(bar, baz, qux);
foo.push(bar, baz, qux);
[].push(bar, baz, qux);
===

Does not transform object properties to invocations
---
foo.push bar
foo.push.apply null, []
[].push.apply null, []
---
foo.push(bar);
foo.push.apply(null, []);
[].push.apply(null, []);
===

Does not transform functions without arguments to invocations
---
shift()
push()
---
shift();
push();
===

Transforms function aliases into object invocations
---
toUrl foo
toUrl ''
contextOf foo, bar
contextOf foo, bar, baz, qux
contextOf [], bar, baz, qux
contextOf (foo), bar, baz, qux
contextOf ([]), bar, baz, qux
---
foo.toDataURL();
''.toDataURL();
foo.getContext(bar);
foo.getContext(bar, baz, qux);
[].getContext(bar, baz, qux);
foo.getContext(bar, baz, qux);
[].getContext(bar, baz, qux);
'''

symbols =
  # qualification
  round: type: 'qualify', object: 'Math'
  PI: type: 'qualify', object: 'Math'
  rotate: type: 'qualify', object: 'context'
  transform: type: 'qualify', object: 'context', property: 'setTransform'
  fillStyle: type: 'qualify', object: 'context'
  canvas: type: 'qualify', object: 'context', property: 'domElement'
  debug: type: 'qualify', object: 'console'
  latLng: type: 'qualify', object: 'foo.bar.baz.maps', property: 'LatLng'

  # invocation
  push: type: 'invoke'
  shift: type: 'invoke'
  toUrl: type: 'invoke', property: 'toDataURL'
  contextOf: type: 'invoke', property: 'getContext'

testCases.split(/\={3,}/g).forEach (testCase) ->
  [ assertion, coffeescript, expected ] = testCase.split /\-{3,}/g
  if assertion and coffeescript
    test assertion.trim(), (t) ->
      t.plan 1
      javascript = coffee.compile coffeescript.trim(), bare: yes
      actual = interlace symbols, javascript
      t.equal actual.trim(), expected.trim()

