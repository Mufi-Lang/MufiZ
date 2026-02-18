# Analysis API Quick Reference Card

## Context Management

```c
// Create context
void* ctx = mufiz_create_analysis_context();

// Update source (triggers parsing)
bool ok = mufiz_update_source(ctx, "file.mufi", source);

// Destroy context
mufiz_destroy_analysis_context(ctx);
```

## Diagnostics

```c
// Get count
int32_t count = mufiz_get_diagnostic_count(ctx);

// Get diagnostic
const MufizDiagnostic* diag = mufiz_get_diagnostic(ctx, index);

// Access diagnostic fields
diag->range.start.line;     // uint32_t
diag->range.start.column;   // uint32_t
diag->severity;              // MUFIZ_DIAGNOSTIC_ERROR (1) or _WARNING (2)
diag->message;               // const char*
```

## Autocompletion

```c
// Compute completions at position
int32_t count = mufiz_compute_completions(ctx, line, column);

// Get completion item
const MufizCompletionItem* item = mufiz_get_completion_item(ctx, index);

// Access item fields
item->name;        // const char*
item->type_name;   // const char*
item->doc_string;  // const char*
item->kind;        // uint8_t: 1=Variable, 2=Function, 3=Struct
```

## Hover Info

```c
// Get hover at position
const MufizCompletionItem* hover = mufiz_get_hover_info(ctx, line, column);

if (hover) {
    printf("%s: %s\n", hover->name, hover->type_name);
}
```

## Data Structures

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
    const char* type_name;
    const char* doc_string;
    uint8_t kind;
} MufizCompletionItem;
```

## Complete Example

```c
#include "mufiz.h"
#include <stdio.h>

int main(void) {
    // Create context
    void* ctx = mufiz_create_analysis_context();
    if (!ctx) return 1;
    
    // Parse source
    const char* source = "var x = 10;\nvar y = x +;";
    mufiz_update_source(ctx, "test.mufi", source);
    
    // Show diagnostics
    int32_t diag_count = mufiz_get_diagnostic_count(ctx);
    for (int32_t i = 0; i < diag_count; i++) {
        const MufizDiagnostic* d = mufiz_get_diagnostic(ctx, i);
        printf("[%d:%d] %s\n", d->range.start.line, 
               d->range.start.column, d->message);
    }
    
    // Get completions
    int32_t comp_count = mufiz_compute_completions(ctx, 1, 10);
    for (int32_t i = 0; i < comp_count; i++) {
        const MufizCompletionItem* item = mufiz_get_completion_item(ctx, i);
        printf("  %s (%s)\n", item->name, item->type_name);
    }
    
    // Get hover info
    const MufizCompletionItem* hover = mufiz_get_hover_info(ctx, 0, 5);
    if (hover) {
        printf("Hover: %s: %s\n", hover->name, hover->type_name);
    }
    
    // Clean up
    mufiz_destroy_analysis_context(ctx);
    return 0;
}
```

## Compilation

```bash
# macOS
gcc -I/path/to/include test.c -L/path/to/lib -lmufiz -framework CoreFoundation

# Linux
gcc -I/path/to/include test.c -L/path/to/lib -lmufiz -lpthread -lm -ldl

# Windows
gcc -I/path/to/include test.c -L/path/to/lib -lmufiz -lws2_32
```

## Pointer Lifetimes

| Function | Returned Pointer Valid Until |
|----------|------------------------------|
| `mufiz_get_diagnostic()` | Next `mufiz_update_source()` |
| `mufiz_get_completion_item()` | Next `mufiz_compute_completions()` |
| `mufiz_get_hover_info()` | Next `mufiz_get_hover_info()` |

## NULL Safety

All functions safely handle `NULL` contexts:
- `mufiz_get_diagnostic_count(NULL)` → `0`
- `mufiz_get_diagnostic(NULL, i)` → `NULL`
- `mufiz_compute_completions(NULL, l, c)` → `0`
- `mufiz_get_completion_item(NULL, i)` → `NULL`
- `mufiz_get_hover_info(NULL, l, c)` → `NULL`
- `mufiz_destroy_analysis_context(NULL)` → (no-op)

## Thread Safety

⚠️ **Each context is NOT thread-safe**

Safe pattern:
```c
// One context per thread/file
void* ctx1 = mufiz_create_analysis_context();  // Thread 1
void* ctx2 = mufiz_create_analysis_context();  // Thread 2
```

Unsafe pattern:
```c
// Shared context without locks - DON'T DO THIS
void* ctx = mufiz_create_analysis_context();
// Thread 1 and 2 both use ctx - RACE CONDITION!
```

## LSP Integration Pattern

```c
// Per-document context
typedef struct {
    char* uri;
    void* ctx;
} Document;

void on_open(const char* uri, const char* text) {
    Document* doc = malloc(sizeof(Document));
    doc->ctx = mufiz_create_analysis_context();
    mufiz_update_source(doc->ctx, uri, text);
    publish_diagnostics(doc);
}

void on_change(Document* doc, const char* text) {
    mufiz_update_source(doc->ctx, doc->uri, text);
    publish_diagnostics(doc);
}

void on_completion(Document* doc, uint32_t line, uint32_t col) {
    int32_t count = mufiz_compute_completions(doc->ctx, line, col);
    for (int32_t i = 0; i < count; i++) {
        send_completion(mufiz_get_completion_item(doc->ctx, i));
    }
}

void on_close(Document* doc) {
    mufiz_destroy_analysis_context(doc->ctx);
    free(doc);
}
```

## Error Handling

```c
// Parse failure
if (!mufiz_update_source(ctx, "file.mufi", source)) {
    fprintf(stderr, "Parse failed\n");
}

// No diagnostics found
if (mufiz_get_diagnostic_count(ctx) == 0) {
    printf("No errors!\n");
}

// Index out of bounds
const MufizDiagnostic* d = mufiz_get_diagnostic(ctx, 999);
if (!d) {
    fprintf(stderr, "Invalid index\n");
}

// No hover info at position
const MufizCompletionItem* h = mufiz_get_hover_info(ctx, line, col);
if (!h) {
    printf("No symbol at position\n");
}
```

## Performance Tips

1. **Reuse contexts** for the same file
2. **Batch diagnostics** - get all at once rather than one-by-one
3. **Avoid unnecessary re-parsing** - only call `update_source()` when changed
4. **Use separate contexts** for concurrent file analysis
5. **Clean up** unused contexts to free memory

## Memory Usage

| Item | Approximate Size |
|------|------------------|
| Context overhead | ~1-5 KB |
| Per diagnostic | ~64 bytes + message length |
| Per symbol | ~32 bytes + string data |
| Completion results | Temporary (freed on next query) |

## See Also

- **Full Documentation**: `docs/ANALYSIS_API_IMPLEMENTATION.md`
- **Usage Examples**: `examples/analysis/README.md`
- **C API Guide**: `docs/C_API_GUIDE.md`
- **LSP Requirements**: `docs/LIBMUFIZ_LSP_REQUIREMENTS.md`
