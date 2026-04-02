# MufiZ Math Module - Complete Reference

## Overview
This document describes all mathematical functions and constants available in the MufiZ math module, including 55+ new functions added across Phases 1-4.

## Phase 1: Hyperbolic Functions

### Hyperbolic Trigonometric Functions
```
sinh(x)     -> Hyperbolic sine
cosh(x)     -> Hyperbolic cosine  
tanh(x)     -> Hyperbolic tangent
asinh(x)    -> Inverse hyperbolic sine
acosh(x)    -> Inverse hyperbolic cosine
atanh(x)    -> Inverse hyperbolic tangent
```

**Example:**
```mufi
y = sinh(1.0);  // = 1.1752...
z = cosh(0);    // = 1.0
```

### Angle & Utility Functions
```
atan2(y, x)     -> Arctangent with quadrant handling (radians)
sign(x)         -> Returns -1, 0, or 1
clamp(x, min, max) -> Constrain value to [min, max]
```

**Example:**
```mufi
angle = atan2(1, 1);        // = π/4
s = sign(-5);               // = -1
clamped = clamp(15, 1, 10); // = 10
```

### Enhanced Complex Number Operations
```
real(z)     -> Extract real part of complex number
imag(z)     -> Extract imaginary part of complex number
conj(z)     -> Complex conjugate
```

**Example:**
```mufi
z = complex(3, 4);
r = real(z);     // = 3
i = imag(z);     // = 4
c = conj(z);     // = complex(3, -4)
```

### Math Constants
```
PI      -> π (3.141592653589793)
E       -> e (2.718281828459045)
TAU     -> 2π (6.283185307179586)
PHI     -> Golden ratio (1.618033988749895)
SQRT2   -> √2 (1.4142135623730951)
LN2     -> ln(2) (0.6931471805599453)
LN10    -> ln(10) (2.302585092994046)
```

---

## Phase 2: Vector Math Operations

### Dot Product & Magnitudes
```
dot(v1, v2)        -> Scalar dot product of two vectors
magnitude(v)       -> Vector length (norm)
distance(v1, v2)   -> Euclidean distance between vectors
angle_between(v1, v2) -> Angle between vectors in radians
```

**Example:**
```mufi
v1 = [1, 0, 0];
v2 = [0, 1, 0];
d = dot(v1, v2);        // = 0
m = magnitude(v1);      // = 1
dist = distance(v1, v2); // = √2
ang = angle_between(v1, v2); // = π/2
```

### Cross Product & 3D Operations
```
cross(v1, v2)  -> Cross product (3D vectors only)
```

**Example:**
```mufi
u = [1, 0, 0];
v = [0, 1, 0];
result = cross(u, v);  // = [0, 0, 1]
```

### Vector Projections
```
normalize(v)        -> Unit vector in same direction
project(v1, v2)     -> Project v1 onto v2
reject(v1, v2)      -> Rejection of v1 from v2
lerp(v1, v2, t)     -> Linear interpolation (t ∈ [0, 1])
```

**Example:**
```mufi
v = [3, 4];
n = normalize(v);           // = [0.6, 0.8]
p = project(v1, v2);        // = projected component
l = lerp([0, 0], [10, 10], 0.5); // = [5, 5]
```

---

## Phase 3: Statistics & Data Analysis

### Descriptive Statistics
```
median(vec)            -> Middle value (50th percentile)
mode(vec)              -> Most frequent value
percentile(vec, p)     -> p-th percentile (p ∈ [0, 100])
quantile(vec, q)       -> q-th quantile (q ∈ [0, 1])
```

**Example:**
```mufi
data = [1, 2, 3, 4, 5, 5, 6];
med = median(data);        // = 4
m = mode(data);            // = 5
p75 = percentile(data, 75); // 75th percentile
q1 = quantile(data, 0.25);  // 1st quartile
```

### Statistical Relationships
```
covariance(v1, v2)    -> Covariance between vectors
correlation(v1, v2)   -> Pearson correlation coefficient (-1 to 1)
```

**Example:**
```mufi
x = [1, 2, 3, 4, 5];
y = [2, 4, 5, 4, 6];
cov = covariance(x, y);  // Covariance value
corr = correlation(x, y); // Correlation (-1 to 1)
```

### Sequence Operations
```
cumsum(vec)   -> Cumulative sum [1,2,3] → [1,3,6]
cumprod(vec)  -> Cumulative product [1,2,3] → [1,2,6]
diff(vec)     -> Differences [1,3,7] → [2,4]
```

**Example:**
```mufi
data = [1, 2, 3, 4];
cs = cumsum(data);   // = [1, 3, 6, 10]
cp = cumprod(data);  // = [1, 2, 6, 24]
d = diff(data);      // = [1, 1, 1]
```

### Array Analysis
```
histogram(vec, bins)         -> Bin data into histogram
moving_average(vec, window)  -> Simple moving average
```

**Example:**
```mufi
values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
h = histogram(values, 5);    // 5-bin histogram
ma = moving_average(values, 3); // 3-point MA
```

---

## Phase 4: Advanced Features

### Reproducible Randomness
```
set_seed(seed)  -> Set global PRNG seed for reproducibility
get_seed()      -> Get current seed value
randint(min, max) -> Random integer in [min, max)
randrange(min, max, n) -> n random floats in [min, max)
```

**Example:**
```mufi
set_seed(42);
r1 = randint(1, 100);
set_seed(42);
r2 = randint(1, 100);
// r1 == r2 (reproducible)
```

### Number Classification
```
isnan(x)      -> Check if value is NaN (1 or 0)
isinf(x)      -> Check if value is infinite (1 or 0)
isfinite(x)   -> Check if value is finite (1 or 0)
```

**Example:**
```mufi
print(isnan(0/0));     // = 1
print(isinf(1/0));     // = 1
print(isfinite(42));   // = 1
```

### Integer Functions
```
factorial(n)  -> n! (0! = 1, grows quickly)
gcd(a, b)     -> Greatest common divisor
lcm(a, b)     -> Least common multiple
```

**Example:**
```mufi
f = factorial(5);    // = 120
g = gcd(48, 18);     // = 6
l = lcm(12, 18);     // = 36
```

### Prime Numbers
```
isprime(n)    -> Check if n is prime (returns 1 or 0)
nextprime(n)  -> Find next prime after n
```

**Example:**
```mufi
if isprime(17) {
    print("17 is prime!");
}
np = nextprime(10);  // = 11
```

---

## Performance Characteristics

### SIMD Optimizations
- Vector operations (`dot`, `cross`, `magnitude`, `normalize`, `distance`) leverage SIMD for large vectors
- Statistical functions operate in O(n) time
- `median` requires sorting: O(n log n)
- `isprime` uses trial division: O(√n)
- `nextprime` iterates until prime found

### Numeric Precision
- All math functions use 64-bit floating-point (f64)
- Complex numbers maintain full precision
- Integer functions use 32-bit signed integers
- Large factorials overflow (not handled specially)

---

## Error Handling

Functions return errors in these cases:
- **Vector size mismatches**: Operations on vectors of different sizes
- **Empty vectors**: Statistical functions on empty arrays
- **Invalid ranges**: `clamp` with min > max, `randint` with min >= max
- **Domain errors**: `acosh`, `atanh` with values outside domain

---

## Type Coercion

All functions follow MufiZ's standard type coercion:
- Numbers converted to floats for math operations
- Complex numbers handled specially (angle, magnitude)
- Vectors required for vector operations
- Strings converted to numbers where applicable

---

## Integration with Other Modules

### Collections Module
Statistical functions operate on arrays/vectors:
```mufi
data = [1, 2, 3, 4, 5];
avg = sum(data) / len(data);
med = median(data);
```

### Complex Number Integration
Math functions work with complex numbers:
```mufi
z = complex(3, 4);
m = magnitude(z);    // Returns 5
a = abs(z);          // Alternative
```

---

## Examples

### Vector-based Geometry
```mufi
// Calculate angle between two 3D vectors
v1 = [1, 0, 0];
v2 = [1, 1, 0];
angle = angle_between(v1, v2);

// Project vector onto plane
v_plane = [1, 1, 0];
v_proj = project(v, v_plane);
```

### Data Analysis Pipeline
```mufi
// Load data and compute statistics
data = [23, 45, 12, 67, 34, 56, 78, 45];

// Central tendency
med = median(data);
avg = sum(data) / len(data);

// Spread
q1 = quantile(data, 0.25);
q3 = quantile(data, 0.75);
iqr = q3 - q1;

// Distribution
hist = histogram(data, 5);
```

### Seeded Random Simulation
```mufi
// Set seed for reproducibility
set_seed(12345);

// Generate random data
n = 100;
data = [];
for i in range(n) {
    r = randint(1, 1000);
    data.push(r);
}

// Analyze
print("Mean:", sum(data) / len(data));
print("Median:", median(data));
```

---

## Version Information
- Added in MufiZ v0.11.0+
- 55+ new functions across 4 implementation phases
- Full backward compatibility maintained
- All existing functions continue to work unchanged
