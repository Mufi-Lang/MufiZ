# Error System Documentation

Welcome to the MufiZ Error System documentation. This directory contains comprehensive information about our current error reporting system and proposed improvements inspired by Rust's excellent error messages.

## 📚 Documentation Files

### 1. [ERROR_SYSTEM_SUMMARY.md](ERROR_SYSTEM_SUMMARY.md)
**Start here!** Quick overview of current state, limitations, and proposed improvements.

- Current strengths and weaknesses
- Key enhancements overview
- Implementation phases
- Benefits summary
- ~366 lines

### 2. [ERROR_SYSTEM_IMPROVEMENTS.md](ERROR_SYSTEM_IMPROVEMENTS.md)
**Comprehensive technical proposal** with detailed specifications.

- Full analysis of current system
- Rust error message best practices
- Detailed improvement proposals
- Enhanced data structures
- Implementation roadmap
- Phase-by-phase breakdown
- ~870 lines

### 3. [ERROR_EXAMPLES.md](ERROR_EXAMPLES.md)
**Visual before/after comparisons** of 10 common error scenarios.

- Undefined variable
- Type mismatch
- Redefined variable
- Wrong argument count
- Unterminated string
- Stack overflow
- Invalid super usage
- Too many locals
- Method not found
- Index out of bounds
- ~467 lines

### 4. [ERROR_PATTERNS.md](ERROR_PATTERNS.md)
**Pattern library** for implementing different error types.

- 12 common error patterns
- Code templates
- Color scheme reference
- Best practices
- Implementation checklist
- Quick reference card
- ~519 lines

## 🚀 Quick Start

### For Reviewing the Proposal
1. Read [ERROR_SYSTEM_SUMMARY.md](ERROR_SYSTEM_SUMMARY.md) for overview
2. Review concrete examples in [ERROR_EXAMPLES.md](ERROR_EXAMPLES.md)
3. Study full proposal in [ERROR_SYSTEM_IMPROVEMENTS.md](ERROR_SYSTEM_IMPROVEMENTS.md)

### For Implementation
1. Study patterns in [ERROR_PATTERNS.md](ERROR_PATTERNS.md)
2. Review reference code in `../src/errors_enhanced.zig`
3. Follow implementation phases in the proposal
4. Use templates for creating new errors

## 📂 Related Files

### Implementation Files
- `../src/errors.zig` - Current error system (210 lines)
- `../src/errors_enhanced.zig` - Reference implementation (599 lines)
- `../src/compiler.zig` - Error usage examples
- `../src/analysis.zig` - LSP integration

## 🎯 Key Improvements

### Visual Enhancements
✓ Multi-line context with line numbers  
✓ Colored underlines (red primary, yellow secondary)  
✓ Labels on spans explaining what's wrong  
✓ Clean gutter with `|` characters  
✓ Professional formatting  

### Structural Improvements
✓ Error codes (E001, E002, etc.)  
✓ Multi-span errors showing relationships  
✓ Separation of notes vs help  
✓ "defined here" / "used here" connections  
✓ Inline diff suggestions  

### Content Improvements
✓ Levenshtein distance for similarity  
✓ Type-specific suggestions  
✓ Contextual help based on error type  
✓ Example code showing fixes  
✓ Language rule explanations  

### Integration Features
✓ JSON output for IDE tooling  
✓ LSP-friendly structure  
✓ Machine-applicable suggestions  
✓ `--explain` flag for detailed docs  

## 📊 Comparison Example

### Before (Current)
```
Error [test.mufi:4:7] (Semantic) Undefined variable 'coun'

  Suggestion: Declare the variable before using it
  Suggestion: Did you mean 'count'?
  Example: var coun = value;
```

### After (Proposed)
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

## 🗓️ Implementation Roadmap

### Phase 1: Core Enhancements (Weeks 1-4)
- Enhanced ErrorInfo with multi-span support
- Error code numbering system
- Levenshtein distance algorithm
- Enhanced printer with context lines
- Multi-span underline support

### Phase 2: Template Improvements (Weeks 5-6)
- Update all ErrorTemplates to new structure
- Add "previous definition here" tracking
- Improve type mismatch with source tracking
- Enhanced undefined variable with scope info

### Phase 3: Advanced Features (Weeks 7-10)
- JSON output format for IDEs
- Error recovery tracking
- `--explain` flag system
- Configuration options
- Comprehensive testing

## 💡 Design Principles

### Clarity
- Errors should be immediately understandable
- Use visual hierarchy to guide the eye
- Show relevant context, not too much or too little

### Actionability
- Every error should suggest how to fix it
- Distinguish between notes (info) and help (action)
- Provide concrete examples when helpful

### Consistency
- All errors follow the same format
- Standardized color scheme
- Predictable structure

### Education
- Errors are teaching moments
- Explain language rules when relevant
- Help users learn, not just fix

### Tooling
- Machine-readable formats available
- Support IDE integration
- Enable automated fixes where safe

## 🧪 Testing Strategy

### Unit Tests
- Individual components (similarity matching, span printing)
- Data structure validation
- Edge cases and error conditions

### Integration Tests
- Full error reporting pipeline
- Multiple error scenarios
- Context extraction from source

### Visual Tests
- Screenshot comparisons
- Color rendering verification
- Layout consistency

### Performance Tests
- Error formatting overhead
- Memory usage tracking
- Large file handling

### Accessibility Tests
- Colorblind-friendly schemes
- Screen reader compatibility
- High contrast mode support

## 🔧 Configuration

Planned configuration options:

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
    Short,      // Compact single-line
    Verbose,    // Maximum detail
};
```

## 📖 Error Code Registry

| Code | Name | Category | Docs |
|------|------|----------|------|
| E001 | Undefined Variable | Semantic | [explain](explain/E001.md) |
| E002 | Type Mismatch | Type | [explain](explain/E002.md) |
| E003 | Redefined Variable | Semantic | [explain](explain/E003.md) |
| E004 | Wrong Argument Count | Semantic | [explain](explain/E004.md) |
| E005 | Unterminated String | Syntax | [explain](explain/E005.md) |
| E006 | Stack Overflow | Runtime | [explain](explain/E006.md) |
| E007 | Invalid Super Usage | Semantic | [explain](explain/E007.md) |
| E008 | Too Many Locals | Semantic | [explain](explain/E008.md) |
| E009 | Method Not Found | Semantic | [explain](explain/E009.md) |
| E010 | Index Out of Bounds | Runtime | [explain](explain/E010.md) |

*Note: Detailed explanation pages to be created during implementation*

## 🎨 Color Reference

### Severity Colors (ANSI)
- Error: `\x1b[31;1m` (bright red)
- Warning: `\x1b[33;1m` (bright yellow)
- Info: `\x1b[36;1m` (bright cyan)
- Hint: `\x1b[32;1m` (bright green)

### Span Colors
- Primary: `\x1b[31;1m` (bright red underline)
- Secondary: `\x1b[33;1m` (bright yellow underline)
- Success: `\x1b[32m` (green for suggestions)

### Elements
- Gutter: `\x1b[36m` (cyan `|`)
- Arrow: `\x1b[36m` (cyan `-->`)
- Bold: `\x1b[1m`
- Dim: `\x1b[2m`
- Reset: `\x1b[0m`

## 🤝 Contributing

When adding new error types:

1. Assign next available error code
2. Choose appropriate category
3. Follow error patterns from [ERROR_PATTERNS.md](ERROR_PATTERNS.md)
4. Write clear, actionable messages
5. Add test cases
6. Update error code registry
7. Create explanation page (for `--explain`)

## 📝 Style Guidelines

### Error Messages
- Start lowercase (unless proper noun)
- Be specific, not generic
- Use backticks for code: `variable`
- Keep under 80 characters
- Use "expected X, found Y" for type errors

### Help Messages
- Start with verb: add, remove, change, use
- Be concrete with exact syntax
- Most likely solution first
- Provide alternatives when appropriate

### Notes
- Explain language rules
- Provide background context
- Keep brief and informative
- Reference documentation when helpful

## 🌟 Inspiration

This error system is inspired by:

- **Rust** - Multi-span errors, excellent explanations
- **Elm** - Friendly, helpful tone
- **TypeScript** - IDE integration
- **Swift** - Clear visual hierarchy
- **Clang** - Fix-it hints

Our goal: Make MufiZ's errors as helpful as Rust's while maintaining our own style.

## 📞 Questions?

For questions about:
- **Current implementation**: See `../src/errors.zig`
- **Proposed changes**: Review proposal documents
- **Patterns**: Check [ERROR_PATTERNS.md](ERROR_PATTERNS.md)
- **Examples**: See [ERROR_EXAMPLES.md](ERROR_EXAMPLES.md)

## 🚦 Status

**Current Phase**: Proposal and Review  
**Next Step**: Team review and prioritization  
**Target**: Phase 1 implementation in next sprint  

---

**Last Updated**: 2024
**Maintainer**: MufiZ Team
**Version**: 1.0 (Proposal)

---

> "A good error message turns a frustrating debugging session into a learning opportunity."

**Let's make MufiZ's errors world-class! 🚀**