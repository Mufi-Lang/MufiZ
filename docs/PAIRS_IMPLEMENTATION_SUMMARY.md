# Pairs Implementation Summary

## Overview

This document describes the implementation of the new `pairs` type in the MufiZ language, designed to enhance the experience of working with hash tables by providing a clean way to iterate over key-value pairs. The implementation includes native arrow syntax (`=>`) for creating pairs.

## Implementation Details

### 1. ObjPair Type

A new object type `ObjPair` was created in `/src/objects/pair.zig`:

```zig
pub const ObjPair = struct {
    obj: Obj,
    key: Value,
    value: Value,
    
    // Methods include:
    // - create(key, value) - Creates a new pair
    // - free() - Frees the pair and releases references
    // - first() - Returns the key
    // - second() - Returns the value
    // - index(idx) - Returns key for idx=0, value for idx=1
    // - length() - Always returns 2
    // - equal(other) - Checks equality with another pair
    // - toString() - String representation "(key, value)"
};
```

### 2. Type System Integration

The following changes were made to integrate pairs into the type system:

- Added `OBJ_PAIR = 12` to the `ObjType` enum in `/src/objects/obj.zig`
- Added `is_pair()` and `as_pair()` methods to the `Value` type in `/src/value.zig`
- Updated `valuesEqual()` to handle pair comparison
- Added pair support to `printObject()` and `objToString()` functions

### 3. Memory Management

Proper memory management was implemented:

- Added `OBJ_PAIR` case to `freeObject()` in `/src/memory.zig`
- Added `OBJ_PAIR` case to `blackenObject()` for garbage collection
- Pairs properly retain and release references to their key and value

### 4. VM Support

The VM was updated to handle pairs:

- Added `OBJ_PAIR` support to `OP_LENGTH` operation (always returns 2)
- Added `OBJ_PAIR` support to `OP_GET_INDEX` operation (0 for key, 1 for value)

### 5. Standard Library Functions

New and updated functions in the collections module:

- `pairs(hash_table)` - Converts a hash table to a linked list of pairs
- `len()` - Updated to support pairs (returns 2)
- `nth()` - Updated to support pairs for accessing key/value by index

### 6. Native Arrow Syntax

The language now supports native arrow syntax for creating pairs:

- `key => value` - Creates a new pair with the given key and value
- Implemented via `TOKEN_ARROW` in the scanner and `OP_PAIR` opcode
- Works with any value types (strings, numbers, booleans, objects, etc.)
- Supports nested pairs: `"outer" => ("inner" => 42)`

## Usage Examples

### Basic Usage

```mufi
// Create pairs using arrow syntax
var pair1 = "name" => "Alice";
var pair2 = "age" => 30;
print pair1;  // Output: (name, Alice)
print pair1[0];  // Output: name
print pair1[1];  // Output: Alice

// Create a hash table
var scores = hash_table();
put(scores, "Math", 95);
put(scores, "Science", 88);
put(scores, "English", 92);

// Get pairs from the hash table
var score_pairs = pairs(scores);
print score_pairs;  // Output: [(Math, 95), (Science, 88), (English, 92)]

// Access individual pairs
var first_pair = nth(score_pairs, 0);
print first_pair;  // Output: (Math, 95)

// Access key and value
print nth(first_pair, 0);  // Output: Math
print nth(first_pair, 1);  // Output: 95
```

### Using Arrow Syntax with Collections

```mufi
// Create a list of configuration pairs
var config = linked_list();
push(config, "host" => "localhost");
push(config, "port" => 8080);
push(config, "ssl" => false);

// Access pairs from the list
var first = nth(config, 0);
print first[0];  // Output: host
print first[1];  // Output: localhost

// Nested pairs
var nested = "user" => ("id" => 123);
print nested;  // Output: (user, (id, 123))
print nested[1][0];  // Output: id
print nested[1][1];  // Output: 123
```

### Manual Iteration

Since there appears to be an issue with foreach loops and linked lists in the current implementation, manual iteration can be used:

```mufi
var i = 0;
var total = len(score_pairs);
while (i < total) {
    var pair = nth(score_pairs, i);
    var subject = nth(pair, 0);
    var score = nth(pair, 1);
    
    print subject;
    print ": ";
    print score;
    
    i = i + 1;
}
```

### Working with Empty Hash Tables

```mufi
var empty_ht = hash_table();
var empty_pairs = pairs(empty_ht);
print empty_pairs;  // Output: []
print len(empty_pairs);  // Output: 0
```

## Benefits

1. **Clean Iteration**: Provides a structured way to iterate over hash table contents
2. **Key-Value Access**: Easy access to both keys and values during iteration
3. **Type Safety**: Pairs are a distinct type with defined behavior
4. **Integration**: Works seamlessly with existing collection functions
5. **Immutability**: Pairs are immutable once created
6. **Native Syntax**: Arrow syntax (`=>`) provides intuitive pair creation
7. **Composition**: Supports nested pairs and complex data structures

## Known Issues

1. **Foreach Loops**: There appears to be an issue with foreach loops over linked lists in the current MufiZ implementation. This affects iteration over the pairs list returned by `pairs()`. Manual iteration using while loops works correctly.

2. **Destructuring**: The language doesn't currently support destructuring assignment, so pairs must be accessed using `nth()` or indexing.

## Future Enhancements

1. **Destructuring Support**: Add syntax like `foreach ((key, value) in pairs(ht))` for cleaner iteration
2. **Fix Foreach**: Resolve the foreach issue with linked lists
3. **Additional Methods**: Consider adding methods like `swap()`, `withKey()`, `withValue()` for pair manipulation
4. **Pattern Matching**: Support pattern matching on pairs in future language versions
5. **Hash Table Literal**: Consider syntax like `#{ key1 => value1, key2 => value2 }` for hash table literals

## Technical Notes

- Pairs are reference-counted objects that properly retain their key and value
- The `pairs()` function creates a new linked list containing pair objects
- Each pair is an independent object with its own memory management
- Hash table iteration order depends on the internal hash table implementation

## Conclusion

The pairs type with native arrow syntax successfully enhances the MufiZ language by providing a clean, type-safe, and intuitive way to work with key-value pairs. The `=>` operator makes pair creation natural and readable, while the pairs() function enables elegant hash table iteration. While foreach loop support requires fixing, the implementation provides all the necessary functionality for effective hash table iteration and manipulation, establishing a foundation for more advanced functional programming patterns in MufiZ.