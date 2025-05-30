; String interpolation for embedded expressions
((string) @injection.content
 (#set! injection.language "mufiz")
 (#match? @injection.content "\\$\\{.*\\}"))

; Comments that contain other languages
((comment) @injection.content
 (#match? @injection.content "^//\\s*(TODO|FIXME|NOTE|HACK):")
 (#set! injection.language "comment"))

; SQL in string literals
((string) @injection.content
 (#match? @injection.content "(?i)(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|ALTER)")
 (#set! injection.language "sql"))

; JSON in string literals
((string) @injection.content
 (#match? @injection.content "^\\s*[\\{\\[]")
 (#set! injection.language "json"))

; Regex patterns in string literals
((string) @injection.content
 (#match? @injection.content "^/.*/$")
 (#set! injection.language "regex"))

; HTML/XML in string literals
((string) @injection.content
 (#match? @injection.content "^\\s*<[^>]+>")
 (#set! injection.language "html"))

; CSS in string literals
((string) @injection.content
 (#match? @injection.content "\\{[^}]*:[^}]*\\}")
 (#set! injection.language "css"))