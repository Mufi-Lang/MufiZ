# Error Pattern Quick Reference Guide

This guide provides visual patterns for implementing different types of errors in the enhanced system.

---

## Pattern 1: Single Location Error

**Use When:** Error occurs at one specific location (syntax errors, undefined variables)

```
error[E001]: cannot find value `x` in this scope
  --> file.mufi:5:10
   |
 3 | var count = 0;
 4 | 
 5 | print(x);
   |       ^ not found in this scope
   |
   = help: did you mean `count`?
```

**Structure:**
- Header: `error[CODE]: message`
- Location: `--> file:line:column`
- Context: 2 lines before/after
- Underline: Single span with label
- Help: Actionable suggestions

---

## Pattern 2: Two-Location Relationship

**Use When:** Need to show "defined here, used here" relationships

```
error[E003]: the name `x` is defined multiple times
   --> file.mufi:12:5
    |
 8  | var x = 42;
    |     - previous definition here
    |
... |
12  | var x = "hello";
    |     ^ `x` redefined here
    |
    = note: variables must have unique names
    = help: choose a different name
```

**Structure:**
- Primary span: Current/problematic location (red)
- Secondary span: Previous/related location (yellow)
- Ellipsis (...) for skipped lines
- Labels on both spans
- Note explaining the rule
- Help with solution

---

## Pattern 3: Type Mismatch with Source

**Use When:** Types don't match and you can show where expectation comes from

```
error[E002]: mismatched types
  --> file.mufi:8:15
   |
 6 | var x: number = 42;
   |        ------ expected `number` because of this
 7 | 
 8 | var result = x + "hello";
   |              -   ^^^^^^^ expected `number`, found `string`
   |              |
   |              this is `number`
   |
   = help: convert the number to string: x.toString()
```

**Structure:**
- Type annotation shown as secondary span
- Expression shown as primary span
- Multi-line underline with connecting lines
- Type-specific conversion help

---

## Pattern 4: Inline Diff Suggestion

**Use When:** You can show exact code change needed

```
error[E011]: missing semicolon
  --> file.mufi:5:20
   |
 5 | var x = 42
   |           ^ expected `;`
   |
   = help: add a semicolon at the end
     |
   5 | var x = 42;
     |           +
```

**Structure:**
- Show error location
- Show corrected version
- Use `+` to indicate additions
- Use `-` to indicate removals

---

## Pattern 5: Method/Function Signature Mismatch

**Use When:** Wrong arguments, method not found, etc.

```
error[E004]: this function takes 2 arguments but 3 were supplied
   --> file.mufi:15:10
    |
 3  | fun calculate(width, height) {
    |               ---------------- defined here
    |
... |
15  |     var area = calculate(10, 20, 5);
    |                ^^^^^^^^^^^^^^^^^---^
    |                                 |
    |                                 unexpected argument
    |
    = note: expected 2 arguments: width, height
    = help: remove the extra argument
```

**Structure:**
- Show function definition
- Show call site
- Highlight problematic argument
- List expected parameters

---

## Pattern 6: Runtime Error with Context

**Use When:** Runtime errors that benefit from showing initialization

```
error[E010]: index out of bounds
   --> file.mufi:12:15
    |
 8  | var numbers = {10, 20, 30};
    |     ------- vector has 3 elements (indices 0-2)
    |
... |
12  | print(numbers[5]);
    |       ----------^
    |               |
    |               index 5 is too large
    |
    = note: valid indices are 0, 1, or 2
    = help: check bounds: if (i < numbers.length()) { ... }
```

**Structure:**
- Show where data structure was created
- Show where out-of-bounds access occurs
- Explain valid range
- Provide defensive programming example

---

## Pattern 7: Cascading Errors

**Use When:** One error causes another

```
error[E012]: cannot call method on undefined value
   --> file.mufi:10:5
    |
10  | result.toString();
    | ^^^^^^ `result` is not defined
    |
    = note: caused by previous error E001
    = help: define `result` before using it
```

**Structure:**
- Show immediate error
- Reference causing error
- Suggest fixing root cause first

---

## Pattern 8: Multiple Suggestions

**Use When:** Several valid approaches to fix the issue

```
error[E013]: incompatible types in conditional
   --> file.mufi:7:8
    |
 7  | if (count) {
    |     ^^^^^ expected boolean, found number
    |
    = help: compare with zero: if (count > 0) { ... }
    = help: or check for non-zero: if (count != 0) { ... }
    = help: or convert to boolean: if (!!count) { ... }
```

**Structure:**
- Single error location
- Multiple help suggestions
- Each help is a complete alternative
- Order by most idiomatic first

---

## Pattern 9: Long Identifier Truncation

**Use When:** Error involves very long names

```
error[E014]: undefined variable
   --> file.mufi:25:10
    |
25  | print(veryLongVariableNameThatIsHardToRead);
    |       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ not found
    |
    = help: did you mean `veryLongVariableNameThatIsEasyToRead`?
    = note: variable names should be concise but descriptive
```

**Structure:**
- Don't truncate in error message
- Show full identifiers
- Suggest better naming if relevant

---

## Pattern 10: Scope Information

**Use When:** Variable visibility/scope issues

```
error[E015]: cannot find value `x` in this scope
   --> file.mufi:15:10
    |
10  | fun outer() {
11  |     var x = 42;
    |         - `x` defined in function scope
12  |     fun inner() {
13  |         // `x` is not visible here
... |
15  |         print(x);
    |               ^ not found in this scope
16  |     }
    |
    = note: `x` is only visible within the `outer` function
    = help: pass `x` as a parameter to `inner`
    = help: or make `x` accessible to `inner` functions
```

**Structure:**
- Show where variable is defined
- Show where it's accessed
- Explain scope boundary
- Suggest parameter passing or restructuring

---

## Pattern 11: Multi-Line Span

**Use When:** Error spans multiple lines (unclosed blocks, etc.)

```
error[E016]: unterminated block
   --> file.mufi:5:10
    |
 5  |   if (condition) {
    |  ______________^
 6  | |     doSomething();
 7  | |     doSomethingElse();
 8  | |     // missing closing brace
    | |________________________________^ expected `}` here
    |
    = help: add closing brace at the end of the block
```

**Structure:**
- Use box drawing characters for multi-line
- Show start and end of span
- Indicate what's missing

---

## Pattern 12: Warning (Non-Error)

**Use When:** Code works but not recommended

```
warning[W001]: unused variable
  --> file.mufi:8:9
   |
 8 | var unusedVar = calculate();
   |     ^^^^^^^^^ variable is never read
   |
   = note: this variable is assigned but never used
   = help: remove the variable if not needed
   = help: or prefix with underscore if intentionally unused: `_unusedVar`
```

**Structure:**
- Use `warning` instead of `error`
- Yellow/orange color scheme
- Less severe tone
- Still provide actionable help

---

## Color Scheme Reference

### Severity Colors (ANSI codes)
- **Error:** `\x1b[31;1m` (bright red)
- **Warning:** `\x1b[33;1m` (bright yellow)
- **Info:** `\x1b[36;1m` (bright cyan)
- **Hint:** `\x1b[32;1m` (bright green)

### Span Colors
- **Primary span:** `\x1b[31;1m` (bright red)
- **Secondary span:** `\x1b[33;1m` (bright yellow)
- **Success/suggestion:** `\x1b[32m` (green)

### Element Colors
- **Gutter (`|`):** `\x1b[36m` (cyan)
- **Arrow (`-->`):** `\x1b[36m` (cyan)
- **Bold text:** `\x1b[1m`
- **Dim text:** `\x1b[2m`
- **Reset:** `\x1b[0m`

---

## Implementation Checklist

When implementing a new error, ensure:

- [ ] Error code assigned (E001, E002, etc.)
- [ ] Category determined (syntax, semantic, type, runtime)
- [ ] Primary span with label
- [ ] Secondary spans if relationships exist
- [ ] Context lines (2 before, 2 after)
- [ ] At least one help message
- [ ] Notes for additional context
- [ ] Examples in help messages when useful
- [ ] Test case created
- [ ] Documentation added to error code registry

---

## Code Templates

### Basic Error Creation

```zig
const error_info = EnhancedErrorInfo{
    .code = "E001",
    .category = "semantic",
    .severity = "error",
    .message = try std.fmt.allocPrint(allocator, "cannot find value `{s}`", .{name}),
    .error_number = 1,
    .primary_span = .{
        .line_start = line,
        .column_start = column,
        .line_end = line,
        .column_end = column + length,
        .label = "not found in this scope",
        .is_primary = true,
    },
    .source_code = source,
    .file_path = file_path,
    .help = &[_]ErrorHelp{
        .{ .message = "declare the variable before using it" },
    },
};
```

### Two-Location Error

```zig
var secondary_spans = try allocator.alloc(ErrorSpan, 1);
secondary_spans[0] = .{
    .line_start = prev_line,
    .column_start = prev_column,
    .line_end = prev_line,
    .column_end = prev_column + prev_length,
    .label = "previous definition here",
    .is_primary = false,
};

const error_info = EnhancedErrorInfo{
    .code = "E003",
    // ... other fields ...
    .secondary_spans = secondary_spans,
};
```

### With Code Suggestion

```zig
const help_with_fix = ErrorHelp{
    .message = try std.fmt.allocPrint(allocator, "did you mean `{s}`?", .{correct_name}),
    .code_suggestion = .{
        .original = wrong_name,
        .replacement = correct_name,
        .span = error_span,
        .applicability = .MaybeIncorrect,
    },
};
```

---

## Best Practices

### DO ✓
- Use specific, actionable language
- Show code context (2-3 lines)
- Provide concrete examples
- Use labels to explain spans
- Separate notes from help
- Include error codes
- Test with real examples

### DON'T ✗
- Use vague terms like "syntax error"
- Show too much context (>5 lines)
- Provide generic suggestions
- Mix informational and actionable content
- Forget to handle edge cases
- Use inconsistent formatting
- Assume user knowledge level

---

## Error Message Writing Guidelines

### Message Format
- Start with lowercase (unless proper noun)
- Be specific, not generic
- Use backticks for code: \`variable\`
- Use "expected X, found Y" pattern for type errors
- Keep under 80 characters if possible

### Help Messages
- Start with verb: "add", "remove", "change", "use"
- Be concrete: show exact syntax
- Prioritize most likely solution first
- Provide alternatives when appropriate

### Notes
- Explain language rules or concepts
- Provide background information
- Reference related documentation
- Keep brief and informative

---

## Testing Your Errors

```zig
test "undefined variable error" {
    const source = 
        \\var count = 0;
        \\print(coun);
    ;
    
    const error_info = try ErrorTemplates.undefinedVariable(
        "coun",
        2, 7, 4,
        &[_][]const u8{"count"},
        source,
        "test.mufi",
        std.testing.allocator,
    );
    
    // Verify error structure
    try std.testing.expectEqual(@as(u32, 1), error_info.error_number);
    try std.testing.expectEqualStrings("E001", error_info.code);
    try std.testing.expect(error_info.help.len > 0);
}
```

---

## Resources

- **Full Proposal:** `ERROR_SYSTEM_IMPROVEMENTS.md`
- **Examples:** `ERROR_EXAMPLES.md`
- **Implementation:** `errors_enhanced.zig`
- **Summary:** `ERROR_SYSTEM_SUMMARY.md`

---

## Quick Reference Card

| Error Type | Code Range | Pattern | Priority |
|------------|------------|---------|----------|
| Syntax | E001-E099 | Single location | High |
| Semantic | E100-E199 | Two locations | High |
| Type | E200-E299 | Type relationship | High |
| Runtime | E300-E399 | With initialization | Medium |
| Memory | E400-E499 | Resource tracking | Medium |
| Limits | E500-E599 | With explanation | Low |
| Class/OOP | E600-E699 | Inheritance chain | Medium |
| Control Flow | E700-E799 | Context dependent | Low |
| IO/Network | E800-E899 | External resources | Low |
| System | E900-E999 | Platform specific | Low |

---

**Remember:** Great error messages turn frustration into learning opportunities. Make every error a teaching moment!