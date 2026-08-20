; Axión syntax highlighting. Later patterns win over earlier ones for the same node,
; so general captures come first and specific ones (function/parameter names) override.

; --- comments & literals ---
(comment) @comment
(string) @string
(char) @character
(integer) @number
(float) @number.float

; --- the linearity mark (%1 / %0.5) — Axión's distinctive annotation ---
(multiplicity) @keyword.storage.modifier

; --- names ---
(variable) @variable
(type_constructor) @type
(constructor) @constructor

; a variable at the head of a definition / signature / foreign is a function
(function_equation name: (variable) @function)
(type_signature name: (variable) @function)
(foreign_declaration name: (variable) @function)

; a constructor being declared, and the type being declared
(data_constructor name: (constructor) @constructor)
(data_declaration name: (type_constructor) @type)
(class_declaration name: (type_constructor) @type)

; --- keywords ---
[
  "module" "import" "qualified" "as"
  "data" "class" "instance" "foreign" "deriving"
  "where" "let" "in"
] @keyword

[
  "if" "then" "else" "case" "of" "do"
] @keyword.control

; --- operators & punctuation ---
(operator) @operator
[
  "::" "->" "=>" "=" "|" "<-" ".." "\\"
] @operator

[ "(" ")" "[" "]" "{" "}" ] @punctuation.bracket
[ "," "." ] @punctuation.delimiter
