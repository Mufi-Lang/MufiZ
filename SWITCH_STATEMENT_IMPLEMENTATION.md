# Switch Statement Implementation for MufiZ

This document describes the implementation of modern switch statements in the MufiZ programming language, as specified in [Issue #52](https://github.com/Mufi-Lang/MufiZ/issues/52).

## Overview

The switch statement implementation provides a modern, safe alternative to traditional switch statements found in other languages. Key features include:

- **No fall-through behavior** - Each case executes independently
- **Arrow syntax** - Uses `=>` for cleaner, more readable code
- **Expression support** - Can be used both as statements and expressions
- **Type flexibility** - Works with numbers, strings, booleans, and complex expressions
- **Default case support** - Uses `_` wildcard for default handling

## Syntax

### Basic Statement Form
```mufi
switch (expression) {
  value1 => { /* code block */ },
  value2 => { /* code block */ },
  _ => { /* default case */ }
}
```

### Expression Form (Future Enhancement)
```mufi
var result = switch (expression) {
  value1 => "result1",
  value2 => "result2", 
  _ => "default"
};
```

## Implementation Details

### Scanner Changes

#### New Token Types
- `TOKEN_SWITCH` (ID: 47) - Recognizes the `switch` keyword
- `TOKEN_ARROW` (ID: 64) - Recognizes the `=>` arrow operator

#### Scanner Updates
- Added `switch` keyword to the keyword map in `initKeywordMap()`
- Updated `scanToken()` to recognize `=>` as a two-character token
- Modified the `=` case to check for `>` following `=`

### Compiler Changes

#### New OpCodes
- `OP_SWITCH` (ID: 48) - Marks the beginning of a switch block
- `OP_SWITCH_CASE` (ID: 49) - Handles individual case comparisons
- `OP_SWITCH_END` (ID: 50) - Marks the end of a switch block

#### Parser Integration
- Updated `statement()` function to recognize `TOKEN_SWITCH`
- Added `switchStatement()` function for parsing switch syntax
- Updated `getRule()` to handle new token types with appropriate precedence

#### Switch Statement Parsing Logic
The `switchStatement()` function implements the following algorithm:

1. **Parse switch expression**: `switch (expression)`
2. **Process each case**:
   - Check for default case (`_`)
   - Parse case value expression
   - Generate comparison bytecode using `OP_DUP` and `OP_EQUAL`
   - Handle conditional jumps with `OP_JUMP_IF_FALSE`
   - Parse case body (block or expression)
   - Generate end-of-case jumps
3. **Handle default case**: Execute if no other cases match
4. **Patch all jumps**: Ensure proper control flow

### Virtual Machine Changes

#### OpCode Handling
The VM handles the new opcodes as follows:
- `OP_SWITCH`: No additional work needed (marker for debugging)
- `OP_SWITCH_CASE`: Comparison already handled by existing opcodes
- `OP_SWITCH_END`: End marker for debugging purposes

#### Stack Management
The implementation uses the existing stack-based approach:
- Switch expression value remains on stack for comparisons
- `OP_DUP` duplicates the switch value before each comparison
- Comparison results are properly popped after use

### Debug Support

Updated `debug.zig` to display the new opcodes:
- `OP_SWITCH` → "OP_SWITCH"
- `OP_SWITCH_CASE` → "OP_SWITCH_CASE" 
- `OP_SWITCH_END` → "OP_SWITCH_END"

## Usage Examples

### Basic Numeric Switch
```mufi
var choice = 2;
switch (choice) {
  1 => { print "One"; },
  2 => { print "Two"; },
  3 => { print "Three"; },
  _ => { print "Other"; }
}
```

### String Switch
```mufi
var command = "start";
switch (command) {
  "start" => { print "Starting..."; },
  "stop" => { print "Stopping..."; },
  _ => { print "Unknown command"; }
}
```

### Boolean Switch
```mufi
var isActive = true;
switch (isActive) {
  true => { print "Active"; },
  false => { print "Inactive"; },
  _ => { print "Unknown"; }
}
```

### Complex Expressions
```mufi
var x = 10;
var y = 5;
switch (x + y) {
  10 => { print "Sum is 10"; },
  15 => { print "Sum is 15"; },
  x * y => { print "Sum equals product"; },
  _ => { print "Other sum"; }
}
```

## Features Implemented

✅ **Core Functionality**
- Switch statement parsing and compilation
- Arrow syntax (`=>`) support
- Block-based case bodies
- Default case with `_` wildcard
- Proper control flow and jump patching

✅ **Safety Features**
- No fall-through behavior by default
- Proper stack management
- Error handling for multiple default cases

✅ **Type Support**
- Numeric literals and variables
- String literals and variables  
- Boolean values
- Complex expressions as case values

✅ **Integration**
- Scanner token recognition
- Compiler statement parsing
- VM bytecode execution
- Debug output support

## Current Limitations

❌ **Expression Form**: Switch expressions that return values for assignment are not yet implemented
❌ **Range Syntax**: Range patterns like `1..5 =>` are not implemented
❌ **Multiple Values**: Multiple values per case like `1 | 2 | 3 =>` are not supported
❌ **Pattern Matching**: Advanced pattern matching features are not available

## Testing

Comprehensive tests are available in:
- `examples/final_switch_demo.mufi` - Complete feature demonstration
- `examples/comprehensive_switch.mufi` - Multiple test cases
- `examples/block_switch.mufi` - Basic functionality test

### Test Results
All implemented features pass testing with proper:
- Case matching and execution
- Default case handling
- Control flow management
- Multiple data type support
- Complex expression evaluation

## File Changes Made

### Modified Files
- `src/scanner.zig` - Added new tokens and keyword recognition
- `src/compiler.zig` - Added switch statement parsing and compilation
- `src/chunk.zig` - Added new opcodes
- `src/vm.zig` - Added opcode handling
- `src/debug.zig` - Added debug output for new opcodes

### New Files
- `examples/final_switch_demo.mufi` - Comprehensive test suite
- `examples/comprehensive_switch.mufi` - Multiple scenario tests
- `examples/block_switch.mufi` - Basic functionality test

## Future Enhancements

1. **Switch Expressions**: Implement the ability to use switch as an expression that returns a value
2. **Range Support**: Add range syntax for case values (`1..5 =>`)
3. **Multiple Values**: Support multiple values per case (`1 | 2 | 3 =>`)
4. **Pattern Matching**: Advanced pattern matching capabilities
5. **Guard Clauses**: Conditional case matching with `when` clauses

## Conclusion

The switch statement implementation successfully provides a modern, safe alternative to traditional switch statements. The implementation follows the design principles outlined in Issue #52, providing clean syntax, safe semantics, and comprehensive functionality for the MufiZ programming language.

The feature is ready for use and provides significant value to MufiZ developers seeking expressive, safe control flow constructs.