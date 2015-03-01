_ = require 'lodash'
esprima = require 'esprima'
escodegen = require 'escodegen'

collectLocals = (node, opts) ->
  return null unless node

  switch node.type
    when 'VariableDeclaration'
      if opts.preserveLocals
        return (type: 'preserve', name: declaration.id.name for declaration in node.declarations when declaration.type is 'VariableDeclarator' and declaration.id.type is 'Identifier')
        
    when 'FunctionDeclaration'
      if node.id.type is 'Identifier'
        return [ type: 'preserve', name: node.id.name ]

    when 'ForStatement'
      return collectLocals node.init, opts

    when 'ForInStatement', 'ForOfStatement'
      return collectLocals node.left, opts

  return null


createScope = (block, opts) ->
  symbols = []

  for node in block.body
    if declarations = collectLocals node, opts
      for declaration in declarations
        symbols.push declaration

  _.indexBy symbols, (symbol) -> symbol.name


combineScopes = (scope1, scope2) ->
  scope = {}

  for name, symbol of scope1
    scope[name] = symbol

  for name, symbol of scope2
    scope[name] = symbol

  scope


coalesceScopes = (scopes) ->
  currentScope = {}
  for scope, i in scopes
    if i is 0
      for name, symbol of scope
        currentScope[name] = symbol
    else
      for name, symbol of scope
        currentScope[name] = null
  currentScope


createLocalScope = (node, opts) ->
  # parse all declarations in this scope
  localScope = createScope node.body, opts

  # include function parameters
  if node.type is 'FunctionExpression' or node.type is 'FunctionDeclaration'
    for param in node.params when param.type is 'Identifier'
      localScope[param.name] = type: 'preserve', name: param.name

  localScope


traverse = (opts, scopes, parentScope, parent, node, f) ->
  isNewScope = node.type is 'FunctionExpression' or node.type is 'FunctionDeclaration'
  if isNewScope
    # create and push a new local scope onto scope stack
    scopes.push createLocalScope node, opts
    currentScope = coalesceScopes scopes
  else
    currentScope = parentScope

  if _.isArray node
    key = node.length
    # walk backwards to allow callers to delete nodes
    while key--
      child = node[key]
      if child isnt null and (_.isObject child) and not _.isFunction child
        traverse opts, scopes, currentScope, node, child, f
        f currentScope, node, key, child 
  else
    for key, child of node
      if child isnt null and (_.isObject child) and not _.isFunction child
        traverse opts, scopes, currentScope, node, child, f
        f currentScope, node, key, child 

  if isNewScope
    # discard local scope
    scopes.pop()

  return


purge = (parent, i) ->
  if _.isArray parent
    parent.splice i, 1
  else if _.isObject parent
    delete parent[i]


interlace = (symbols, javascript, opts={}) ->
  program = esprima.parse javascript

  rootScope = createScope program, opts

  globalScope = combineScopes rootScope, symbols

  traverse opts, [ globalScope ], globalScope, null, program, (currentScope, parent, key, node) ->

    if node.type is 'VariableDeclaration'		
      declarations = node.declarations.filter (declaration) ->		
        if declaration.type is 'VariableDeclarator' and declaration.id.type is 'Identifier'
          if symbol = currentScope[declaration.id.name]		
            symbol.type is 'preserve'
          else
            yes
        else
          yes
      if declarations.length is 0		
        # purge this node so that escodegen doesn't fail
        purge parent, key	
      else		
        # replace with cleaned-up declarations
        node.declarations = declarations

    else if node.type is 'Identifier'
      return if parent.type is 'VariableDeclarator' and key is 'id' # ignore variable declarations
      return if parent.type is 'Property' and key is 'key' # ignore property keys in object literals
      return if key is 'property' # ignore members
      return unless symbol = currentScope[node.name]
      return unless symbol.type is 'qualify'
      parent[key] =
        type: 'MemberExpression'
        computed: no
        object:
          type: 'Identifier'
          name: symbol.object
        property:
          type: 'Identifier'
          name: symbol.property ? node.name

    else if node.type is 'CallExpression'
      return unless node.callee.type is 'Identifier'
      return unless symbol = currentScope[node.callee.name]
      return unless symbol.type is 'invoke'
      return unless node.arguments.length > 0
      [ first, rest... ] = node.arguments
      node.callee =
        type: 'MemberExpression'
        computed: no
        object: first
        property:
          type: 'Identifier'
          name: symbol.property or node.callee.name
      node.arguments = rest
    return
    
  escodegen.generate program

module.exports = interlace
