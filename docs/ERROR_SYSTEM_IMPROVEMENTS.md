# Error System Analysis and Improvement Proposal

## Executive Summary

This document analyzes MufiZ's current error reporting system and proposes improvements inspired by Rust's excellent error messages. The goal is to make error messages more helpful, actionable, and user-friendly while maintaining the existing architecture.

## Current State Analysis

### Strengths

1. **Well-Structured Error Information**
   - Clear separation of error categories (SYNTAX, SEMANTIC, RUNTIME, TYPE, MEMORY)
   - Severity levels (ERROR, WARNING, INFO, HINT)
   - Specific error codes for different scenarios
   - Location tracking (line, column, length)

2. **Suggestion System**
   - Multiple suggestions per error
   - Optional fix and example fields
   - Context-aware suggestions

3. **Visual Presentation**
   - Color-coded severity levels
   - Caret (^) pointer to error location
   - Category display

4. **Error Templates**
   - Pre-formatted common errors
   - Consistent messaging
   - Helper functions for formatting

5. **Similar Name Detection**
   - Basic fuzzy matching for undefined variables/methods
   - "Did you mean?" suggestions

### Current Limitations

1. **Single-Span Errors Only**
   - Can only highlight one location per error
   - Cannot show relationships between multiple locations
   - Missing "defined here" / "used here" connections

2. **Limited Context Display**
   - Only shows the single error line
   - No surrounding code context
   - Cannot show multi-line spans

3. **Basic Similarity Matching**
   - Uses simple prefix matching
   - No Levenshtein distance or edit distance
   - May miss close matches

4. **No Error Code Display**
   - Error codes exist but aren't shown to users
   - No standardized error documentation system
   - Can't easily search for specific errors

5. **Suggestions vs Help**
   - No distinction between informational notes and actionable help
   - All suggestions are treated equally
   - Hard to prioritize what to try first

6. **IDE Integration**
   - No machine-readable output format
   - Hard for tools to parse error information
   - LSP integration could be better

## Rust's Error Message Best Practices

### What Makes Rust Errors Great

1. **Multi-Span Highlighting**
   ```
   error[E0308]: mismatched types
     --> src/main.rs:4:18
      |
   3  |     let x: i32 = "hello";
      |            ---   ^^^^^^^ expected `i32`, found `&str`
      |            |
      |            expected due to this
   ```

2. **Labels on Spans**
   - Primary span: The main error location
   - Secondary spans: Related locations with labels
   - Clear visual hierarchy

3. **Notes and Help**
   - `note:` for informational context
   - `help:` for actionable suggestions
   - Clear distinction between them

4. **Error Codes**
   - Standardized codes (E0001, E0002, etc.)
   - `--explain` flag for detailed documentation
   - Easy to search and reference

5. **Context Lines**
   - Shows 2-3 lines before and after error
   - Line numbers for navigation
   - Code formatting preserved

6. **Diff-Style Suggestions**
   ```
   help: you can convert a `&str` to a `String`
      |
   3  |     let x: String = "hello".to_string();
      |                            +++++++++++++
   ```

## Proposed Improvements

### Phase 1: Core Enhancements (High Priority)

#### 1. Enhanced Error Structure

```zig
pub const ErrorSpan = struct {
    line_start: u32,
    column_start: u32,
    line_end: u32,
    column_end: u32,
    label: ?[]const u8 = null,
    is_primary: bool = true,
};

pub const ErrorNote = struct {
    message: []const u8,
    span: ?ErrorSpan = null,
};

pub const ErrorHelp = struct {
    message: []const u8,
    code_suggestion: ?CodeSuggestion = null,
};

pub const CodeSuggestion = struct {
    original: []const u8,
    replacement: []const u8,
    span: ErrorSpan,
    applicability: Applicability,
};

pub const Applicability = enum {
    MachineApplicable,  // Can be auto-applied
    MaybeIncorrect,     // Probably correct but verify
    HasPlaceholders,    // Contains placeholders
    Unspecified,        // Manual review needed
};

pub const ErrorInfo = struct {
    code: ErrorCode,
    category: ErrorCategory,
    severity: ErrorSeverity,
    message: []const u8,
    
    // Multi-span support
    primary_span: ErrorSpan,
    secondary_spans: []const ErrorSpan = &[_]ErrorSpan{},
    
    // Structured feedback
    notes: []const ErrorNote = &[_]ErrorNote{},
    help: []const ErrorHelp = &[_]ErrorHelp{},
    
    // Metadata
    error_number: ?u32 = null,  // E001, E002, etc.
    file_path: ?[]const u8 = null,
    
    // Source context
    source_code: ?[]const u8 = null,
};
```

#### 2. Error Code Display System

```zig
pub const ErrorCodeInfo = struct {
    number: u32,
    short_description: []const u8,
    long_description: []const u8,
    examples: []const []const u8,
};

pub const ErrorCodes = struct {
    // E001: Undefined variable
    pub const UNDEFINED_VARIABLE = ErrorCodeInfo{
        .number = 1,
        .short_description = "Undefined variable",
        .long_description = 
            \\This error occurs when you try to use a variable that hasn't been declared.
            \\Variables must be declared with 'var' or 'const' before use.
            \\
            \\Possible causes:
            \\  - Typo in variable name
            \\  - Variable declared in different scope
            \\  - Variable not yet declared
        ,
        .examples = &[_][]const u8{
            "var x = 42;\nprint(x);  // OK",
            "print(y);  // Error: undefined variable 'y'",
        },
    };
    
    // E002: Type mismatch
    pub const TYPE_MISMATCH = ErrorCodeInfo{
        .number = 2,
        .short_description = "Type mismatch",
        .long_description = 
            \\This error occurs when an expression has a different type than expected.
            \\MufiZ is dynamically typed but still checks types at runtime.
        ,
        .examples = &[_][]const u8{
            "var x: number = 42;  // OK",
            "var y: number = \"text\";  // Error: type mismatch",
        },
    };
    
    // ... more error codes
};
```

#### 3. Improved Levenshtein Distance for Similarity

```zig
pub fn levenshteinDistance(s1: []const u8, s2: []const u8, allocator: Allocator) !usize {
    const len1 = s1.len;
    const len2 = s2.len;
    
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;
    
    // Create matrix for dynamic programming
    var matrix = try allocator.alloc([]usize, len1 + 1);
    defer allocator.free(matrix);
    
    for (matrix, 0..) |*row, i| {
        row.* = try allocator.alloc(usize, len2 + 1);
        row.*[0] = i;
    }
    defer for (matrix) |row| allocator.free(row);
    
    for (0..len2 + 1) |j| {
        matrix[0][j] = j;
    }
    
    for (1..len1 + 1) |i| {
        for (1..len2 + 1) |j| {
            const cost: usize = if (s1[i - 1] == s2[j - 1]) 0 else 1;
            matrix[i][j] = @min(
                @min(matrix[i - 1][j] + 1, matrix[i][j - 1] + 1),
                matrix[i - 1][j - 1] + cost
            );
        }
    }
    
    return matrix[len1][len2];
}

pub fn findSimilarNames(
    name: []const u8,
    candidates: []const []const u8,
    allocator: Allocator,
    max_distance: usize
) ![]const []const u8 {
    var matches = std.ArrayList([]const u8).init(allocator);
    
    for (candidates) |candidate| {
        const distance = try levenshteinDistance(name, candidate, allocator);
        
        // Consider it similar if distance is small relative to name length
        const threshold = @max(max_distance, name.len / 3);
        if (distance <= threshold) {
            try matches.append(candidate);
        }
    }
    
    // Sort by distance (closest first)
    // ... sorting logic
    
    return matches.toOwnedSlice();
}
```

#### 4. Enhanced Error Printer with Context

```zig
pub fn printErrorEnhanced(self: *ErrorManager, info: ErrorInfo) void {
    // Print error header with code
    switch (info.severity) {
        .ERROR => print("\x1b[31;1merror", .{}),
        .WARNING => print("\x1b[33;1mwarning", .{}),
        .INFO => print("\x1b[36;1minfo", .{}),
        .HINT => print("\x1b[32;1mhint", .{}),
    }
    
    if (info.error_number) |num| {
        print("[E{d:0>3}]", .{num});
    }
    
    print("\x1b[0m: {s}\n", .{info.message});
    
    // Print file location
    if (info.file_path) |path| {
        print("  \x1b[36m-->\x1b[0m {s}:{d}:{d}\n", .{
            path,
            info.primary_span.line_start,
            info.primary_span.column_start,
        });
    }
    
    // Print source context with line numbers
    if (info.source_code) |source| {
        printSourceContext(source, info.primary_span, info.secondary_spans);
    }
    
    // Print notes
    if (info.notes.len > 0) {
        print("\n", .{});
        for (info.notes) |note| {
            print("  \x1b[36m=\x1b[0m \x1b[1mnote:\x1b[0m {s}\n", .{note.message});
            if (note.span) |span| {
                // Print span context if available
                printSpanContext(span);
            }
        }
    }
    
    // Print help
    if (info.help.len > 0) {
        print("\n", .{});
        for (info.help) |help_item| {
            print("  \x1b[36m=\x1b[0m \x1b[1mhelp:\x1b[0m {s}\n", .{help_item.message});
            if (help_item.code_suggestion) |suggestion| {
                printCodeSuggestion(suggestion);
            }
        }
    }
    
    print("\n", .{});
}

fn printSourceContext(
    source: []const u8,
    primary: ErrorSpan,
    secondary: []const ErrorSpan
) void {
    var lines = std.mem.split(u8, source, "\n");
    var line_num: u32 = 1;
    var context_start = if (primary.line_start > 2) primary.line_start - 2 else 1;
    var context_end = primary.line_end + 2;
    
    print("   \x1b[36m|\x1b[0m\n", .{});
    
    while (lines.next()) |line| : (line_num += 1) {
        if (line_num < context_start) continue;
        if (line_num > context_end) break;
        
        // Print line number
        if (line_num == primary.line_start) {
            print("\x1b[36m{d:>4} |\x1b[0m ", .{line_num});
        } else {
            print("{d:>4} | ", .{line_num});
        }
        
        print("{s}\n", .{line});
        
        // Print span indicators
        if (line_num >= primary.line_start and line_num <= primary.line_end) {
            printSpanUnderline(line, primary, true);
        }
        
        for (secondary) |span| {
            if (line_num >= span.line_start and line_num <= span.line_end) {
                printSpanUnderline(line, span, false);
            }
        }
    }
    
    print("   \x1b[36m|\x1b[0m\n", .{});
}

fn printSpanUnderline(line: []const u8, span: ErrorSpan, is_primary: bool) void {
    print("     | ", .{});
    
    // Print spaces before underline
    for (0..span.column_start - 1) |_| {
        print(" ", .{});
    }
    
    // Print underline
    if (is_primary) {
        print("\x1b[31m", .{});  // Red for primary
    } else {
        print("\x1b[33m", .{});  // Yellow for secondary
    }
    
    const length = if (span.line_start == span.line_end)
        span.column_end - span.column_start + 1
    else
        line.len - span.column_start + 1;
    
    for (0..length) |_| {
        print("^", .{});
    }
    
    print("\x1b[0m", .{});
    
    // Print label if available
    if (span.label) |label| {
        print(" {s}", .{label});
    }
    
    print("\n", .{});
}
```

#### 5. JSON Output for IDE Integration

```zig
pub fn printErrorAsJson(self: *ErrorManager, info: ErrorInfo) !void {
    var json_obj = std.json.ObjectMap.init(self.allocator);
    defer json_obj.deinit();
    
    try json_obj.put("severity", .{ .String = @tagName(info.severity) });
    try json_obj.put("code", .{ .String = @tagName(info.code) });
    try json_obj.put("message", .{ .String = info.message });
    
    if (info.error_number) |num| {
        try json_obj.put("error_number", .{ .Integer = @intCast(i64, num) });
    }
    
    if (info.file_path) |path| {
        try json_obj.put("file", .{ .String = path });
    }
    
    // Primary span
    var primary_span_obj = std.json.ObjectMap.init(self.allocator);
    try primary_span_obj.put("line_start", .{ .Integer = @intCast(i64, info.primary_span.line_start) });
    try primary_span_obj.put("column_start", .{ .Integer = @intCast(i64, info.primary_span.column_start) });
    try primary_span_obj.put("line_end", .{ .Integer = @intCast(i64, info.primary_span.line_end) });
    try primary_span_obj.put("column_end", .{ .Integer = @intCast(i64, info.primary_span.column_end) });
    if (info.primary_span.label) |label| {
        try primary_span_obj.put("label", .{ .String = label });
    }
    try json_obj.put("primary_span", .{ .Object = primary_span_obj });
    
    // Help and notes arrays
    var help_array = std.json.Array.init(self.allocator);
    for (info.help) |help_item| {
        try help_array.append(.{ .String = help_item.message });
    }
    try json_obj.put("help", .{ .Array = help_array });
    
    // Serialize to stdout
    try std.json.stringify(json_obj, .{}, std.io.getStdOut().writer());
    try std.io.getStdOut().writer().writeAll("\n");
}
```

### Phase 2: Template Improvements (Medium Priority)

#### 6. Enhanced Error Templates

```zig
pub const ErrorTemplates = struct {
    pub fn undefinedVariableEnhanced(
        name: []const u8,
        location: ErrorSpan,
        source: []const u8,
        available_vars: []const []const u8,
        allocator: Allocator
    ) !ErrorInfo {
        const similar = try findSimilarNames(name, available_vars, allocator, 2);
        
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
                    .span = location,
                    .applicability = .MaybeIncorrect,
                },
            });
        } else {
            try help_list.append(.{
                .message = "declare the variable before using it",
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
        
        return ErrorInfo{
            .code = .UNDEFINED_VARIABLE,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .message = try std.fmt.allocPrint(
                allocator,
                "cannot find value `{s}` in this scope",
                .{name}
            ),
            .error_number = 1,
            .primary_span = location,
            .source_code = source,
            .help = help_list.toOwnedSlice(),
            .notes = notes.toOwnedSlice(),
            .file_path = null,
        };
    }
    
    pub fn typeMismatchEnhanced(
        expected: []const u8,
        found: []const u8,
        expr_span: ErrorSpan,
        expected_span: ?ErrorSpan,  // Where the type requirement comes from
        source: []const u8,
        allocator: Allocator
    ) !ErrorInfo {
        var secondary_spans = std.ArrayList(ErrorSpan).init(allocator);
        
        if (expected_span) |exp_span| {
            try secondary_spans.append(.{
                .line_start = exp_span.line_start,
                .column_start = exp_span.column_start,
                .line_end = exp_span.line_end,
                .column_end = exp_span.column_end,
                .label = try std.fmt.allocPrint(allocator, "expected `{s}` because of this", .{expected}),
                .is_primary = false,
            });
        }
        
        var help_list = std.ArrayList(ErrorHelp).init(allocator);
        
        // Add type-specific conversion help
        if (std.mem.eql(u8, expected, "string") and std.mem.eql(u8, found, "number")) {
            try help_list.append(.{
                .message = "convert the number to a string using toString()",
            });
        } else if (std.mem.eql(u8, expected, "number") and std.mem.eql(u8, found, "string")) {
            try help_list.append(.{
                .message = "parse the string to a number using parseInt() or parseFloat()",
            });
        }
        
        return ErrorInfo{
            .code = .TYPE_MISMATCH,
            .category = .TYPE,
            .severity = .ERROR,
            .message = try std.fmt.allocPrint(
                allocator,
                "mismatched types: expected `{s}`, found `{s}`",
                .{expected, found}
            ),
            .error_number = 2,
            .primary_span = .{
                .line_start = expr_span.line_start,
                .column_start = expr_span.column_start,
                .line_end = expr_span.line_end,
                .column_end = expr_span.column_end,
                .label = try std.fmt.allocPrint(allocator, "expected `{s}`, found `{s}`", .{expected, found}),
                .is_primary = true,
            },
            .secondary_spans = secondary_spans.toOwnedSlice(),
            .source_code = source,
            .help = help_list.toOwnedSlice(),
            .file_path = null,
        };
    }
    
    pub fn redefinedVariableEnhanced(
        name: []const u8,
        current_location: ErrorSpan,
        previous_location: ErrorSpan,
        source: []const u8,
        allocator: Allocator
    ) !ErrorInfo {
        var secondary_spans = [_]ErrorSpan{
            .{
                .line_start = previous_location.line_start,
                .column_start = previous_location.column_start,
                .line_end = previous_location.line_end,
                .column_end = previous_location.column_end,
                .label = "previous definition here",
                .is_primary = false,
            },
        };
        
        return ErrorInfo{
            .code = .REDEFINED_VARIABLE,
            .category = .SEMANTIC,
            .severity = .ERROR,
            .message = try std.fmt.allocPrint(
                allocator,
                "the name `{s}` is defined multiple times",
                .{name}
            ),
            .error_number = 3,
            .primary_span = .{
                .line_start = current_location.line_start,
                .column_start = current_location.column_start,
                .line_end = current_location.line_end,
                .column_end = current_location.column_end,
                .label = try std.fmt.allocPrint(allocator, "`{s}` redefined here", .{name}),
                .is_primary = true,
            },
            .secondary_spans = &secondary_spans,
            .source_code = source,
            .notes = &[_]ErrorNote{
                .{ .message = "variables must have unique names within the same scope" },
            },
            .help = &[_]ErrorHelp{
                .{ .message = "choose a different name for this variable" },
                .{ .message = "or remove the previous definition if no longer needed" },
            },
            .file_path = null,
        };
    }
};
```

### Phase 3: Advanced Features (Lower Priority)

#### 7. Error Recovery Hints

When the parser enters panic mode, track what it tried to do:

```zig
pub const RecoveryAction = enum {
    InsertedSemicolon,
    InsertedClosingBrace,
    InsertedClosingParen,
    SkippedToken,
    AssumedExpression,
};

pub const RecoveryInfo = struct {
    action: RecoveryAction,
    location: ErrorSpan,
    description: []const u8,
};

// In parser
pub fn synchronize() void {
    parser.panicMode = false;
    
    while (parser.current.type != .TOKEN_EOF) {
        if (parser.previous.type == .TOKEN_SEMICOLON) return;
        
        switch (parser.current.type) {
            .TOKEN_CLASS, .TOKEN_FUN, .TOKEN_VAR, 
            .TOKEN_FOR, .TOKEN_IF, .TOKEN_WHILE,
            .TOKEN_PRINT, .TOKEN_RETURN => return,
            else => {},
        }
        
        // Track recovery action
        const recovery = RecoveryInfo{
            .action = .SkippedToken,
            .location = getCurrentSpan(),
            .description = "parser skipped this token while recovering from error",
        };
        try parser.recovery_actions.append(recovery);
        
        advance();
    }
}
```

#### 8. Chained Error Reporting

For errors that cascade from a root cause:

```zig
pub const ErrorChain = struct {
    primary: ErrorInfo,
    caused_by: ?*ErrorChain = null,
    
    pub fn print(self: *ErrorChain, manager: *ErrorManager) void {
        manager.printError(self.primary);
        
        if (self.caused_by) |cause| {
            print("\n\x1b[36m=\x1b[0m \x1b[1mcaused by:\x1b[0m\n\n", .{});
            cause.print(manager);
        }
    }
};
```

#### 9. Configuration Options

```zig
pub const ErrorFormatOptions = struct {
    color: bool = true,
    show_line_numbers: bool = true,
    context_lines: u32 = 2,
    max_suggestions: u32 = 5,
    format: OutputFormat = .Human,
    show_error_codes: bool = true,
};

pub const OutputFormat = enum {
    Human,      // Pretty colored output
    Json,       // Machine-readable JSON
    Short,      // Compact single-line format
    Verbose,    // Maximum detail
};
```

## Implementation Roadmap

### Week 1-2: Foundation
- [ ] Implement enhanced ErrorInfo structure with multi-span support
- [ ] Add error code numbering system
- [ ] Create ErrorCodeInfo database with documentation
- [ ] Implement Levenshtein distance algorithm

### Week 3-4: Display Improvements
- [ ] Enhance printError to show context lines
- [ ] Add multi-span underline support
- [ ] Implement colored labels for spans
- [ ] Add note vs help distinction

### Week 5-6: Template Migration
- [ ] Update all ErrorTemplates to use new structure
- [ ] Add "previous definition here" for redefinition errors
- [ ] Improve type mismatch errors with expected source tracking
- [ ] Enhance undefined variable with scope information

### Week 7-8: Advanced Features
- [ ] Implement JSON output format
- [ ] Add error recovery tracking
- [ ] Create error explanation system (--explain flag)
- [ ] Add configuration options

### Week 9-10: Integration & Testing
- [ ] Update compiler.zig to use enhanced errors
- [ ] Update analysis.zig for LSP integration
- [ ] Write comprehensive tests
- [ ] Update documentation

## Example Transformations

### Before (Current)

```
Error [test.mufi:5:10] (Semantic) Undefined variable 'coun'

  Suggestion: Declare the variable before using it
  Suggestion: Did you mean 'count'?
  Example: var coun = value;
```

### After (Proposed)

```
error[E001]: cannot find value `coun` in this scope
  --> test.mufi:5:10
   |
 3 | var count = 0;
   |     ----- help: did you mean `count`?
 4 | 
 5 | print(coun);
   |       ^^^^ not found in this scope
   |
   = note: available variables in scope: count, total, index
   = help: for more information about this error, try `mufiz --explain E001`
```

### Type Mismatch - Before

```
Error [test.mufi:8:15] (Type) Type mismatch in addition: expected number, got string

  Suggestion: Convert string to number
  Suggestion: Check that all operands are of compatible types
  Example: number + number, string + string
```

### Type Mismatch - After

```
error[E002]: mismatched types
  --> test.mufi:8:15
   |
 6 | var x: number = 42;
   |        ------ expected `number` because of this type
 7 | 
 8 | var result = x + "hello";
   |              -   ^^^^^^^ expected `number`, found `string`
   |              |
   |              this is `number`
   |
   = help: parse the string to a number using parseInt() or parseFloat()
   = help: or convert `x` to string: x.toString() + "hello"
```

### Redefinition - After (New)

```
error[E003]: the name `x` is defined multiple times
   --> test.mufi:12:5
    |
 8  | var x = 42;
    |     - previous definition here
    |
...
12  | var x = "hello";
    |     ^ `x` redefined here
    |
    = note: variables must have unique names within the same scope
    = help: choose a different name for this variable
    = help: or remove the previous definition if no longer needed
```

## Benefits

1. **Better Learning Experience**: Users understand not just what's wrong, but why and how to fix it
2. **Faster Development**: Clearer errors mean less time debugging
3. **IDE Integration**: JSON format enables better tooling support
4. **Consistency**: Standardized error codes and formats
5. **Documentation**: Error codes link to detailed explanations
6. **Professionalism**: Error quality matches modern language standards

## Compatibility Considerations

- Maintain backward compatibility with existing ErrorInfo structure initially
- Add deprecation warnings for old-style error creation
- Provide migration guide for existing code
- Keep simple error creation API for common cases

## Testing Strategy

1. **Unit Tests**: Test each component (similarity matching, span printing, etc.)
2. **Integration Tests**: Test full error reporting pipeline
3. **Visual Tests**: Compare output screenshots before/after
4. **Performance Tests**: Ensure error formatting doesn't slow compilation
5. **Accessibility Tests**: Test with screen readers, ensure colorblind-friendly

## Conclusion

By implementing these improvements, MufiZ will have an error system that rivals or exceeds Rust's excellent error messages. The key is providing actionable, contextual information that helps developers understand and fix problems quickly.

The phased approach allows incremental implementation while maintaining stability. Start with the high-priority core enhancements, then progressively add more sophisticated features.

---

**Next Steps:**
1. Review this proposal with the team
2. Prioritize which phases to implement first
3. Create detailed implementation issues
4. Begin Phase 1 implementation
5. Gather user feedback on improved errors
6. Iterate based on real-world usage