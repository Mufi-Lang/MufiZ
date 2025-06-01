# MufiZ Enhanced Error System

## Overview

The MufiZ language features a comprehensive error reporting system that provides detailed, helpful error messages with suggestions for fixing common programming mistakes. This system is designed to make debugging easier and help developers learn best practices.

## Error Categories

The error system categorizes errors into the following types:

### Syntax Errors
- **UNEXPECTED_TOKEN**: Wrong token found where another was expected
- **UNTERMINATED_STRING**: String literal missing closing quote
- **INVALID_CHARACTER**: Invalid or unexpected character in source code
- **MISSING_SEMICOLON**: Missing semicolon where required
- **MISMATCHED_BRACKETS**: Mismatched [], {}, or () brackets

### Semantic Errors
- **UNDEFINED_VARIABLE**: Reference to undeclared variable
- **REDEFINED_VARIABLE**: Variable declared multiple times in same scope
- **UNDEFINED_FUNCTION**: Call to undefined function
- **UNDEFINED_PROPERTY**: Access to undefined object property
- **WRONG_ARGUMENT_COUNT**: Function called with wrong number of arguments

### Type Errors
- **TYPE_MISMATCH**: Operation between incompatible types
- **INVALID_CAST**: Invalid type conversion
- **INCOMPATIBLE_TYPES**: Types cannot be used together

### Runtime Errors
- **STACK_OVERFLOW**: Too many nested function calls
- **INDEX_OUT_OF_BOUNDS**: Array/vector access outside valid range
- **NULL_REFERENCE**: Access to null object
- **DIVISION_BY_ZERO**: Division or modulo by zero

### Memory/Limit Errors
- **TOO_MANY_CONSTANTS**: More than 256 constants in one function
- **TOO_MANY_LOCALS**: More than 256 local variables in function
- **TOO_MANY_ARGUMENTS**: More than 255 function arguments
- **LOOP_TOO_LARGE**: Loop body exceeds maximum size (65535 bytes)
- **JUMP_TOO_LARGE**: Conditional jump distance too large

### Class/Object Errors
- **INVALID_SUPER_USAGE**: 'super' used outside class or without inheritance
- **INVALID_SELF_USAGE**: 'self' used outside class context
- **CLASS_INHERITANCE_ERROR**: Invalid class inheritance (e.g., self-inheritance)
- **METHOD_NOT_FOUND**: Called method doesn't exist on object

## Error Message Format

Each error message includes:

1. **Severity Level**: Error, Warning, Info, or Hint
2. **Location**: File, line, and column number
3. **Category**: The type of error (Syntax, Runtime, etc.)
4. **Message**: Clear description of what went wrong
5. **Context**: Relevant source code with error highlighting
6. **Suggestions**: Helpful advice on how to fix the error
7. **Examples**: Code examples showing correct usage (when applicable)

### Example Error Output

```
Error [script:15:23] (Syntax) Unexpected token 'var', expected ')'
    var result = add(5, var x = 10);
                       ^^^
  Suggestion: Replace 'var' with a valid expression
    Fix: Remove variable declaration from function call
    Example: var result = add(5, x);

  Suggestion: Declare variables outside function calls
    Example: var x = 10; var result = add(5, x);
```

## Common Error Scenarios and Suggestions

### Undefined Variables

**Error**: `Undefined variable 'userName'`

**Suggestions**:
- Declare the variable before using it
- Check spelling (did you mean 'username'?)
- Ensure variable is in correct scope

**Fix Examples**:
```javascript
// Before (error)
print(userName);

// After (fixed)
var userName = "John";
print(userName);
```

### Wrong Argument Count

**Error**: `Function 'add' expects 2 arguments, but 1 were provided`

**Suggestions**:
- Add the missing argument
- Check function signature
- Verify you're calling the correct function

**Fix Examples**:
```javascript
// Before (error)
var result = add(5);

// After (fixed)
var result = add(5, 3);
```

### Stack Overflow

**Error**: `Stack overflow - too many function calls`

**Suggestions**:
- Check for infinite recursion
- Add base case to recursive functions
- Consider using iteration instead
- Limit recursion depth

**Fix Examples**:
```javascript
// Before (infinite recursion)
fun factorial(n) {
    return n * factorial(n - 1);
}

// After (with base case)
fun factorial(n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}
```

### Index Out of Bounds

**Error**: `Index 5 is out of bounds for size 3`

**Suggestions**:
- Valid indices are 0 to 2
- Check array/vector size before accessing
- Use bounds checking

**Fix Examples**:
```javascript
// Before (unsafe)
var value = arr[index];

// After (safe)
if (index >= 0 && index < arr.length) {
    var value = arr[index];
} else {
    print("Index out of bounds");
}
```

### Invalid Super Usage

**Error**: `Cannot use 'super' outside of a class`

**Suggestions**:
- Use 'super' only inside class methods
- Ensure class has a parent class
- Move super call into class definition

**Fix Examples**:
```javascript
// Before (error)
super.method();

// After (fixed)
class Child extends Parent {
    method() {
        super.method();
    }
}
```

## Did You Mean Suggestions

The error system includes intelligent "did you mean" suggestions for:

- **Variable names**: Suggests similar variable names based on edit distance
- **Function names**: Suggests similar function names when available
- **Method names**: Suggests available methods on objects
- **Keywords**: Suggests correct keywords for typos

### Example
```
Error: Undefined variable 'usrName'
  Suggestion: Did you mean 'userName'?
```

## Error Recovery

The compiler includes panic mode recovery:

1. **Enter Panic Mode**: When an error is detected
2. **Skip Tokens**: Continue parsing by skipping problematic tokens
3. **Synchronization Points**: Recover at statement boundaries
4. **Exit Panic Mode**: Resume normal parsing

This allows the compiler to report multiple errors in a single compilation pass.

## Best Practices for Error Handling

### For Language Users

1. **Read the full error message**: Don't just look at the first line
2. **Check suggestions**: They often provide quick fixes
3. **Look at examples**: Understand the correct pattern
4. **Fix one error at a time**: Start with the first error reported

### For Language Developers

1. **Provide context**: Show relevant source code
2. **Be specific**: Explain exactly what went wrong
3. **Offer solutions**: Don't just report problems
4. **Use examples**: Show correct usage patterns
5. **Consider similar names**: Help with typos and misspellings

## Customizing Error Messages

The error system is extensible. New error types can be added by:

1. Adding to the `ErrorCode` enum
2. Creating templates in `ErrorTemplates`
3. Implementing appropriate suggestions
4. Adding category and severity information

### Example Custom Error

```zig
pub fn customError(context: []const u8) ErrorInfo {
    return ErrorInfo{
        .code = .CUSTOM_ERROR,
        .category = .SEMANTIC,
        .severity = .ERROR,
        .message = "Custom error message",
        .suggestions = &[_]ErrorSuggestion{
            .{ .message = "Try this fix" },
            .{ .example = "code example" },
        },
    };
}
```

## Performance Considerations

The error system is designed to:

- **Minimize overhead** during successful compilation
- **Provide rich information** only when errors occur
- **Use memory efficiently** with arena allocation
- **Support incremental** error reporting

## Future Enhancements

Planned improvements include:

- **Interactive fixes**: Suggest automatic code fixes
- **Error clustering**: Group related errors together
- **IDE integration**: Rich error information for editors
- **Localization**: Multi-language error messages
- **Error codes**: Stable identifiers for programmatic handling