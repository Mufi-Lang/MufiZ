; Keywords
[
  "var"
  "fun"
  "class"
  "if"
  "else"
  "while"
  "for"
  "foreach"
  "in"
  "return"
  "print"
  "and"
  "or"
] @keyword

; Control flow
[
  "if"
  "else"
  "while"
  "for"
  "foreach"
  "return"
] @keyword.control

; Storage types
[
  "var"
  "fun"
  "class"
] @keyword.storage

; Operators
[
  "="
  "=="
  "!="
  ">"
  ">="
  "<"
  "<="
  "+"
  "-"
  "*"
  "/"
  "%"
  "!"
  "and"
  "or"
] @operator

; Punctuation
[
  ";"
  ","
  "."
  ":"
] @punctuation.delimiter

; Brackets
[
  "("
  ")"
  "["
  "]"
  "{"
  "}"
] @punctuation.bracket

; Literals
(number) @constant.numeric
(boolean) @constant.builtin.boolean
(nil) @constant.builtin
(string) @string

; Complex numbers
(complex_number
  real: (number) @constant.numeric
  imaginary: (number) @constant.numeric)

; Escape sequences in strings
(escape_sequence) @constant.character.escape

; Identifiers
(identifier) @variable

; Function names
(function_declaration
  name: (identifier) @function)

(method_declaration
  name: (identifier) @function.method)

(call_expression
  function: (identifier) @function.call)

; Class names
(class_declaration
  name: (identifier) @type)

(class_declaration
  superclass: (identifier) @type)

; Parameters
(parameter_list
  (identifier) @variable.parameter)

; Field access
(member_expression
  property: (identifier) @property)

; Variable declarations
(variable_declaration
  name: (identifier) @variable)

; Assignment targets
(assignment_expression
  left: (identifier) @variable)

; Foreach loop variables
(foreach_statement
  variable: (identifier) @variable.parameter)

; Comments
(comment) @comment

; Special keywords
"print" @keyword.function
(self) @variable.builtin
(super) @variable.builtin

; Built-in types and collections
[
  "table"
  "list"
] @type.builtin

; Built-in values
(nil) @constant.builtin