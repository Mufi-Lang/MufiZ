# MufiZ Type System Reference

This document lists all type names available in MufiZ with examples of how to use them with type annotations.

## Primitive Types

### `int` - Integer
A 64-bit signed integer for whole numbers.

```mufi
var count: int = 42;
var negative: int = -100;
var zero: int = 0;
print count;           // Output: 42
```

**Operations:**
- Arithmetic: `+`, `-`, `*`, `/`, `%`, `^` (power)
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Bitwise: `&`, `|`, `^`, `<<`, `>>`

---

### `double` - Floating Point
A 64-bit IEEE 754 floating-point number for decimal values.

```mufi
var pi: double = 3.14159;
var price: double = 19.99;
var temperature: double = -273.15;
print pi;             // Output: 3.14159
```

**Operations:**
- Arithmetic: `+`, `-`, `*`, `/`, `%`, `^`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
- Special values: `inf`, `-inf`, `nan`

---

### `complex` - Complex Numbers
A complex number with real and imaginary parts (a + bi).

```mufi
// Complex literal: (real, imaginary)
var z: complex = (3, 4);      // 3 + 4i
var conj: complex = (5, -2);  // 5 - 2i
print z;                       // Output: (3 + 4i)
```

**Operations:**
- Arithmetic: `+`, `-`, `*`, `/`
- Comparison: `==`, `!=` (by both parts)
- Properties: `|z|` (magnitude), `conj(z)` (conjugate)

---

### `bool` - Boolean
A boolean value for true/false logic.

```mufi
var isActive: bool = true;
var isEmpty: bool = false;
var result: bool = 10 > 5;
print result;         // Output: true
```

**Operations:**
- Logical: `and`, `or`, `not`
- Comparison: `==`, `!=`

---

### `string` - Text
A sequence of characters (UTF-8).

```mufi
var greeting: string = "Hello";
var name: string = "World";
var combined: string = greeting + ", " + name;
print combined;       // Output: Hello, World
```

**Operations:**
- Concatenation: `+`
- Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=` (lexicographic)
- Length: `len(str)`
- Indexing: `str[0]` (first character)

---

### `nil` - Null/None
Represents the absence of a value (like `null` in other languages).

```mufi
var empty: nil = nil;
var maybeValue = nil;  // Type inferred as nil
print empty;           // Output: nil
```

---

## Collection Types

### `array` - Dynamic Array
An ordered collection of elements (size can change).

```mufi
var numbers: array = [1, 2, 3, 4, 5];
var mixed: array = [42, "hello", 3.14];  // Can mix types
var empty: array = [];

print len(numbers);    // Output: 5
```

**Operations:**
- Length: `len(arr)`
- Indexing: `arr[0]`, `arr[1]` (0-based)
- Append: `push(arr, value)`
- Remove: `pop(arr)`

---

### `vector` - Float Vector
A homogeneous array of floating-point numbers (optimized for math).

```mufi
var v1: vector = [1.0, 2.0, 3.0];
var v2: vector = [4.0, 5.0, 6.0];
var dot: double = v1 . v2;  // Dot product
print dot;            // Output: 32.0
```

**Operations:**
- Dot product: `v1 . v2`
- Cross product: `v1 × v2`
- Magnitude: `|v|`
- Normalize: `norm(v)`
- Element-wise: `+`, `-`, `*`, `/`

---

### `matrix` - 2D Matrix
A 2-dimensional array of numbers (optimized for linear algebra).

```mufi
var m: matrix = [[1, 2], [3, 4]];
var identity: matrix = [[1, 0], [0, 1]];

print m[0][1];        // Output: 2
```

**Operations:**
- Element access: `m[i][j]`
- Matrix multiplication: `m1 * m2`
- Transpose: `m^T` or `transpose(m)`
- Determinant: `det(m)`
- Inverse: `inv(m)`

---

### `table` - Hash Table
A key-value data structure (like dictionaries/maps).

```mufi
var person: table = {
  "name": "Alice",
  "age": 30,
  "active": true
};

print person["name"];  // Output: Alice
```

**Operations:**
- Access: `t["key"]`
- Set: `t["key"] = value`
- Keys: `keys(t)`
- Values: `values(t)`
- Contains: `has(t, "key")`

---

## Special Types

### `function` - Function Type
Represents a function/callable.

```mufi
var myFunc: function = fn(x: int) => x * 2;
var result: int = myFunc(5);
print result;         // Output: 10
```

---

### `any` - Any Type
A type for values whose type hasn't been inferred yet (dynamic typing).

```mufi
var mystery: any = 42;
mystery = "now a string";
mystery = true;
```

---

### `invalid` - Invalid Type
An internal error type (should not appear in normal code).

---

## Type Coercion & Promotion

MufiZ automatically promotes types in operations when safe:

```mufi
// int automatically promoted to double
var result1: double = 10 + 5.5;  // 15.5
var result2 = 10 + 5.5;          // Type inferred as double

// Division always returns double
var result3: double = 10 / 4;    // 2.5 (not 2)

// Comparison works across numeric types
var comp: bool = 10 > 5.5;       // true
```

**Type Hierarchy:**
```
int → double → complex
```

---

## Type Annotation Syntax

Basic syntax for declaring variables with type annotations:

```mufi
var name: TypeName = value;
var x: int = 10;
var y: double = 3.14;
var s: string = "hello";
```

**Optional (type inference when omitted):**
```mufi
var a = 10;          // Type inferred as int
var b = 3.14;        // Type inferred as double
var c = "hello";     // Type inferred as string
```

---

## Type Compatibility

### Implicit (Automatic) Conversions
- `int` → `double` (e.g., in arithmetic)
- `int` → `string` (in concatenation)
- Lower types in hierarchy → higher types

### Explicit (Manual) Conversions
```mufi
var x: int = 42;
var y: string = str(x);        // Convert int to string
var z: int = int("42");        // Convert string to int
var d: double = double(x);     // Convert int to double
```

---

## Examples: Multi-Type Program

```mufi
// Type annotations in action
var name: string = "MufiZ";
var version: double = 0.11;
var active: bool = true;
var count: int = 42;

// Type coercion
var mixed: double = count + version;  // 42.11 (int + double = double)

// String concatenation
var info: string = name + " v" + str(version);
print info;  // Output: MufiZ v0.11

// Boolean logic with comparison
var ready: bool = (count > 10) and active;
print ready; // Output: true
```

---

## Summary Table

| Type Name | Purpose | Example | Default |
|-----------|---------|---------|---------|
| `int` | Whole numbers | `42`, `-100` | N/A |
| `double` | Decimals & floats | `3.14`, `2.5` | N/A |
| `complex` | Complex numbers | `(3, 4)` | N/A |
| `bool` | True/false | `true`, `false` | N/A |
| `string` | Text | `"hello"` | `""` |
| `nil` | No value | `nil` | N/A |
| `array` | Dynamic list | `[1, 2, 3]` | `[]` |
| `vector` | Float array | `[1.0, 2.0]` | N/A |
| `matrix` | 2D array | `[[1, 2]]` | N/A |
| `table` | Key-value map | `{"x": 10}` | `{}` |
| `function` | Callable | `fn(x) => x+1` | N/A |
| `any` | Dynamic | (varies) | N/A |

---

## See Also
- [Type System Architecture](src/type_system.zig)
- [Type Annotations](src/type_annotations.zig)
- [Type Checker](src/type_checker.zig)
- [Type Inference](src/type_inference.zig)
