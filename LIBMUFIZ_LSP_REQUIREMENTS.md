# `libmufiz` API Requirements for LSP Support

To implement a robust Language Server Protocol (LSP) for Mufi within Ferrufi (or any other editor), the core runtime (`libmufiz`) needs to expose internal compilation structures via its C API.

Currently, `libmufiz` only exposes `mufiz_interpret()`, which executes code. This is insufficient for an IDE, which needs to analyze code **statically** (without running it) to provide instant feedback, autocomplete, and navigation.

## 1. Core Requirements

### A. Static Analysis (Parse Only)
We need a way to parse the source code and retrieve errors *without* execution. This is critical for "Diagnostics" (red squiggles).

**Requirement:**
- Parse a source string.
- Return a list of syntax errors (line, column, message).
- **Do not** execute side effects (no printing, no file I/O).

### B. Abstract Syntax Tree (AST) Access
To support "Go to Definition", "Find References", and "Outline View", we need to traverse the parsed code structure.

**Requirement:**
- Retrieve a simplified tree of nodes (Functions, Variable Declarations, Blocks).
- Each node must contain its source range (start line/col, end line/col).

### C. Symbol Table / Scope Access
For "Autocompletion", we need to know what variables and functions are visible at a specific position in the code.

**Requirement:**
- Query available symbols at a given line/column.
- Get details for a symbol (Type, Name, Kind: Function/Variable).

### D. Tokenizer Access (Optional but recommended)
For Semantic Syntax Highlighting (coloring variables differently from functions), we need the raw stream of tokens.

---

## 2. Proposed C API (`mufiz.h`)

Below is a proposed extension to the C API to support these features.

### Data Structures

```c
typedef enum {
    MUFIZ_DIAGNOSTIC_ERROR = 1,
    MUFIZ_DIAGNOSTIC_WARNING = 2
} MufizDiagnosticSeverity;

typedef struct {
    uint32_t line;
    uint32_t column;
} MufizPosition;

typedef struct {
    MufizPosition start;
    MufizPosition end;
} MufizRange;

typedef struct {
    MufizRange range;
    MufizDiagnosticSeverity severity;
    const char* message;
} MufizDiagnostic;

typedef struct {
    const char* name;
    const char* type_name; // e.g. "int", "fn(int)->void"
    const char* doc_string;
    uint8_t kind; // 1=Variable, 2=Function, 3=Struct
} MufizCompletionItem;
```

### Functions

#### parsing context
A compiled "Module" or "Context" handle that holds the AST state.

```c
// Create a context for static analysis (does not execute)
MUFIZ_API void* mufiz_create_analysis_context(void);
MUFIZ_API void mufiz_destroy_analysis_context(void* context);

// Update the source code in the context (triggers re-parsing)
// Returns true if parse was successful (no fatal errors)
MUFIZ_API bool mufiz_update_source(void* context, const char* filename, const char* source);
```

#### Diagnostics (Linting)

```c
// Get the number of syntax/semantic errors found
MUFIZ_API int mufiz_get_diagnostic_count(void* context);

// Get a specific diagnostic
// The returned pointer is valid until the next call to mufiz_update_source
MUFIZ_API MufizDiagnostic* mufiz_get_diagnostic(void* context, int index);
```

#### Autocompletion

```c
// Request completion items at a specific cursor position
// Returns the number of items found
MUFIZ_API int mufiz_compute_completions(void* context, uint32_t line, uint32_t column);

// Retrieve a completion item after calling compute_completions
MUFIZ_API MufizCompletionItem* mufiz_get_completion_item(void* context, int index);
```

#### Hover / Tooltip

```c
// Get type/doc info for the symbol under the cursor
// Returns NULL if nothing found
MUFIZ_API MufizCompletionItem* mufiz_get_hover_info(void* context, uint32_t line, uint32_t column);
```

---

## 3. Interim Strategy (Ferrufi Side)

Until `libmufiz` implements these APIs, Ferrufi must implement a **"Shadow Parser"** in Swift.

1.  **Swift Lexer:** Re-implement the Mufi tokenization rules in Swift.
2.  **Swift Parser:** Implement a lightweight parser that builds a rough AST.
    *   *Goal:* Detect basic syntax errors and build an outline of defined names.
    *   *Limitation:* It won't have the deep type checking of the real compiler, but it's enough for basic IDE features.
