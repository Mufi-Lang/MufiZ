# MufiZ Mathematical Operations Guide

This comprehensive guide covers all mathematical capabilities in MufiZ, from basic arithmetic to advanced linear algebra.

## Table of Contents

1. [Numeric Types](#numeric-types)
2. [Basic Arithmetic Operations](#basic-arithmetic-operations)
3. [Math Functions](#math-functions)
4. [Bitwise Operations](#bitwise-operations)
5. [Vector Operations](#vector-operations)
6. [Matrix Operations](#matrix-operations)
7. [Statistical Functions](#statistical-functions)
8. [Complex Numbers](#complex-numbers)
9. [Examples and Patterns](#examples-and-patterns)

---

## Numeric Types

MufiZ supports several numeric types for mathematical computation:

### Basic Types
- **Integer** (`int`): Whole numbers, used for counting and discrete operations
- **Float** (`double`): Floating-point numbers with decimal precision
- **Complex**: Complex numbers with real and imaginary parts

### Collections
- **Vector** (float vector): 1D array of floating-point numbers
- **Matrix** (2D array): 2D grid of numbers
- **List**: Ordered collection of any values

### Type Conversion
```mufi
let x = 5          // integer
let y = 5.0        // double (float)
let z = int(3.14)  // converts to integer: 3
let f = float(5)   // converts to double: 5.0
```

---

## Basic Arithmetic Operations

### Standard Operators

```mufi
// Addition, subtraction, multiplication, division
let a = 10 + 5        // 15
let b = 10 - 5        // 5
let c = 10 * 5        // 50
let d = 10 / 5        // 2
let e = 10 % 3        // 1 (modulo)

// Exponentiation
let f = 2 ^ 10        // 1024 (2 to the power of 10)

// Negation
let g = -5            // -5
```

### Operator Precedence
Operations follow standard mathematical precedence:
1. Exponentiation (`^`) - highest
2. Unary (`-`, `bnot`) 
3. Multiplication (`*`, `/`, `%`)
4. Addition (`+`, `-`)
5. Bitwise shifts (`shl`, `shr`)
6. Bitwise AND (`band`)
7. Bitwise XOR (`bxor`)
8. Bitwise OR (`bor`)
9. Comparison (`<`, `>`, `<=`, `>=`, `==`, `!=`) - lowest

### Type Promotion
When mixing types, MufiZ automatically promotes to the wider type:
```mufi
let x = 5 + 3.14      // Result is 8.14 (double)
let y = 2 * 3         // Result is 6 (integer)
```

---

## Math Functions

### Trigonometric Functions

```mufi
// Basic trigonometric functions (angle in radians)
sin(x)          // Sine
cos(x)          // Cosine
tan(x)          // Tangent

// Inverse trigonometric functions
asin(x)         // Arcsine (returns [-π/2, π/2])
acos(x)         // Arccosine (returns [0, π])
atan(x)         // Arctangent (returns [-π/2, π/2])
atan2(y, x)     // Two-argument arctangent (handles quadrants)

// Hyperbolic functions
sinh(x)         // Hyperbolic sine
cosh(x)         // Hyperbolic cosine
tanh(x)         // Hyperbolic tangent
asinh(x)        // Inverse hyperbolic sine
acosh(x)        // Inverse hyperbolic cosine
atanh(x)        // Inverse hyperbolic tangent
```

**Example:**
```mufi
import math

// Find angle in a right triangle
let opposite = 3.0
let adjacent = 4.0
let angle = atan2(opposite, adjacent)    // ~0.6435 radians
let angle_deg = rad2deg(angle)           // ~36.87 degrees
```

### Exponential and Logarithmic Functions

```mufi
exp(x)          // e^x
ln(x)           // Natural logarithm (base e)
log2(x)         // Logarithm base 2
log10(x)        // Logarithm base 10
pow(base, exp)  // base^exponent (same as ^)
sqrt(x)         // Square root
```

**Example:**
```mufi
import math

let growth_factor = exp(0.1)    // e^0.1 ≈ 1.105
let double_time = ln(2)         // Time for exponential doubling
```

### Rounding and Comparison Functions

```mufi
abs(x)          // Absolute value
ceil(x)         // Round up to nearest integer
floor(x)        // Round down to nearest integer
round(x)        // Round to nearest integer
trunc(x)        // Truncate decimal part
sign(x)         // Returns -1, 0, or 1
clamp(x, min, max)  // Clamp value between min and max
```

**Example:**
```mufi
import math

let price = 9.47
let rounded_price = round(price * 100) / 100   // $9.47
let clamped = clamp(user_age, 0, 150)         // Valid age range
```

### Geometric and Special Functions

```mufi
// Distance and angles
hypot(x, y)     // Euclidean distance: sqrt(x² + y²)
deg2rad(degrees)    // Convert degrees to radians
rad2deg(radians)    // Convert radians to degrees

// Integer operations
gcd(a, b)       // Greatest common divisor
lcm(a, b)       // Least common multiple
factorial(n)    // n! (factorial)
```

**Example:**
```mufi
import math

// Find greatest common divisor
let common = gcd(48, 18)    // 6

// Calculate combinations C(n,k) = n! / (k!(n-k)!)
let n = 10
let k = 3
let combinations = factorial(n) / (factorial(k) * factorial(n - k))
```

### Min and Max

```mufi
max(a, b)       // Maximum of two values
max(list)       // Maximum in a list
min(a, b)       // Minimum of two values
min(list)       // Minimum in a list
```

---

## Bitwise Operations

### Bitwise Operators

Bitwise operators work on the binary representations of integers:

```mufi
// Binary AND: both bits must be 1
let a = 5 band 3        // 0101 & 0011 = 0001 (1)

// Binary OR: at least one bit must be 1
let b = 5 bor 3         // 0101 | 0011 = 0111 (7)

// Binary XOR: bits must differ
let c = 5 bxor 3        // 0101 ^ 0011 = 0110 (6)

// Binary NOT: flip all bits (unary)
let d = bnot 5          // ~0101 = 1010 (platform-dependent)

// Left shift: multiply by 2^n
let e = 5 shl 1         // 0101 << 1 = 1010 (10)

// Right shift: divide by 2^n
let f = 5 shr 1         // 0101 >> 1 = 0010 (2)
```

### Use Cases

**Flag Management:**
```mufi
// Define permission flags
let READ = 1 shl 0     // 001
let WRITE = 1 shl 1    // 010
let EXECUTE = 1 shl 2  // 100

// Check permissions
let permissions = READ bor WRITE    // 011
let can_read = (permissions band READ) != 0    // true
let can_execute = (permissions band EXECUTE) != 0  // false

// Add permission
let permissions = permissions bor EXECUTE
```

**Bit Manipulation:**
```mufi
// Check if number is power of 2
let is_power_of_2 = (n band (n - 1)) == 0

// Count set bits
let count_bits = fn(n) {
    let count = 0
    while (n > 0) {
        count = count + (n band 1)
        n = n shr 1
    }
    return count
}

// Reverse bits
let reverse_bits = fn(n, bits) {
    let result = 0
    for i in 0 to bits {
        result = (result shl 1) bor (n band 1)
        n = n shr 1
    }
    return result
}
```

---

## Vector Operations

Vectors are 1D arrays of floating-point numbers, optimized for numerical computations.

### Vector Creation

```mufi
// Create vectors using array literals
let v1 = [1.0, 2.0, 3.0]
let v2 = [4.0, 5.0, 6.0]

// Create vectors with range
let v3 = [1..10]        // [1, 2, 3, ..., 10]
let v4 = [0..1 by 0.1]  // [0, 0.1, 0.2, ..., 1.0]
```

### Vector Operations

```mufi
// Dot product (scalar product)
let dot_product = dot(v1, v2)    // 1*4 + 2*5 + 3*6 = 32

// Vector magnitude (norm/length)
let magnitude = norm([3.0, 4.0])    // sqrt(9 + 16) = 5.0
let length = length([3.0, 4.0])     // Alias for norm
```

### Vector Arithmetic

```mufi
// Element-wise operations using loops
let add_vectors = fn(a, b) {
    let result = []
    for i in 0 to len(a) {
        result.push(a[i] + b[i])
    }
    return result
}

let multiply_scalar = fn(v, scalar) {
    let result = []
    for i in 0 to len(v) {
        result.push(v[i] * scalar)
    }
    return result
}

let scale = multiply_scalar([1, 2, 3], 2)    // [2, 4, 6]
```

### Vector Example: Euclidean Distance

```mufi
import math

let point1 = [0.0, 0.0]
let point2 = [3.0, 4.0]

// Method 1: Using hypot
let distance1 = hypot(point2[0] - point1[0], point2[1] - point1[1])

// Method 2: Using vector operations
let diff = [point2[0] - point1[0], point2[1] - point1[1]]
let distance2 = norm(diff)

// Both should equal 5.0
println("Distance: " .. distance1)
```

---

## Matrix Operations

Matrices are 2D arrays of numbers. See [MATRIX_GUIDE.md](./matrix_guide.md) for comprehensive matrix documentation.

### Matrix Creation

```mufi
// Create matrix using array literals
let m1 = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
]

// Create with constructor
import matrix
let m2 = matrix::create(3, 3, 0)    // 3x3 matrix filled with 0s
```

### Matrix Operations

```mufi
import matrix

let m1 = [[1, 2], [3, 4]]
let m2 = [[5, 6], [7, 8]]

// Arithmetic
let sum = matrix::add(m1, m2)
let product = matrix::multiply(m1, m2)
let transpose = matrix::transpose(m1)

// Properties
let det = matrix::determinant(m1)
let inv = matrix::inverse(m1)
let rank = matrix::rank(m1)
```

---

## Statistical Functions

Statistical functions work with lists or vectors of numerical data.

### Basic Statistics

```mufi
import math

let data = [1, 2, 3, 4, 5]

// Sum of all elements
let total = sum(data)        // 15

// Average (mean)
let average = mean(data)     // 3.0

// Spread (variance)
let spread = variance(data)  // 2.5 (sample variance)

// Standard deviation
let std_dev = stddev(data)   // sqrt(2.5) ≈ 1.581
```

### Statistical Example: Grade Analysis

```mufi
import math

let grades = [78, 85, 92, 88, 95, 82, 90]

let total = sum(grades)
let count = len(grades)
let average = mean(grades)
let std_dev = stddev(grades)

println("Total Score: " .. total)
println("Average: " .. average)
println("Std Dev: " .. std_dev)
println("Class Size: " .. count)

// Identify outliers (more than 2 std devs from mean)
for grade in grades {
    let z_score = (grade - average) / std_dev
    if abs(z_score) > 2 {
        println("Outlier: " .. grade .. " (z-score: " .. z_score .. ")")
    }
}
```

### Statistical Example: Quality Control

```mufi
import math

// Manufacturing: check if parts meet specifications
let measurements = [10.02, 9.98, 10.01, 9.99, 10.05, 9.97]
let target = 10.0
let tolerance = 0.1

let avg = mean(measurements)
let dev = stddev(measurements)

let within_spec = fn(measurements, target, tolerance) {
    for m in measurements {
        if abs(m - target) > tolerance {
            return false
        }
    }
    return true
}

if within_spec(measurements, target, tolerance) {
    println("✓ All parts within specification")
} else {
    println("✗ Some parts out of specification")
}
```

---

## Complex Numbers

Complex numbers have a real and imaginary part.

### Complex Number Creation

```mufi
import math

// Using complex() function
let z1 = complex(3, 4)       // 3 + 4i
let z2 = complex(1, -2)      // 1 - 2i

// Using arithmetic
let z3 = 3 + 4 * i   // Requires 'i' to be defined as complex(0, 1)
```

### Complex Operations

```mufi
import math

let z1 = complex(3, 4)
let z2 = complex(1, 2)

// Arithmetic
let sum = z1 + z2          // (3+4i) + (1+2i) = 4+6i
let product = z1 * z2      // (3+4i)(1+2i) = -5+10i

// Complex functions
let conjugate = conj(z1)   // 3 - 4i
let real_part = real(z1)   // 3
let imag_part = imag(z1)   // 4
let magnitude = abs(z1)    // sqrt(9 + 16) = 5
let angle = phase(z1)      // atan2(4, 3) ≈ 0.927 radians
```

### Complex Example: AC Circuit Analysis

```mufi
import math

// Impedance Z = R + jXL (resistance + inductive reactance)
let R = 10      // Resistance (ohms)
let XL = 15     // Inductive reactance (ohms)
let Z = complex(R, XL)

// Current magnitude for 100V source
let V = 100
let I_magnitude = V / abs(Z)    // Current amplitude

// Phase angle between voltage and current
let phase_angle = phase(Z)
let phase_degrees = rad2deg(phase_angle)

println("Impedance magnitude: " .. abs(Z) .. " ohms")
println("Current magnitude: " .. I_magnitude .. " A")
println("Phase angle: " .. phase_degrees .. "°")
```

---

## Examples and Patterns

### Linear Interpolation

```mufi
import math

// Interpolate between two points
let lerp = fn(a, b, t) {
    return a * (1 - t) + b * t
}

let v1 = [0, 0]
let v2 = [10, 10]
let halfway = [lerp(v1[0], v2[0], 0.5), lerp(v1[1], v2[1], 0.5)]
println("Halfway point: " .. halfway)    // [5, 5]
```

### Normalize Vector to Unit Length

```mufi
import math

let normalize = fn(v) {
    let mag = norm(v)
    if mag == 0 {
        return v
    }
    let result = []
    for i in 0 to len(v) {
        result.push(v[i] / mag)
    }
    return result
}

let v = [3, 4]
let v_unit = normalize(v)    // [0.6, 0.8]
println("Normalized: " .. v_unit)
```

### Running Average (Moving Average)

```mufi
import math

let moving_average = fn(data, window_size) {
    let result = []
    for i in 0 to len(data) - window_size + 1 {
        let window = []
        for j in i to i + window_size {
            window.push(data[j])
        }
        result.push(mean(window))
    }
    return result
}

let prices = [100, 102, 101, 103, 105, 104, 106]
let ma3 = moving_average(prices, 3)
println("3-day moving average: " .. ma3)
```

### Quadratic Formula

```mufi
import math

let solve_quadratic = fn(a, b, c) {
    let discriminant = b * b - 4 * a * c
    
    if discriminant < 0 {
        return nil    // No real solutions
    }
    
    let sqrt_disc = sqrt(discriminant)
    let x1 = (-b + sqrt_disc) / (2 * a)
    let x2 = (-b - sqrt_disc) / (2 * a)
    
    return [x1, x2]
}

// Solve x² - 5x + 6 = 0
let solutions = solve_quadratic(1, -5, 6)
println("Solutions: " .. solutions)        // [3, 2]
```

### Polynomial Evaluation (Horner's Method)

```mufi
import math

// Evaluate polynomial: a*x³ + b*x² + c*x + d
let eval_polynomial = fn(coeffs, x) {
    let result = 0
    for i in 0 to len(coeffs) {
        result = result * x + coeffs[i]
    }
    return result
}

// Evaluate 2x³ + 3x² - 5x + 7 at x=2
let coeffs = [2, 3, -5, 7]
let value = eval_polynomial(coeffs, 2)
println("P(2) = " .. value)        // 2*8 + 3*4 - 5*2 + 7 = 29
```

### Matrix-Vector Multiplication

```mufi
import math

let matrix_vector_mult = fn(matrix, vector) {
    let result = []
    for row in matrix {
        let dot_result = 0
        for i in 0 to len(vector) {
            dot_result = dot_result + row[i] * vector[i]
        }
        result.push(dot_result)
    }
    return result
}

let A = [[1, 2], [3, 4]]
let v = [5, 6]
let result = matrix_vector_mult(A, v)
println("A*v = " .. result)        // [17, 39]
```

---

## Performance Tips

1. **Use vectors for large numerical data**: Vectors are optimized for performance with native floating-point operations.

2. **Cache computed values**: Store frequently used values like norms or dot products to avoid recalculation.

3. **Use bitwise operations for flags**: Bitwise operations are faster than boolean arrays for flag management.

4. **Batch operations**: Process data in larger chunks when possible for better cache utilization.

5. **Avoid unnecessary type conversions**: Keep data in consistent types (integers or doubles) throughout calculations.

---

## Related Documentation

- [TYPE_REFERENCE.md](./TYPE_REFERENCE.md) - Complete type system reference
- [STDLIB_REFERENCE.md](./STDLIB_REFERENCE.md) - Full standard library documentation
- [Matrix Guide](./matrix_guide.md) - Comprehensive matrix operations guide
