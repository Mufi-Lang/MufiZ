# Error System Improvement Summary

## Overview

This document provides a quick reference for the proposed improvements to MufiZ's error reporting system, inspired by Rust's excellent error messages.

## Current Strengths

✅ Well-structured error categories and codes  
✅ Suggestion system with examples  
✅ Color-coded output  
✅ Basic similarity matching  
✅ Error templates for common cases  

## Key Limitations to Address

❌ Single-span errors only (can't show relationships)  
❌ Limited context (only shows error line)  
❌ Basic fuzzy matching (prefix only)  
❌ Error codes exist but aren't displayed  
❌ No distinction between notes and actionable help  
❌ No machine-readable output for IDEs  

## Proposed Enhancements

### 1. Multi-Span Errors

**Before:**
```
Error [test.mufi:12:5] (Semantic) Variable 'x' is already defined
```

**After:**
```
error[E003]: the name `x` is defined multiple times
   --> test.mufi:12:5
    |
 8  | var x = 42;
    |     - previous definition here
    |
12  | var x = "hello";
    |     ^ `x` redefined here
```

**Benefit:** Shows relationships between multiple code locations

---

### 2. Context Lines with Line Numbers

**Before:** Shows only the error line  
**After:** Shows 2-3 lines before and after with line numbers

**Benefit:** Better understanding of surrounding code context

---

### 3. Improved Levenshtein Distance

**Before:** Simple prefix matching  
**After:** Edit distance algorithm for accurate similarity

```zig
levenshteinDistance("claculate", "calculate", allocator) // → 2
```

**Benefit:** Better "did you mean" suggestions

---

### 4. Error Code Display System

**Format:** `error[E001]`, `error[E002]`, etc.

**Features:**
- Standardized numbering (E001-E999)
- `--explain E001` flag for detailed documentation
- Easy to search and reference

**Benefit:** Developers can look up detailed explanations

---

### 5. Notes vs Help Distinction

**Notes:** Informational context  
**Help:** Actionable suggestions

```
= note: variables must have unique names within the same scope
= help: choose a different name for this variable
= help: or remove the previous definition if no longer needed
```

**Benefit:** Clear prioritization of what to do

---

### 6. Labeled Spans

```
8 | var result = x + "hello";
  |              -   ^^^^^^^ expected `number`, found `string`
  |              |
  |              this is `number`
```

**Benefit:** Inline explanations at relevant locations

---

### 7. Inline Diff Suggestions

```
= help: change `factorial(n)` to `factorial(n - 1)`
  |
5 |     return n * factorial(n - 1);
  |                             +++
```

**Benefit:** Visual indication of exact changes needed

---

### 8. JSON Output for IDEs

```json
{
  "severity": "error",
  "code": "E001",
  "message": "cannot find value `x` in this scope",
  "file": "test.mufi",
  "primary_span": {
    "line_start": 4,
    "column_start": 7,
    "line_end": 4,
    "column_end": 8
  },
  "help": ["did you mean `count`?"]
}
```

**Benefit:** Better LSP integration and tool support

---

## New Data Structures

### ErrorSpan
```zig
pub const ErrorSpan = struct {
    line_start: u32,
    column_start: u32,
    line_end: u32,
    column_end: u32,
    label: ?[]const u8 = null,
    is_primary: bool = true,
};
```

### ErrorNote
```zig
pub const ErrorNote = struct {
    message: []const u8,
    span: ?ErrorSpan = null,
};
```

### ErrorHelp
```zig
pub const ErrorHelp = struct {
    message: []const u8,
    code_suggestion: ?CodeSuggestion = null,
};
```

### CodeSuggestion
```zig
pub const CodeSuggestion = struct {
    original: []const u8,
    replacement: []const u8,
    span: ErrorSpan,
    applicability: Applicability,
};
```

### Applicability
```zig
pub const Applicability = enum {
    MachineApplicable,  // Can be auto-applied
    MaybeIncorrect,     // Probably correct but verify
    HasPlaceholders,    // Contains placeholders
    Unspecified,        // Manual review needed
};
```

---

## Implementation Phases

### Phase 1: Core Enhancements (Weeks 1-4)
- [ ] Enhanced ErrorInfo with multi-span support
- [ ] Error code numbering system
- [ ] Levenshtein distance algorithm
- [ ] Enhanced printer with context lines
- [ ] Multi-span underlines

### Phase 2: Template Improvements (Weeks 5-6)
- [ ] Update all ErrorTemplates
- [ ] Add "previous definition here" tracking
- [ ] Type mismatch with source tracking
- [ ] Enhanced undefined variable errors

### Phase 3: Advanced Features (Weeks 7-10)
- [ ] JSON output format
- [ ] Error recovery tracking
- [ ] `--explain` flag system
- [ ] Configuration options
- [ ] Comprehensive testing

---

## Error Code Reference (Planned)

| Code | Name | Example |
|------|------|---------|
| E001 | Undefined Variable | `cannot find value 'x' in this scope` |
| E002 | Type Mismatch | `expected 'number', found 'string'` |
| E003 | Redefined Variable | `the name 'x' is defined multiple times` |
| E004 | Wrong Argument Count | `function takes 2 arguments but 3 were supplied` |
| E005 | Unterminated String | `unterminated string literal` |
| E006 | Stack Overflow | `stack overflow - infinite recursion` |
| E007 | Invalid Super Usage | `invalid use of 'super' keyword` |
| E008 | Too Many Locals | `function has too many local variables` |
| E009 | Method Not Found | `no method named 'x' found for class 'Y'` |
| E010 | Index Out of Bounds | `index 5 is out of bounds for size 3` |

More codes will be added as needed.

---

## Benefits Summary

### For Developers
- ✅ Faster debugging (understand errors immediately)
- ✅ Better learning experience (errors explain concepts)
- ✅ Less frustration (actionable suggestions)
- ✅ Professional experience (matches modern standards)

### For Tooling
- ✅ Better IDE integration (JSON format)
- ✅ Automated fixes (machine-applicable suggestions)
- ✅ Error analytics (categorize by code)
- ✅ Documentation generation (from error codes)

### For the Language
- ✅ Professional appearance
- ✅ Competitive with Rust, TypeScript, etc.
- ✅ Lower barrier to entry
- ✅ Better reputation and adoption

---

## Example Comparison

### Before (Current System)
```
Error [test.mufi:4:7] (Semantic) Undefined variable 'coun'

  Suggestion: Declare the variable before using it
  Suggestion: Did you mean 'count'?
  Example: var coun = value;
```

### After (Enhanced System)
```
error[E001]: cannot find value `coun` in this scope
  --> test.mufi:4:7
   |
 1 | var count = 0;
 2 | var total = 100;
 3 | 
 4 | print(coun);
   |       ^^^^ not found in this scope
   |
   = note: available variables in scope: count, total
   = help: did you mean `count`?

for more information about this error, try `mufiz --explain E001`
```

**Key Improvements:**
- Shows surrounding code context
- Clear visual hierarchy
- Distinguishes notes from help
- Error code for documentation
- Better formatting and professionalism

---

## Files to Review

1. **ERROR_SYSTEM_IMPROVEMENTS.md** - Full detailed proposal (870 lines)
2. **ERROR_EXAMPLES.md** - 10 concrete before/after examples
3. **errors_enhanced.zig** - Reference implementation (599 lines)

---

## Getting Started

1. Read the full proposal in `ERROR_SYSTEM_IMPROVEMENTS.md`
2. Review examples in `ERROR_EXAMPLES.md`
3. Examine reference code in `errors_enhanced.zig`
4. Prioritize which features to implement first
5. Create implementation issues and assign work
6. Start with Phase 1 (core enhancements)

---

## Configuration Options (Planned)

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

---

## Backward Compatibility

- Maintain existing ErrorInfo structure initially
- Add deprecation warnings for old-style errors
- Provide migration guide
- Keep simple API for common cases
- Gradual migration path

---

## Testing Strategy

- **Unit Tests:** Individual components (similarity, spans, etc.)
- **Integration Tests:** Full error pipeline
- **Visual Tests:** Screenshot comparisons
- **Performance Tests:** Ensure no slowdown
- **Accessibility Tests:** Colorblind-friendly, screen readers

---

## Conclusion

These improvements will bring MufiZ's error system to world-class standards, matching or exceeding Rust's excellent error messages. The phased approach ensures stability while progressively adding sophisticated features.

**Next Action:** Review proposal with team and prioritize implementation phases.