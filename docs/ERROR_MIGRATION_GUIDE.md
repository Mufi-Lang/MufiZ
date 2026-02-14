# Error System Migration Guide

This guide helps you migrate from the current error system to the enhanced error system with Rust-inspired error messages.

## Overview

The enhanced error system introduces:
- Multi-span error support
- Error codes (E001, E002, etc.)
- Enhanced visual formatting
- Structured notes and help messages
- Better similarity matching
- JSON output for tooling

## Migration Phases

### Phase 1: Compatibility Layer (Weeks 1-2)

The enhanced system will run alongside the current system with automatic conversion.

**No changes required** - existing code continues to work.

```zig
// Old API still works
const errorInfo = errors.ErrorInfo{
    .code = .UNDEFINED_VARIABLE,
    .category = .SEMANTIC,
    .severity = .ERROR,
    .line = 5,
    .column = 10,
    .length = 4,
    .message = "Undefined variable 'x'",
    .suggestions = &[_]errors.ErrorSuggestion{
        .{ .message = "Declare the variable first" },
    },
};
```

### Phase 2: New API Introduction (Weeks 3-4)

Enhanced API becomes available, old API gets deprecation warnings.

```zig
// New enhanced API
const errorInfo = errors_enhanced.EnhancedErrorInfo{
    .code = "E001",
    .category = "semantic",
    .severity = "error",
    .message = "cannot find value `x` in this scope",
    .error_number = 1,
    .primary_span = .{
        .line_start = 5,
        .column_start = 10,
        .line_end = 5,
        .column_end = 14,
        .label = "not found in this scope",
    },
    .source_code = source,
    .file_path = file_path,
    .help = &[_]errors_enhanced.ErrorHelp{
        .{ .message = "declare the variable before using it" },
    },
};
```

### Phase 3: Full Migration (Weeks 5-8)

All error creation moves to enhanced templates and new structures.

```zig
// Use enhanced templates
const errorInfo = try errors_enhanced.EnhancedTemplates.undefinedVariable(
    "x",
    5,      // line
    10,     // column
    1,      // length
    &[_][]const u8{"count", "total"},  // available vars
    source,
    file_path,
    allocator,
);
```

## Step-by-Step Migration

### Step 1: Update Error Creation

#### Before (Current)
```zig
var errorInfo = errors.ErrorInfo{
    .code = .UNDEFINED_VARIABLE,
    .category = .SEMANTIC,
    .severity = .ERROR,
    .line = line,
    .column = column,
    .length = length,
    .message = "Undefined variable",
    .suggestions = &[_]errors.ErrorSuggestion{
        .{ .message = "Declare it first" },
    },
    .context = null,
    .file_path = file_path,
};
```

#### After (Enhanced)
```zig
const errorInfo = try errors_enhanced.EnhancedTemplates.undefinedVariable(
    var_name,
    line,
    column,
    length,
    available_variables,
    source_code,
    file_path,
    allocator,
);
```

### Step 2: Update Error Codes

#### Before
```zig
.code = .UNDEFINED_VARIABLE,
```

#### After
```zig
.code = "E001",
.error_number = 1,
```

### Step 3: Update Spans

#### Before (Single Location)
```zig
.line = 5,
.column = 10,
.length = 4,
```

#### After (Span-based)
```zig
.primary_span = .{
    .line_start = 5,
    .column_start = 10,
    .line_end = 5,
    .column_end = 14,
    .label = "not found in this scope",
},
```

### Step 4: Add Secondary Spans (When Applicable)

For errors that need to show relationships:

```zig
// Allocate secondary spans
var secondary_spans = try allocator.alloc(errors_enhanced.ErrorSpan, 1);
secondary_spans[0] = .{
    .line_start = 3,
    .column_start = 5,
    .line_end = 3,
    .column_end = 6,
    .label = "previous definition here",
    .is_primary = false,
};

// Include in error
.secondary_spans = secondary_spans,
```

### Step 5: Separate Notes from Help

#### Before (Mixed)
```zig
.suggestions = &[_]errors.ErrorSuggestion{
    .{ .message = "Variables must be unique" },
    .{ .message = "Choose a different name" },
},
```

#### After (Separated)
```zig
.notes = &[_]errors_enhanced.ErrorNote{
    .{ .message = "variables must have unique names within scope" },
},
.help = &[_]errors_enhanced.ErrorHelp{
    .{ .message = "choose a different name for this variable" },
    .{ .message = "or remove the previous definition" },
},
```

### Step 6: Add Source Code Context

```zig
// Before: context was optional and not always used
.context = null,

// After: source code enables rich display
.source_code = source,
```

## Conversion Examples

### Example 1: Simple Error

#### Before
```zig
pub fn errorAtCurrent(message: [*]const u8) void {
    errorAt(&parser.current, message);
}

pub fn errorAt(token: *Token, message: [*]const u8) void {
    if (parser.panicMode) return;
    
    var errorInfo = errors.ErrorInfo{
        .code = .UNEXPECTED_TOKEN,
        .category = .SYNTAX,
        .severity = .ERROR,
        .line = @intCast(token.*.line),
        .column = calculateTokenColumn(token, scanner_h.getSourceStart()),
        .length = @intCast(token.*.length),
        .message = convertCString(message),
        .suggestions = &[_]errors.ErrorSuggestion{},
        .file_path = parser.currentFile,
    };
    
    globalErrorManager.reportError(errorInfo);
}
```

#### After
```zig
pub fn errorAtCurrent(message: []const u8) void {
    errorAt(&parser.current, message);
}

pub fn errorAt(token: *Token, message: []const u8) void {
    if (parser.panicMode) return;
    
    const errorInfo = errors_enhanced.EnhancedErrorInfo{
        .code = "E011",
        .category = "syntax",
        .severity = "error",
        .message = message,
        .error_number = 11,
        .primary_span = .{
            .line_start = token.*.line,
            .column_start = calculateTokenColumn(token),
            .line_end = token.*.line,
            .column_end = calculateTokenColumn(token) + token.*.length,
            .label = "unexpected token",
        },
        .source_code = parser.source,
        .file_path = parser.currentFile,
    };
    
    globalErrorManager.reportErrorEnhanced(errorInfo);
}
```

### Example 2: Error with Suggestions

#### Before
```zig
const suggestions = [_]errors.ErrorSuggestion{
    .{ .message = "Did you mean 'count'?" },
    .{ .message = "Declare the variable first" },
    .{ .example = "var coun = 0;" },
};

errorWithSuggestions(&parser.previous, .UNDEFINED_VARIABLE, "Undefined variable 'coun'", &suggestions);
```

#### After
```zig
const errorInfo = try errors_enhanced.EnhancedTemplates.undefinedVariable(
    "coun",
    parser.previous.line,
    calculateTokenColumn(&parser.previous),
    parser.previous.length,
    &[_][]const u8{"count", "total"},
    parser.source,
    parser.currentFile,
    parser.allocator,
);

globalErrorManager.reportErrorEnhanced(errorInfo);
```

### Example 3: Multi-Location Error

#### Before (Not Possible)
```zig
// Could only show one location
errorAt(&current_token, "Variable redefined");
```

#### After (Multi-Span)
```zig
const errorInfo = try errors_enhanced.EnhancedTemplates.redefinedVariable(
    "x",
    current_line,
    current_column,
    current_length,
    previous_line,
    previous_column,
    previous_length,
    parser.source,
    parser.currentFile,
    parser.allocator,
);

globalErrorManager.reportErrorEnhanced(errorInfo);
```

## Template Migration

### Creating New Error Templates

#### Old Template Style
```zig
pub fn undefinedVariable(name: []const u8, similar_names: []const []const u8) ErrorInfo {
    const message = fmt("Undefined variable '{s}'", .{name});
    
    var suggestions = std.ArrayList(ErrorSuggestion).init(allocator);
    suggestions.append(.{ .message = "Declare it first" }) catch {};
    
    return ErrorInfo{
        .code = .UNDEFINED_VARIABLE,
        .category = .SEMANTIC,
        .severity = .ERROR,
        .line = 0,
        .column = 0,
        .length = @intCast(name.len),
        .message = message,
        .suggestions = suggestions.toOwnedSlice() catch &[_]ErrorSuggestion{},
    };
}
```

#### New Template Style
```zig
pub fn undefinedVariable(
    name: []const u8,
    line: u32,
    column: u32,
    length: u32,
    available_vars: []const []const u8,
    source: []const u8,
    file_path: []const u8,
    allocator: Allocator,
) !EnhancedErrorInfo {
    const similar = try findSimilarNames(name, available_vars, allocator, 2);
    defer allocator.free(similar);
    
    var help_list = std.ArrayList(ErrorHelp).init(allocator);
    
    if (similar.len > 0) {
        const did_you_mean = try std.fmt.allocPrint(
            allocator,
            "did you mean `{s}`?",
            .{similar[0]}
        );
        try help_list.append(.{
            .message = did_you_mean,
            .code_suggestion = .{
                .original = name,
                .replacement = similar[0],
                .span = .{
                    .line_start = line,
                    .column_start = column,
                    .line_end = line,
                    .column_end = column + length,
                },
                .applicability = .MaybeIncorrect,
            },
        });
    }
    
    var notes = std.ArrayList(ErrorNote).init(allocator);
    if (available_vars.len > 0) {
        const vars_list = try std.mem.join(allocator, ", ", available_vars);
        const note_msg = try std.fmt.allocPrint(
            allocator,
            "available variables in scope: {s}",
            .{vars_list}
        );
        try notes.append(.{ .message = note_msg });
    }
    
    return EnhancedErrorInfo{
        .code = "E001",
        .category = "semantic",
        .severity = "error",
        .message = try std.fmt.allocPrint(
            allocator,
            "cannot find value `{s}` in this scope",
            .{name}
        ),
        .error_number = 1,
        .primary_span = .{
            .line_start = line,
            .column_start = column,
            .line_end = line,
            .column_end = column + length,
            .label = "not found in this scope",
        },
        .source_code = source,
        .file_path = file_path,
        .help = try help_list.toOwnedSlice(),
        .notes = try notes.toOwnedSlice(),
    };
}
```

## Common Pitfalls

### Pitfall 1: Forgetting Source Code
```zig
// ❌ Bad: No context
.source_code = null,

// ✅ Good: Include source
.source_code = parser.source,
```

### Pitfall 2: Not Using Labels
```zig
// ❌ Bad: No label
.label = null,

// ✅ Good: Descriptive label
.label = "expected boolean expression",
```

### Pitfall 3: Mixing Notes and Help
```zig
// ❌ Bad: Mixed
.help = &[_]ErrorHelp{
    .{ .message = "variables must be unique" },  // This is a note!
    .{ .message = "choose a different name" },
},

// ✅ Good: Separated
.notes = &[_]ErrorNote{
    .{ .message = "variables must be unique" },
},
.help = &[_]ErrorHelp{
    .{ .message = "choose a different name" },
},
```

### Pitfall 4: Not Using Templates
```zig
// ❌ Bad: Manual creation
const errorInfo = EnhancedErrorInfo{
    // ... lots of manual setup
};

// ✅ Good: Use templates
const errorInfo = try EnhancedTemplates.undefinedVariable(
    name, line, column, length, vars, source, path, allocator
);
```

## Testing Your Migration

### Unit Test Template
```zig
test "migrated undefined variable error" {
    const source = 
        \\var count = 0;
        \\print(coun);
    ;
    
    const error_info = try EnhancedTemplates.undefinedVariable(
        "coun",
        2, 7, 4,
        &[_][]const u8{"count"},
        source,
        "test.mufi",
        std.testing.allocator,
    );
    
    try std.testing.expectEqual(@as(u32, 1), error_info.error_number);
    try std.testing.expectEqualStrings("E001", error_info.code);
    try std.testing.expect(error_info.help.len > 0);
    try std.testing.expectEqual(@as(u32, 2), error_info.primary_span.line_start);
}
```

### Visual Testing
```bash
# Generate test errors with old system
mufiz test_errors.mufi > old_output.txt

# Migrate and generate with new system
mufiz test_errors.mufi > new_output.txt

# Compare (new should be more detailed)
diff old_output.txt new_output.txt
```

## Checklist

When migrating an error:

- [ ] Error code assigned (E001-E999)
- [ ] Template created in EnhancedTemplates
- [ ] Primary span with label
- [ ] Secondary spans if needed
- [ ] Notes separated from help
- [ ] Help messages actionable
- [ ] Source code included
- [ ] File path included
- [ ] Test case written
- [ ] Visual output verified
- [ ] Documentation updated

## Backwards Compatibility

During migration, both systems work:

```zig
// Old system (still works, shows deprecation warning)
const old_error = errors.ErrorInfo{ ... };
globalErrorManager.reportError(old_error);

// New system (preferred)
const new_error = errors_enhanced.EnhancedErrorInfo{ ... };
globalErrorManager.reportErrorEnhanced(new_error);
```

## Timeline

- **Week 1-2**: Compatibility layer, both systems run
- **Week 3-4**: New API available, deprecation warnings added
- **Week 5-6**: Critical errors migrated
- **Week 7-8**: All errors migrated
- **Week 9**: Old system removed
- **Week 10**: Cleanup and polish

## Help and Resources

- **Questions**: Check ERROR_PATTERNS.md
- **Examples**: See ERROR_EXAMPLES.md
- **API Reference**: See errors_enhanced.zig
- **Issues**: Create GitHub issue with "error-migration" label

## Support

If you encounter issues during migration:

1. Check this guide
2. Review ERROR_PATTERNS.md for patterns
3. Look at ERROR_EXAMPLES.md for inspiration
4. Examine existing migrated errors
5. Ask for help in team chat

---

**Remember**: The goal is better error messages for users. Take time to craft helpful, clear errors!