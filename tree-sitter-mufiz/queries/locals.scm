; Scopes
(block_statement) @local.scope
(function_declaration) @local.scope
(method_declaration) @local.scope
(class_declaration) @local.scope
(for_statement) @local.scope
(foreach_statement) @local.scope

; Definitions
(variable_declaration
  name: (identifier) @local.definition.variable)

(function_declaration
  name: (identifier) @local.definition.function)

(method_declaration
  name: (identifier) @local.definition.method)

(class_declaration
  name: (identifier) @local.definition.type)

(parameter_list
  (identifier) @local.definition.parameter)

(foreach_statement
  variable: (identifier) @local.definition.parameter)

; References
(identifier) @local.reference