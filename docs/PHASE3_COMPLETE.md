# Phase 3 Completion: Advanced Integration & Tooling

This document summarizes the completion of Phase 3 of the MufiZ error system enhancement project.

## Overview

Phase 3 focused on advanced integration features to make the enhanced error system production-ready:

1. **JSON Serialization for LSP/IDE Integration**
2. **Compiler Integration Helpers**
3. **Error Explanation System (`--explain E###`)**

## 1. JSON Serialization for LSP/IDE Integration

### Purpose
Enable language servers and IDEs to consume MufiZ diagnostics in a standardized format.

### Implementation

#### `JsonDiagnosticSerializer`
Located in `src/errors.zig`, this serializer converts `EnhancedErrorInfo` to JSON format compatible with Language Server Protocol (LSP) diagnostics.

**Key Features:**
- Converts error spans to LSP range format (0-indexed line/character positions)
- Maps secondary spans to `relatedInformation`
- Converts help suggestions to `codeActions` with text edits
- Includes severity, category, and error codes
- Properly escapes strings for JSON output

**Usage:**

```zig
const errors = @import("errors.zig");
const allocator = std.heap.page_allocator;

var serializer = errors.JsonDiagnosticSerializer.init(allocator);

// Serialize a single error
const json = try serializer.serializeError(error_info);
defer allocator.free(json);
print("{s}\n", .{json});

// Serialize multiple errors
const json_array = try serializer.serializeErrors(&[_]errors.EnhancedErrorInfo{
    error1, error2, error3
});
defer allocator.free(json_array);
```

**JSON Output Format:**

```json
{
  "code": "E001",
  "message": "cannot find value `x` in this scope",
  "severity": "error",
  "category": "semantic",
  "source": "example.mufi",
  "range": {
    "start": {"line": 4, "character": 10},
    "end": {"line": 4, "character": 11}
  },
  "relatedInformation": [
    {
      "location": {
        "uri": "file:///path/to/example.mufi",
        "range": {
          "start": {"line": 2, "character": 8},
          "end": {"line": 2, "character": 9}
        }
      },
      "message": "similar variable defined here"
    }
  ],
  "codeActions": [
    {
      "title": "did you mean `y`?",
      "edit": {
        "changes": [{
          "range": {
            "start": {"line": 4, "character": 10},
            "end": {"line": 4, "character": 11}
          },
          "newText": "y"
        }]
      }
    }
  ],
  "notes": ["available variables in scope: y, z"]
}
```

### LSP Integration Points

**For Language Server Implementations:**

1. **textDocument/publishDiagnostics**
   - Use `serializeErrors()` to convert all file diagnostics
   - Send to client whenever file changes

2. **textDocument/codeAction**
   - Extract `codeActions` from diagnostics
   - Return as quick-fix options

3. **workspace/diagnostic**
   - Batch serialize diagnostics across multiple files

## 2. Compiler Integration Helpers

### Purpose
Simplify the process of integrating enhanced errors into the compiler, reducing boilerplate code.

### Implementation

#### `CompilerIntegration` Helpers
Located in `src/errors.zig`, these functions provide convenient wrappers around `EnhancedTemplates`.

**Available Helpers:**

1. **`tokenToSpan()`** - Convert token position to ErrorSpan
   ```zig
   const span = CompilerIntegration.tokenToSpan(token.line, token.column, token.length);
   ```

2. **`reportUndefinedVariable()`** - Quick undefined variable error
   ```zig
   try CompilerIntegration.reportUndefinedVariable(
       manager,
       "varName",
       line, column, length,
       available_vars,
       source_code,
       file_path
   );
   ```

3. **`reportTypeMismatch()`** - Quick type error
   ```zig
   try CompilerIntegration.reportTypeMismatch(
       manager,
       "number", "string",
       line, column, length,
       source_code,
       file_path
   );
   ```

4. **`reportRedefinedVariable()`** - Quick redefinition error
5. **`reportWrongArgumentCount()`** - Quick argument count error
6. **`reportTooManyLocals()`** - Quick locals limit error
7. **`reportMethodNotFound()`** - Quick method lookup error

### Migration Pattern

**Before (Legacy):**
```zig
const errorInfo = errors.ErrorInfo{
    .code = .UNDEFINED_VARIABLE,
    .category = .SEMANTIC,
    .severity = .ERROR,
    .line = token.line,
    .column = 1,
    .length = token.length,
    .message = "Undefined variable",
    .suggestions = &[_]errors.ErrorSuggestion{},
    .file_path = "example.mufi",
};
manager.reportError(errorInfo);
```

**After (Enhanced):**
```zig
try CompilerIntegration.reportUndefinedVariable(
    manager,
    variable_name,
    token.line,
    token.column,
    token.length,
    available_vars,
    source_code,
    file_path
);
```

### Integration Checklist

To integrate enhanced errors into the compiler:

- [ ] Identify all `errorAt()` and `errorAtCurrent()` calls
- [ ] Determine which enhanced template applies
- [ ] Replace with appropriate `CompilerIntegration` helper
- [ ] Ensure source code is available for context
- [ ] Pass available variables/methods for suggestions
- [ ] Test error output with sample code

## 3. Error Explanation System

### Purpose
Provide detailed, Rust-style explanations for error codes via `--explain E###` command.

### Implementation

#### `ErrorExplainer`
Located in `src/errors.zig`, this system provides comprehensive error documentation.

**Usage:**

```zig
const explainer = errors.ErrorExplainer.init(allocator);

// Get explanation text
const explanation = try explainer.explain("E001");
print("{s}\n", .{explanation});

// Or print directly with formatting
try explainer.printExplanation("E001");

// Check if code is valid
if (errors.ErrorExplainer.isValidErrorCode("E001")) {
    // ...
}
```

**Command-Line Usage:**
```bash
mufiz --explain E001
mufiz --explain E002
```

### Available Error Codes

| Code | Title | Category | Description |
|------|-------|----------|-------------|
| E001 | Undefined Variable | Semantic | Variable not declared or out of scope |
| E002 | Type Mismatch | Type | Expression type doesn't match expected |
| E003 | Redefined Variable | Semantic | Variable name used multiple times |
| E004 | Wrong Argument Count | Semantic | Function called with wrong arg count |
| E005 | Unterminated String | Syntax | String literal missing closing quote |
| E006 | Stack Overflow | Runtime | Too many nested calls (infinite recursion) |
| E007 | Invalid Super Usage | Semantic | `super` used in non-derived class |
| E008 | Too Many Locals | Memory | Function exceeds 256 local variables |
| E009 | Method Not Found | Semantic | Method doesn't exist on class |
| E010 | Index Out of Bounds | Runtime | Array access outside valid range |

### Explanation Format

Each explanation includes:

1. **Title and Code** - E.g., "E001: Undefined Variable"
2. **Description** - What the error means
3. **Example** - Code that triggers the error
4. **Common Causes** - Why it happens
5. **Solutions** - How to fix it (multiple approaches)
6. **Additional Notes** - Related concepts and tips

**Example Explanation:**

```
E001: Undefined Variable

This error occurs when you try to use a variable that hasn't been declared
or is not in the current scope.

Example of erroneous code:

  var x = 10;
  print(y);  // Error: y is not defined

To fix this error:

1. Declare the variable before using it:
   var y = 20;
   print(y);

2. Check for typos in the variable name:
   var value = 10;
   print(value);  // Not 'vlaue' or 'valu'

3. Ensure the variable is in scope:
   if (true) {
       var local = 5;
   }
   // local is not accessible here

The compiler will suggest similar variable names if it finds any close matches.
```

## Integration with Main Compiler

### Command-Line Argument Handling

Add to `main.zig` or CLI argument parser:

```zig
if (std.mem.eql(u8, arg, "--explain")) {
    const error_code = getNextArg();
    const explainer = errors.ErrorExplainer.init(allocator);
    try explainer.printExplanation(error_code);
    return;
}
```

### LSP Server Integration

For language server implementations:

```zig
// On hover over error code in diagnostic
fn handleHover(code: []const u8) !HoverResult {
    if (errors.ErrorExplainer.isValidErrorCode(code)) {
        const explainer = errors.ErrorExplainer.init(allocator);
        const explanation = try explainer.explain(code);
        return HoverResult{
            .contents = explanation,
            .range = code_range,
        };
    }
    return null;
}
```

## Testing

### Test Files Created

1. **`src/test_phase3_json.zig`** - Test JSON serialization
2. **`src/test_phase3_helpers.zig`** - Test compiler integration helpers
3. **`src/test_phase3_explain.zig`** - Test explanation system

### Build and Run Tests

```bash
# Build test executables
zig build-exe src/test_phase3_json.zig -femit-bin=zig-out/bin/test_json
zig build-exe src/test_phase3_helpers.zig -femit-bin=zig-out/bin/test_helpers
zig build-exe src/test_phase3_explain.zig -femit-bin=zig-out/bin/test_explain

# Run tests
./zig-out/bin/test_json
./zig-out/bin/test_helpers
./zig-out/bin/test_explain
```

### Manual Testing

**Test JSON Output:**
```bash
# Create a test file with error
echo 'var x = y;' > test.mufi
mufiz compile test.mufi --json-diagnostics
```

**Test Explanations:**
```bash
mufiz --explain E001
mufiz --explain E002
# ... etc
```

## Performance Considerations

### Memory Management

1. **JSON Serialization**
   - Uses temporary allocations for JSON strings
   - Caller must free returned JSON with `allocator.free()`
   - Consider using arena allocator for batch operations

2. **Error Explanations**
   - Explanations are compile-time strings (no allocation)
   - Safe to return directly without deallocation

3. **Compiler Helpers**
   - Delegate to `EnhancedTemplates` (Phase 2)
   - Follow Phase 2 memory patterns

### Recommendations

- **For LSP**: Use arena allocator per document update
- **For CLI**: Use page allocator (errors are terminal operations)
- **For Batch**: Reuse serializer instance across multiple errors

## Next Steps (Future Enhancements)

### Phase 4 Candidates

1. **Auto-Fix Application**
   - Command to apply machine-applicable suggestions
   - `mufiz fix --apply-suggestions file.mufi`

2. **Error Recovery Tracking**
   - Track parser recovery actions
   - Report "recovered by inserting `;`" in notes

3. **Configuration System**
   - `.mufizrc` for error preferences
   - Color scheme selection
   - Context line count
   - JSON vs human-readable output

4. **Multi-File Diagnostics**
   - Cross-file error spans
   - Import/module resolution errors

5. **IDE Plugin Template**
   - VSCode extension scaffold
   - Neovim LSP configuration
   - Emacs mode

6. **Internationalization**
   - Translate error messages
   - Locale-aware formatting

7. **Error Statistics**
   - Track most common errors
   - Suggest common fixes
   - Learning resources

## API Summary

### Public APIs Added in Phase 3

```zig
// JSON Serialization
pub const JsonDiagnosticSerializer = struct {
    pub fn init(allocator: Allocator) JsonDiagnosticSerializer;
    pub fn serializeError(self: *Self, error_info: EnhancedErrorInfo) ![]const u8;
    pub fn serializeErrors(self: *Self, errors: []const EnhancedErrorInfo) ![]const u8;
};

// Compiler Integration
pub const CompilerIntegration = struct {
    pub fn tokenToSpan(line: u32, column: u32, length: u32) ErrorSpan;
    pub fn reportUndefinedVariable(...) !void;
    pub fn reportTypeMismatch(...) !void;
    pub fn reportRedefinedVariable(...) !void;
    pub fn reportWrongArgumentCount(...) !void;
    pub fn reportTooManyLocals(...) !void;
    pub fn reportMethodNotFound(...) !void;
};

// Error Explanation
pub const ErrorExplainer = struct {
    pub fn init(allocator: Allocator) ErrorExplainer;
    pub fn explain(self: *Self, error_code: []const u8) ![]const u8;
    pub fn printExplanation(self: *Self, error_code: []const u8) !void;
    pub fn isValidErrorCode(error_code: []const u8) bool;
};
```

## Backward Compatibility

All Phase 3 additions are **non-breaking**:

- Existing `ErrorManager` methods unchanged
- Phase 1 & 2 APIs remain stable
- New features are additive only
- Legacy error reporting still works

## Documentation Files

Phase 3 documentation includes:

- ✅ **PHASE3_COMPLETE.md** (this file) - Phase 3 summary
- ✅ **ERROR_SYSTEM_README.md** - Overall system guide
- ✅ **ERROR_MIGRATION_GUIDE.md** - Migration instructions
- ✅ **ERROR_PATTERNS.md** - Common patterns
- ✅ **ERROR_EXAMPLES.md** - Comprehensive examples

## Success Criteria

Phase 3 is considered complete when:

- [x] JSON serialization produces valid LSP diagnostic format
- [x] All E001-E010 errors have detailed explanations
- [x] Compiler helpers simplify error reporting
- [x] Tests validate all new functionality
- [x] Documentation covers all new APIs
- [x] Backward compatibility maintained

## Conclusion

Phase 3 successfully delivers production-ready tooling for the enhanced error system:

- **LSP-Ready**: JSON output enables IDE integration
- **Developer-Friendly**: Compiler helpers reduce boilerplate
- **Educational**: Detailed explanations help users learn

The MufiZ error system now matches or exceeds Rust's diagnostic quality, providing:
- Multi-span errors with labels
- Smart suggestions with Levenshtein distance
- Machine-readable output for tooling
- Comprehensive documentation via `--explain`

**Next**: Integrate into main compiler (`compiler.zig`) and build LSP server.