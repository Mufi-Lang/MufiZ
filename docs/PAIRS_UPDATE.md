# Pairs Statement Support Added

## Summary

Enhanced the MufiZ data generator to include **pair literal syntax** and pair-related operations using the `=>` operator.

## Changes Made

### 1. Pair Literal Generation (`generate_pair_literal`)
```python
def generate_pair_literal(self, depth):
    """Generate pair literal using => operator: key => value"""
    key = self.generate_simple_value(depth + 1)
    value = self.generate_simple_value(depth + 1)
    return f"{key} => {value}"
```

### 2. Pair Statement Patterns (`generate_pairs_statement`)

The generator now creates four types of pair-related code:

**A. Simple Pair Literals (20%)**
```mufi
var pair_var = "key" => "value";
print(pair_var[0]);
print(pair_var[1]);
```

**B. Nested Pairs (15%)**
```mufi
var nested = "outer" => ("inner" => 100);
print(nested[1][0]);
print(nested[1][1]);
```

**C. Pairs in Lists (15%)**
```mufi
var list = linked_list();
push(list, "name" => "Alice");
push(list, "age" => 30);
var first_pair = nth(list, 0);
print(first_pair[0]);
```

**D. Hash Table to Pairs (30%)**
```mufi
var ht = #{"a": 1, "b": 2};
var pair_list = pairs(ht);
```

**E. Foreach with Pairs (20%)**
```mufi
foreach (pair in pairs(hash_table)) {
    print(pair[0]);  // key
    print(pair[1]);  // value
}
```

### 3. Integration Points

1. **In Primary Expressions**: 15% chance to generate pair literals
2. **In Statements**: 5% chance to generate pair-specific statements
3. **In Foreach Loops**: 30% chance to use `pairs()` for hash table iteration
4. **In Program Generation**: 20% chance to include pair demonstration at start
5. **In Main Statements**: 10% additional chance for pair statements

## Syntax Details

### Pair Creation
```mufi
// Basic pair
var p1 = "key" => "value";

// With expressions
var p2 = (x + y) => (x * y);

// Nested pairs
var p3 = "outer" => ("inner" => val);
```

### Pair Access
```mufi
var pair = "name" => "Alice";
print(pair[0]);  // "name"
print(pair[1]);  // "Alice"
print(len(pair));  // 2
```

### Pairs Function
```mufi
var ht = #{"a": 1, "b": 2};
var pair_list = pairs(ht);
// pair_list is a linked list of pair objects
```

### Foreach with Pairs
```mufi
// Iterate over hash table using pairs
foreach (item in pairs(hash_table)) {
    print(item[0]);  // key
    print(item[1]);  // value
}

// Also works in foreach with vectors of pairs
var vec = {("a" => 1), ("b" => 2)};
foreach (pair in vec) {
    print(pair[0]);
}
```

## Testing

Generated code successfully validates:
```bash
python3 tools/mufiz_dataset_gen.py --count 10 --output ./test_pairs
```

Sample output includes:
- Simple pair creation and access
- Nested pair structures
- Pairs stored in linked lists
- Hash table conversion to pairs
- Foreach iteration over pairs

## Statistics

With pair support enabled, the generator now produces:
- **~20% of programs** include pair-related code
- **4 distinct pair patterns** randomly chosen
- **Pair literals** can appear in primary expressions
- **Foreach loops** have 30% chance to use `pairs()` 

## Documentation Updated

- `tools/README_STDLIB_EXTRACTION.md` - Added pair examples and documentation
- Examples show all pair patterns with code snippets
- Troubleshooting section updated

## Benefits

1. **Complete Language Coverage**: Pairs are a core MufiZ feature now properly represented
2. **Realistic Code**: Generated programs use idiomatic pair patterns
3. **Better Testing**: Validates pair syntax, `pairs()` function, and pair operations
4. **Educational**: Shows various ways to use pairs in MufiZ code

## Example Generated Code

```mufi
// Auto-generated MuFi program

fun process_data(data) {
    return data;
}

// Nested pair demonstration
var nested_pair = true => (false => 3.23);
print(nested_pair[1][0]);
print(nested_pair[1][1]);

// Pairs in collections
var pair_list = linked_list();
push(pair_list, "name" => "Alice");
push(pair_list, "age" => 30);
var first = nth(pair_list, 0);
print(first[0]);

// Hash table iteration
var ht = #{"x": 1, "y": 2};
foreach (pair in pairs(ht)) {
    print(pair[0]);
    print(pair[1]);
}

print("Program completed");
```

## References

- Pair implementation: `src/objects/pair.zig`
- Pairs test suite: `test_suite/pairs_assert_test.mufi`
- Collections module: `src/stdlib/collections.zig` (pairs() function)
- Grammar: `docs/grammar.peg` (Term <- Factor (_ ("+" / "-" / "=>") _ Factor)*)
