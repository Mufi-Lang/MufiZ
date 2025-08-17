# LinkedList API Comparison

This document shows how to use the LinkedList with the new bounded methods API compared to the old free function API.

## API Comparison Table

| Operation | Old API (Free Functions) | New API (Bounded Methods) |
|-----------|-------------------------|---------------------------|
| Create | `newLinkedList()` | `LinkedList.init()` or `LinkedList.new()` |
| Push back | `pushBack(list, value)` | `list.push(value)` |
| Push front | `pushFront(list, value)` | `list.push_front(value)` |
| Pop back | `popBack(list)` | `list.pop()` |
| Pop front | `popFront(list)` | `list.pop_front()` |
| Get element | `nth(list, index)` | `list.get(index)` |
| Search | `searchLinkedList(list, value)` | `list.search(value)` |
| Sort | `mergeSort(list)` | `list.sort()` |
| Reverse | `reverseLinkedList(list)` | `list.reverse()` |
| Clear | `clearLinkedList(list)` | `list.clear()` |
| Clone | `cloneLinkedList(list)` | `list.clone()` |
| Equal | `equalLinkedList(a, b)` | `a.equal(b)` |
| Slice | `sliceLinkedList(list, start, end)` | `list.slice(start, end)` |
| Splice | `spliceLinkedList(list, start, end)` | `list.splice(start, end)` |
| Merge | `mergeLinkedList(a, b)` | `a.merge(b)` |

## Code Examples

### Old API (Free Functions)

```zig
// Create and populate a list
var list = newLinkedList();
pushBack(list, Value.init_int(1));
pushBack(list, Value.init_int(2));
pushBack(list, Value.init_int(3));
pushFront(list, Value.init_int(0));

// Access elements
var first = nth(list, 0);
var index = searchLinkedList(list, Value.init_int(2));

// Manipulate the list
mergeSort(list);
reverseLinkedList(list);

// Pop elements
var last = popBack(list);
var first = popFront(list);

// Create a slice
var sliced = sliceLinkedList(list, 1, 3);

// Clean up
clearLinkedList(list);
```

### New API (Bounded Methods)

```zig
// Create and populate a list
var list = LinkedList.init();
list.push(Value.init_int(1));
list.push(Value.init_int(2));
list.push(Value.init_int(3));
list.push_front(Value.init_int(0));

// Access elements
var first = list.get(0);
var index = list.search(Value.init_int(2));

// Manipulate the list
list.sort();
list.reverse();

// Pop elements
var last = list.pop();
var first = list.pop_front();

// Create a slice
var sliced = list.slice(1, 3);

// Clean up
list.clear();
```

### Method Chaining

With the new API, you can chain operations that return `self`:

```zig
var list = LinkedList.init();

// Chain multiple push operations
list.push(Value.init_int(5))
    .push(Value.init_int(3))
    .push(Value.init_int(7))
    .push(Value.init_int(1));

// Sort and reverse in one chain
list.sort().reverse();

// Clear and repopulate
list.clear()
    .push(Value.init_int(10))
    .push(Value.init_int(20));
```

### Iterator Pattern

The new API includes iterator methods similar to FloatVector:

```zig
var list = LinkedList.init();
list.push(Value.init_int(1));
list.push(Value.init_int(2));
list.push(Value.init_int(3));

// Iterator methods
while (list.has_next()) {
    if (list.next()) |value| {
        // Process value
        printValue(value);
    }
}

// Reset iterator
list.reset();

// Peek without advancing
if (list.peek()) |value| {
    // Value at current position
}

// Skip elements
list.skip(2);
```

### New Methods Not in Old API

The bounded methods API adds several convenient methods:

```zig
// Check if empty
if (list.is_empty()) {
    print("List is empty\n");
}

// Get length as a method
var count = list.len();

// Insert at specific position
list.insert(2, Value.init_int(99));

// Remove at specific position
var removed = list.remove(2);

// Set value at index
list.set(1, Value.init_int(42));

// Push multiple values at once
var values = [_]Value{
    Value.init_int(1),
    Value.init_int(2),
    Value.init_int(3),
};
list.pushMany(&values);
```

## Migration Guide

To migrate from the old API to the new API:

1. Replace `newLinkedList()` with `LinkedList.init()`
2. Replace function calls like `pushBack(list, value)` with method calls like `list.push(value)`
3. Take advantage of method chaining where appropriate
4. Use the new iterator methods for traversal
5. Use the convenience methods like `is_empty()` and `len()`

## Performance Notes

The new API has minimal overhead compared to the old API:
- Methods are inlined by the compiler when possible
- No virtual dispatch - all calls are resolved at compile time
- Same memory layout and allocation patterns
- Iterator methods add a single `pos` field to track position

## Compatibility

During the transition period, the old free functions can be implemented as wrappers around the new methods:

```zig
pub fn pushBack(list: *LinkedList, value: Value) void {
    list.push(value);
}

pub fn popBack(list: *LinkedList) Value {
    return list.pop();
}
```

This allows existing code to continue working while gradually migrating to the new API.