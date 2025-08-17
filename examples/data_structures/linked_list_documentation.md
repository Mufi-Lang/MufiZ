# LinkedList Class Documentation

This document shows how to organize linked list operations into a struct/class with bounded methods, similar to the float vector pattern in MufiZ.

## Basic LinkedList Class

The LinkedList class wraps the native `linked_list()` type and provides an object-oriented interface with method chaining support.

```mufi
class LinkedList {
    init() {
        self.data = linked_list();
    }

    // Core operations
    push(value) {
        push(self.data, value);
        return self;
    }

    push_front(value) {
        push_front(self.data, value);
        return self;
    }

    pop() {
        return pop(self.data);
    }

    pop_front() {
        return pop_front(self.data);
    }

    // Access operations
    at(index) {
        return nth(self.data, index);
    }

    nth(index) {
        return nth(self.data, index);
    }

    len() {
        return len(self.data);
    }

    // Search and manipulation
    search(value) {
        return search(self.data, value);
    }

    sort() {
        sort(self.data);
        return self;
    }

    reverse() {
        reverse(self.data);
        return self;
    }

    // Utility methods
    is_empty() {
        return len(self.data) == 0;
    }

    clear() {
        self.data = linked_list();
        return self;
    }

    contains(value) {
        return search(self.data, value) != -1;
    }

    print() {
        print(self.data);
        return self;
    }

    // Get underlying data for compatibility
    get_data() {
        return self.data;
    }
}
```

## Usage Examples

### Basic Operations

```mufi
// Create a new linked list
var list = LinkedList();

// Add elements
list.push(1).push(2).push(3);

// Access elements
var first = list.at(0);  // 1
var second = list.at(1); // 2
var length = list.len(); // 3

// Remove elements
var last = list.pop();      // returns 3
var first = list.pop_front(); // returns 1
```

### Method Chaining

```mufi
// Create, populate, sort, and print in one chain
var list = LinkedList()
    .push(5)
    .push(2)
    .push(8)
    .push(1)
    .sort()
    .print();  // Output: [1, 2, 5, 8]
```

### Working with Different Types

```mufi
// String list
var names = LinkedList();
names.push("Alice").push("Bob").push("Charlie");

// Check if contains
if (names.contains("Bob")) {
    print("Found Bob!");
}

// Mixed types (if supported)
var mixed = LinkedList();
mixed.push(42).push("hello").push(3.14);
```

## Advanced LinkedList Class

For more advanced use cases, you can extend the basic LinkedList:

```mufi
class AdvancedLinkedList < LinkedList {
    // Insert at specific position
    insert(index, value) {
        if (index < 0 || index > self.len()) {
            return self;
        }
        
        if (index == 0) {
            return self.push_front(value);
        }
        
        if (index == self.len()) {
            return self.push(value);
        }
        
        // Rebuild list for middle insertion
        var new_data = linked_list();
        var i = 0;
        while (i < index) {
            push(new_data, self.at(i));
            i = i + 1;
        }
        push(new_data, value);
        while (i < self.len()) {
            push(new_data, self.at(i));
            i = i + 1;
        }
        self.data = new_data;
        return self;
    }

    // Remove at specific position
    remove_at(index) {
        if (index < 0 || index >= self.len()) {
            return nil;
        }
        
        if (index == 0) {
            return self.pop_front();
        }
        
        if (index == self.len() - 1) {
            return self.pop();
        }
        
        var value = self.at(index);
        var new_data = linked_list();
        var i = 0;
        while (i < self.len()) {
            if (i != index) {
                push(new_data, self.at(i));
            }
            i = i + 1;
        }
        self.data = new_data;
        return value;
    }

    // Map function
    map(func) {
        var result = AdvancedLinkedList();
        var i = 0;
        while (i < self.len()) {
            result.push(func(self.at(i)));
            i = i + 1;
        }
        return result;
    }

    // Filter function
    filter(predicate) {
        var result = AdvancedLinkedList();
        var i = 0;
        while (i < self.len()) {
            var elem = self.at(i);
            if (predicate(elem)) {
                result.push(elem);
            }
            i = i + 1;
        }
        return result;
    }

    // Reduce function
    reduce(func, initial) {
        var result = initial;
        var i = 0;
        while (i < self.len()) {
            result = func(result, self.at(i));
            i = i + 1;
        }
        return result;
    }

    // For each element
    foreach(func) {
        var i = 0;
        while (i < self.len()) {
            func(self.at(i));
            i = i + 1;
        }
        return self;
    }
}
```

## Functional Operations Example

```mufi
var numbers = AdvancedLinkedList();
numbers.push(1).push(2).push(3).push(4).push(5);

// Map: square each number
var squared = numbers.map(fun(x) { return x * x; });
// Result: [1, 4, 9, 16, 25]

// Filter: keep only even numbers
var evens = numbers.filter(fun(x) { return x % 2 == 0; });
// Result: [2, 4]

// Reduce: sum all numbers
var sum = numbers.reduce(fun(acc, x) { return acc + x; }, 0);
// Result: 15

// Foreach: print each element
numbers.foreach(fun(x) { print("Number: " + str(x)); });
```

## Comparison with Native Functions

The LinkedList class provides the same functionality as native linked list functions but with a more organized, object-oriented interface:

| Native Function | LinkedList Method | Example |
|----------------|-------------------|---------|
| `push(ll, val)` | `ll.push(val)` | `list.push(5)` |
| `push_front(ll, val)` | `ll.push_front(val)` | `list.push_front(0)` |
| `pop(ll)` | `ll.pop()` | `var last = list.pop()` |
| `pop_front(ll)` | `ll.pop_front()` | `var first = list.pop_front()` |
| `nth(ll, i)` | `ll.at(i)` or `ll.nth(i)` | `var elem = list.at(2)` |
| `len(ll)` | `ll.len()` | `var size = list.len()` |
| `search(ll, val)` | `ll.search(val)` | `var idx = list.search(42)` |
| `sort(ll)` | `ll.sort()` | `list.sort()` |
| `reverse(ll)` | `ll.reverse()` | `list.reverse()` |

## Benefits of the Class-Based Approach

1. **Method Chaining**: Operations can be chained together for cleaner code
2. **Encapsulation**: The internal data structure is hidden from direct access
3. **Extensibility**: Easy to add new methods or create specialized versions
4. **Consistency**: All operations follow the same pattern (method calls on the object)
5. **Self-Documenting**: Methods clearly indicate what operations are available

## Migration Guide

To migrate from native linked list functions to the LinkedList class:

```mufi
// Old style
var ll = linked_list();
push(ll, 1);
push(ll, 2);
push(ll, 3);
sort(ll);
var idx = search(ll, 2);

// New style
var list = LinkedList();
list.push(1).push(2).push(3).sort();
var idx = list.search(2);
```

## Performance Considerations

The LinkedList class is a thin wrapper around native linked list operations, so there should be minimal performance overhead. The main cost is the additional method call indirection, which is typically negligible compared to the actual linked list operations.

## Thread Safety

The LinkedList class does not provide thread safety. If you need to use a LinkedList in a multi-threaded environment, you should add appropriate synchronization mechanisms.

## Future Enhancements

Potential additions to the LinkedList class:

1. **Iterators**: Support for more advanced iteration patterns
2. **Slicing**: Extract sublists efficiently
3. **Concatenation**: Join multiple lists together
4. **Serialization**: Convert to/from other formats
5. **Custom Comparators**: Support for custom sorting logic