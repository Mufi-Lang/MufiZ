# Error Message Examples: Before and After Comparison

This document shows concrete examples of how error messages will improve with the enhanced error system.

## Example 1: Undefined Variable

### Current Output (Before)

```
Error [test.mufi:4:7] (Semantic) Undefined variable 'coun'

  Suggestion: Declare the variable before using it
  Suggestion: Did you mean 'count'?
  Example: var coun = value;
```

### Enhanced Output (After)

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

**Improvements:**
- Shows surrounding context (lines 1-2)
- Clear visual underline with label
- Distinguishes notes (informational) from help (actionable)
- Includes error code for documentation lookup
- Better formatting and hierarchy

---

## Example 2: Type Mismatch

### Current Output (Before)

```
Error [calculator.mufi:8:15] (Type) Type mismatch in addition: expected number, got string

  Suggestion: Convert string to number
  Suggestion: Check that all operands are of compatible types
  Example: number + number, string + string
```

### Enhanced Output (After)

```
error[E002]: mismatched types
  --> calculator.mufi:8:15
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

**Improvements:**
- Multi-span error showing both the type annotation and the mismatch
- Labels on both spans explaining the issue
- Type-specific conversion suggestions
- Shows where the type expectation originates

---

## Example 3: Redefined Variable

### Current Output (Before)

```
Error [data.mufi:12:5] (Semantic) Variable 'x' is already defined

  Suggestion: Choose a different variable name
  Suggestion: Remove the duplicate definition
```

### Enhanced Output (After)

```
error[E003]: the name `x` is defined multiple times
   --> data.mufi:12:5
    |
 8  | var x = 42;
    |     - previous definition here
    |
... |
12  | var x = "hello";
    |     ^ `x` redefined here
    |
    = note: variables must have unique names within the same scope
    = help: choose a different name for this variable
    = help: or remove the previous definition if no longer needed
```

**Improvements:**
- Shows both definitions with clear labels
- Visual connection between locations
- Uses ellipsis (...) to show skipped lines
- Explains the scope rule being violated

---

## Example 4: Wrong Argument Count

### Current Output (Before)

```
Error [utils.mufi:15:10] (Semantic) Function 'calculateArea' expects 2 arguments, but 3 were provided

  Suggestion: Remove 1 argument
  Suggestion: Check the function signature for the correct number of parameters
```

### Enhanced Output (After)

```
error[E004]: this function takes 2 arguments but 3 arguments were supplied
   --> utils.mufi:15:10
    |
 3  | fun calculateArea(width, height) {
    |                   ---------------- defined here
    |
... |
15  |     var area = calculateArea(10, 20, 5);
    |                ^^^^^^^^^^^^^^^^^^^-----^
    |                                   |
    |                                   unexpected argument
    |
    = note: expected 2 arguments: width, height
    = help: remove the extra argument
```

**Improvements:**
- Shows function definition location
- Highlights the extra argument specifically
- Lists expected parameter names
- Multi-span error linking definition to call site

---

## Example 5: Unterminated String

### Current Output (Before)

```
Error [poem.mufi:3:15] (Syntax) Unterminated string

  Suggestion: Add closing quote
  Suggestion: Check for escaped quotes
```

### Enhanced Output (After)

```
error[E005]: unterminated string literal
  --> poem.mufi:3:15
   |
 1 | var title = "My Poem";
 2 | 
 3 | var text = "This is
   |            ^^^^^^^^ missing closing quote
 4 |     a multiline poem
 5 |     without proper syntax;
   |
   = help: add a closing quote at the end: "This is a poem"
   = help: for multi-line strings, use proper escaping or string concatenation
   = note: string literals must be on a single line unless escaped
```

**Improvements:**
- Shows multiple lines to illustrate the problem
- Suggests both quick fix and proper solution
- Explains the language rule
- More context about what's wrong

---

## Example 6: Stack Overflow (Runtime)

### Current Output (Before)

```
Error [recursion.mufi:5:12] (Runtime) Stack overflow - too many function calls

  Suggestion: Check for infinite recursion
  Suggestion: Add a base case to recursive functions
  Suggestion: Consider using iteration instead of recursion
  Example: if (depth > MAX_DEPTH) return;
```

### Enhanced Output (After)

```
error[E006]: stack overflow
  --> recursion.mufi:5:12
   |
 3 | fun factorial(n) {
 4 |     if (n <= 0) return 1;
 5 |     return n * factorial(n);  // Bug: should be n-1
   |                ^^^^^^^^^^^^^
   |                |
   |                recursive call without proper base case
   |
   = note: this function calls itself without reducing the problem size
   = help: ensure recursive calls work toward the base case
   = help: change `factorial(n)` to `factorial(n - 1)`
     |
   5 |     return n * factorial(n - 1);
     |                             +++

for more information about recursion, try `mufiz --explain E006`
```

**Improvements:**
- Shows the buggy code in context
- Inline diff suggestion (the +++ showing what to add)
- Explains the root cause (not reducing problem size)
- Provides concrete fix with code change

---

## Example 7: Invalid Super Usage

### Current Output (Before)

```
Error [widget.mufi:10:9] (Semantic) Cannot use 'super' outside of a class or in a class with no superclass

  Suggestion: Use 'super' only inside methods of a derived class
  Suggestion: Ensure the class inherits from another class
  Example: super.methodName(args)
```

### Enhanced Output (After)

```
error[E007]: invalid use of `super` keyword
   --> widget.mufi:10:9
    |
 6  | class Widget {
    | ------------ `super` cannot be used in classes without inheritance
 7  |     fun init() {
 8  |         print("Creating widget");
 9  |     }
10  |     fun setup() {
11  |         super.init();
    |         ^^^^^ `super` used here, but `Widget` has no parent class
12  |     }
    |
    = help: remove the `super` call if not needed
    = help: or make `Widget` inherit from a parent class: class Widget < ParentClass {
    = note: `super` can only be used in classes that extend another class
```

**Improvements:**
- Shows class declaration to explain context
- Multi-line context showing the problematic method
- Explains why `super` can't be used here
- Provides both removal and inheritance solutions

---

## Example 8: Too Many Locals

### Current Output (Before)

```
Error [processor.mufi:45:5] (Semantic) Too many local variables in function (maximum 256)

  Suggestion: Reduce the number of local variables
  Suggestion: Consider breaking the function into smaller functions
  Suggestion: Use data structures to group related variables
```

### Enhanced Output (After)

```
error[E008]: function has too many local variables
   --> processor.mufi:45:5
    |
 3  | fun processData(input) {
    |     ----------- function defined here
    |
... |
43  |     var result255 = calculate(data255);
44  |     var result256 = calculate(data256);
45  |     var result257 = calculate(data257);  // 257th variable
    |         ^^^^^^^^^ exceeds maximum of 256 local variables
    |
    = note: MufiZ currently supports a maximum of 256 local variables per function
    = help: extract some of this logic into helper functions
    = help: use arrays or objects to group related data
    = help: example refactoring:
      |
      | fun processData(input) {
      |     var results = processChunk1(input);
      |     var moreResults = processChunk2(input);
      |     return combine(results, moreResults);
      | }
```

**Improvements:**
- Shows which variable exceeds the limit
- Provides example refactoring pattern
- Explains the limit clearly
- Suggests practical alternatives

---

## Example 9: Method Not Found

### Current Output (Before)

```
Error [shape.mufi:18:10] (Semantic) Undefined method 'claculate' on class 'Circle'

  Suggestion: Check the method name spelling
```

### Enhanced Output (After)

```
error[E009]: no method named `claculate` found for class `Circle`
   --> shape.mufi:18:10
    |
 5  | class Circle {
    | ------------ method should be defined here
 6  |     fun calculate(radius) { ... }
    |         --------- similarly named method found here
    |
... |
18  |     var area = circle.claculate(5);
    |                       ^^^^^^^^^ help: a method with a similar name exists: `calculate`
    |
    = note: available methods: calculate, draw, getRadius, setRadius
    = help: did you mean `calculate`?
```

**Improvements:**
- Shows where similar method is defined
- Lists all available methods
- Clearer "did you mean" with specific suggestion
- Shows class structure for context

---

## Example 10: Index Out of Bounds

### Current Output (Before)

```
Error [array_test.mufi:12:15] (Runtime) Index 5 is out of bounds for size 3

  Suggestion: Valid indices are 0 to 2
  Suggestion: Check array/vector size before accessing elements
  Example: if (index >= 0 && index < size) { ... }
```

### Enhanced Output (After)

```
error[E010]: index out of bounds
   --> array_test.mufi:12:15
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
    = note: vector `numbers` has length 3, so valid indices are 0, 1, or 2
    = help: check the index is within bounds before accessing:
      |
      | if (index < numbers.length()) {
      |     print(numbers[index]);
      | }
```

**Improvements:**
- Shows where array was created and its size
- Visual indication of the problematic index
- Provides defensive programming example
- Clear explanation of valid range

---

## Summary of Improvements

### Visual Enhancements
- ✓ Multi-line context showing surrounding code
- ✓ Colored underlines (red for primary, yellow for secondary)
- ✓ Line numbers for easy navigation
- ✓ Gutter with `|` character for clean alignment
- ✓ Labels on spans explaining what's wrong

### Structural Improvements
- ✓ Error codes (E001, E002, etc.) for documentation
- ✓ Separation of notes (informational) vs help (actionable)
- ✓ Multi-span errors showing relationships
- ✓ "defined here" / "used here" connections
- ✓ Inline diff suggestions with +/- markers

### Content Improvements
- ✓ Better similar name detection (Levenshtein distance)
- ✓ Type-specific suggestions (e.g., string ↔ number conversion)
- ✓ Contextual help based on error type
- ✓ Example code showing the fix
- ✓ Explanation of language rules

### User Experience
- ✓ Easier to scan and understand
- ✓ Actionable suggestions prioritized
- ✓ Less overwhelming (better formatting)
- ✓ Links to detailed explanations
- ✓ Professional appearance matching modern compilers

---

## Error Code Reference

| Code | Name | Category | Description |
|------|------|----------|-------------|
| E001 | Undefined Variable | Semantic | Variable used before declaration |
| E002 | Type Mismatch | Type | Expression type doesn't match expected type |
| E003 | Redefined Variable | Semantic | Variable name used multiple times in scope |
| E004 | Wrong Argument Count | Semantic | Function called with incorrect number of arguments |
| E005 | Unterminated String | Syntax | String literal missing closing quote |
| E006 | Stack Overflow | Runtime | Too many recursive function calls |
| E007 | Invalid Super Usage | Semantic | `super` used outside inheritance context |
| E008 | Too Many Locals | Semantic | Function exceeds 256 local variable limit |
| E009 | Method Not Found | Semantic | Method doesn't exist on class |
| E010 | Index Out of Bounds | Runtime | Array/vector index exceeds bounds |

More error codes will be added as the system evolves.

---

## Implementation Notes

The enhanced error system provides:

1. **Better Developer Experience**: Errors are easier to understand and fix
2. **IDE Integration**: Machine-readable JSON format for tooling
3. **Consistency**: All errors follow the same high-quality format
4. **Scalability**: Easy to add new error types with rich information
5. **Documentation**: Error codes link to detailed explanations

This brings MufiZ's error messages up to the standard set by modern languages like Rust, helping developers be more productive and learn the language more effectively.