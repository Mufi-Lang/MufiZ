# MufiZ Analysis API Example

This directory contains a comprehensive example demonstrating the MufiZ Analysis API, which provides static code analysis capabilities for Language Server Protocol (LSP) support and IDE integration.

## Overview

The Analysis API allows you to:
- **Parse MufiZ source code** without executing it
- **Detect syntax and semantic errors** (diagnostics)
- **Provide autocompletion suggestions** based on available symbols
- **Show hover information** (type and documentation) for symbols
- **Support multiple analysis contexts** for concurrent file analysis

## Building the Example

### Prerequisites

1. Build the MufiZ library first:
   ```bash
   cd ../..
   zig build -Doptimize=ReleaseFast
   ```

2. Ensure `libmufiz` is built in `../../zig-out/lib/`

### Compile and Run

```bash
make        # Build the test
make run    # Build and run the test
make clean  # Clean build artifacts
```

Alternatively, compile manually:

```bash
# macOS
gcc -Wall -Wextra -std=c99 \
    -I../../zig-out/include \
    test_analysis.c \
    -L../../zig-out/lib \
    -lmufiz -framework CoreFoundation \
    -o test_analysis

# Linux
gcc -Wall -Wextra -std=c99 \
    -I../../zig-out/include \
    test_analysis.c \
    -L../../zig-out/lib \
    -lmufiz -lpthread -lm -ldl \
    -o test_analysis

# Windows (MinGW)
gcc -Wall -Wextra -std=c99 \
    -I../../zig-out/include \
    test_analysis.c \
    -L../../zig-out/lib \
    -lmufiz -lws2_32 \
    -o test_analysis.exe
```

## API Reference

### Data Structures

#### `MufizDiagnosticSeverity`
```c
typedef enum {
    MUFIZ_DIAGNOSTIC_ERROR = 1,
    MUFIZ_DIAGNOSTIC_WARNING = 2
} MufizDiagnosticSeverity;
```

#### `MufizPosition`
```c
typedef struct {
    uint32_t line;
    uint32_t column;
} MufizPosition;
```

#### `MufizRange`
```c
typedef struct {
    MufizPosition start;
    MufizPosition end;
} MufizRange;
```

#### `MufizDiagnostic`
```c
typedef struct {
    MufizRange range;
    MufizDiagnosticSeverity severity;
    const char* message;
} MufizDiagnostic;
```

#### `MufizCompletionItem`
```c
typedef struct {
    const char* name;
    const char* type_name;
    const char* doc_string;
    uint8_t kind; // 1=Variable, 2=Function, 3=Struct
} MufizCompletionItem;
```

### Functions

#### Context Management

**`mufiz_create_analysis_context()`**
```c
void* mufiz_create_analysis_context(void);
```
Creates a new analysis context for static code analysis. Returns an opaque pointer to the context, or NULL on allocation failure.

**`mufiz_destroy_analysis_context()`**
```c
void mufiz_destroy_analysis_context(void* context);
```
Destroys an analysis context and frees all associated resources. Safe to call with NULL.

**`mufiz_update_source()`**
```c
bool mufiz_update_source(void* context, const char* filename, const char* source);
```
Updates the source code in the context and triggers re-parsing. Returns true if parsing succeeded.

#### Diagnostics

**`mufiz_get_diagnostic_count()`**
```c
int32_t mufiz_get_diagnostic_count(void* context);
```
Returns the number of diagnostics (errors and warnings) found during parsing.

**`mufiz_get_diagnostic()`**
```c
const MufizDiagnostic* mufiz_get_diagnostic(void* context, int32_t index);
```
Returns a pointer to a specific diagnostic. The pointer is valid until the next call to `mufiz_update_source()`.

#### Autocompletion

**`mufiz_compute_completions()`**
```c
int32_t mufiz_compute_completions(void* context, uint32_t line, uint32_t column);
```
Computes completion items at a specific cursor position. Returns the number of items found.

**`mufiz_get_completion_item()`**
```c
const MufizCompletionItem* mufiz_get_completion_item(void* context, int32_t index);
```
Returns a specific completion item. The pointer is valid until the next call to `mufiz_compute_completions()`.

#### Hover Information

**`mufiz_get_hover_info()`**
```c
const MufizCompletionItem* mufiz_get_hover_info(void* context, uint32_t line, uint32_t column);
```
Returns type and documentation information for the symbol at the cursor position. Returns NULL if no symbol is found.

## Usage Examples

### Example 1: Basic Analysis

```c
#include "mufiz.h"
#include <stdio.h>

int main(void) {
    // Create analysis context
    void* ctx = mufiz_create_analysis_context();
    if (!ctx) {
        fprintf(stderr, "Failed to create context\n");
        return 1;
    }

    // Parse source code
    const char* source = "var x = 10;\nvar y = 20;";
    if (!mufiz_update_source(ctx, "test.mufi", source)) {
        fprintf(stderr, "Parse failed\n");
    }

    // Check diagnostics
    int32_t diag_count = mufiz_get_diagnostic_count(ctx);
    printf("Found %d diagnostics\n", diag_count);

    // Clean up
    mufiz_destroy_analysis_context(ctx);
    return 0;
}
```

### Example 2: Error Detection

```c
#include "mufiz.h"
#include <stdio.h>

int main(void) {
    void* ctx = mufiz_create_analysis_context();
    
    // Parse code with syntax error
    const char* source = "var x = 10 +;";  // Missing operand
    mufiz_update_source(ctx, "error.mufi", source);
    
    // Display errors
    int32_t count = mufiz_get_diagnostic_count(ctx);
    for (int32_t i = 0; i < count; i++) {
        const MufizDiagnostic* diag = mufiz_get_diagnostic(ctx, i);
        if (diag) {
            printf("[%d:%d] %s: %s\n",
                diag->range.start.line,
                diag->range.start.column,
                diag->severity == MUFIZ_DIAGNOSTIC_ERROR ? "ERROR" : "WARNING",
                diag->message);
        }
    }
    
    mufiz_destroy_analysis_context(ctx);
    return 0;
}
```

### Example 3: Autocompletion

```c
#include "mufiz.h"
#include <stdio.h>

int main(void) {
    void* ctx = mufiz_create_analysis_context();
    
    const char* source = 
        "var myVariable = 10;\n"
        "fn myFunction() { return 42; }\n";
    
    mufiz_update_source(ctx, "complete.mufi", source);
    
    // Get completions at line 1, column 25
    int32_t count = mufiz_compute_completions(ctx, 1, 25);
    printf("Found %d completions:\n", count);
    
    for (int32_t i = 0; i < count; i++) {
        const MufizCompletionItem* item = mufiz_get_completion_item(ctx, i);
        if (item) {
            printf("  - %s (%s)\n", item->name, item->type_name);
        }
    }
    
    mufiz_destroy_analysis_context(ctx);
    return 0;
}
```

### Example 4: Hover Information

```c
#include "mufiz.h"
#include <stdio.h>

int main(void) {
    void* ctx = mufiz_create_analysis_context();
    
    const char* source = "var myValue = 42;";
    mufiz_update_source(ctx, "hover.mufi", source);
    
    // Get hover info at position (line 0, column 5)
    const MufizCompletionItem* hover = mufiz_get_hover_info(ctx, 0, 5);
    if (hover) {
        printf("Symbol: %s\n", hover->name);
        printf("Type: %s\n", hover->type_name);
        if (hover->doc_string && hover->doc_string[0]) {
            printf("Doc: %s\n", hover->doc_string);
        }
    } else {
        printf("No symbol found at position\n");
    }
    
    mufiz_destroy_analysis_context(ctx);
    return 0;
}
```

## Use Cases

### Language Server Protocol (LSP) Implementation

The Analysis API is designed to support LSP implementations:

```c
// In your LSP server's didChange handler
void on_document_change(const char* uri, const char* text) {
    void* ctx = get_or_create_context(uri);
    mufiz_update_source(ctx, uri, text);
    
    // Publish diagnostics
    int32_t count = mufiz_get_diagnostic_count(ctx);
    for (int32_t i = 0; i < count; i++) {
        const MufizDiagnostic* diag = mufiz_get_diagnostic(ctx, i);
        publish_diagnostic(uri, diag);
    }
}

// In your LSP server's completion handler
void on_completion_request(const char* uri, uint32_t line, uint32_t col) {
    void* ctx = get_context(uri);
    int32_t count = mufiz_compute_completions(ctx, line, col);
    
    for (int32_t i = 0; i < count; i++) {
        const MufizCompletionItem* item = mufiz_get_completion_item(ctx, i);
        send_completion_item(item);
    }
}

// In your LSP server's hover handler
void on_hover_request(const char* uri, uint32_t line, uint32_t col) {
    void* ctx = get_context(uri);
    const MufizCompletionItem* hover = mufiz_get_hover_info(ctx, line, col);
    
    if (hover) {
        send_hover_response(hover);
    }
}
```

### IDE Integration

Use the Analysis API to provide IDE features:

1. **Real-time Error Checking**: Call `mufiz_update_source()` on every keystroke
2. **Code Completion**: Use `mufiz_compute_completions()` when user triggers completion
3. **Quick Info**: Use `mufiz_get_hover_info()` on mouse hover
4. **Symbol Navigation**: Track symbols from completion items

## Thread Safety

⚠️ **Important**: Each analysis context is **not** thread-safe. If you need to analyze multiple files concurrently:

1. Create a separate context for each thread/file
2. Use your own synchronization if sharing contexts
3. Consider using a context pool for better performance

```c
// Safe: Multiple contexts in different threads
void* ctx1 = mufiz_create_analysis_context();  // Thread 1
void* ctx2 = mufiz_create_analysis_context();  // Thread 2
```

## Performance Considerations

- **Context Reuse**: Reuse contexts for the same file to avoid allocation overhead
- **Incremental Updates**: Currently, `mufiz_update_source()` re-parses the entire file
- **Memory Management**: Analysis contexts hold parsed AST and symbol tables in memory
- **Batch Operations**: If analyzing many files, consider processing in batches

## Current Limitations

The Analysis API is currently in development and has the following limitations:

1. **Parser Integration**: The API infrastructure is in place, but full parser integration is pending
2. **Semantic Analysis**: Type checking and semantic validation are not yet implemented
3. **Incremental Parsing**: Currently re-parses the entire source on each update
4. **Symbol Resolution**: Cross-file symbol resolution is not yet supported

These features are planned for future releases.

## Related Documentation

- [C API Guide](../../docs/C_API_GUIDE.md) - Complete C API documentation
- [LSP Requirements](../../docs/LIBMUFIZ_LSP_REQUIREMENTS.md) - Original LSP design document
- [Analysis Module](../../src/analysis.zig) - Implementation source code

## Contributing

To enhance the Analysis API:

1. Implement parser hooks in `src/compiler.zig`
2. Populate diagnostics during parsing
3. Build symbol table during semantic analysis
4. Connect to type checker for hover information

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for guidelines.

## License

This example is part of the MufiZ project and is licensed under the same terms.
See [LICENSE](../../LICENSE) for details.