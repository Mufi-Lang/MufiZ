// This patch shows the changes needed in object.zig to use the new LinkedList with bounded methods

// Add this import after the FloatVector import (around line 11):
pub const LinkedList = @import("objects/linked_list.zig").LinkedList;
pub const ObjLinkedList = LinkedList;

// Replace the old ObjLinkedList struct definition (around lines 42-47) with:
// Update the Node struct if it's defined separately, or remove it since it's now in linked_list.zig

// Replace the newLinkedList function (around lines 407-413) with:
pub fn newLinkedList() *LinkedList {
    return LinkedList.init();
}

// Replace the cloneLinkedList function (around lines 414-422) with:
pub fn cloneLinkedList(list: *LinkedList) *LinkedList {
    return list.clone();
}

// Replace the clearLinkedList function (around lines 424-434) with:
pub fn clearLinkedList(list: *LinkedList) void {
    list.clear();
}

// Replace the pushFront function (around lines 436-449) with:
pub fn pushFront(list: *LinkedList, value: Value) void {
    list.push_front(value);
}

// Replace the pushBack function (around lines 451-464) with:
pub fn pushBack(list: *LinkedList, value: Value) void {
    list.push(value);
}

// Replace the popFront function (around lines 466-479) with:
pub fn popFront(list: *LinkedList) Value {
    return list.pop_front();
}

// Replace the popBack function (around lines 481-495) with:
pub fn popBack(list: *LinkedList) Value {
    return list.pop();
}

// Replace the equalLinkedList function (around lines 497-518) with:
pub fn equalLinkedList(a: *LinkedList, b: *LinkedList) bool {
    return a.equal(b);
}

// Replace the freeObjectLinkedList function (around lines 520-527) with:
pub fn freeObjectLinkedList(list: *LinkedList) void {
    list.clear();
    // Note: deinit() should be called by the memory manager
}

// Replace the mergeSort function (around lines 529-559) with:
pub fn mergeSort(list: *LinkedList) void {
    list.sort();
}

// Replace the searchLinkedList function (around lines 561-581) with:
pub fn searchLinkedList(list: *LinkedList, value: Value) i32 {
    return list.search(value);
}

// Replace the reverseLinkedList function (around lines 583-603) with:
pub fn reverseLinkedList(list: *LinkedList) void {
    list.reverse();
}

// Replace the mergeLinkedList function (around lines 605-634) with:
pub fn mergeLinkedList(a: *LinkedList, b: *LinkedList) *LinkedList {
    const result = LinkedList.init();
    // Copy all elements from a
    var current = a.head;
    while (current) |node| {
        result.push(node.data);
        current = node.next;
    }
    // Copy all elements from b
    current = b.head;
    while (current) |node| {
        result.push(node.data);
        current = node.next;
    }
    return result;
}

// Replace the sliceLinkedList function (around lines 635-649) with:
pub fn sliceLinkedList(list: *LinkedList, start: i32, end: i32) *LinkedList {
    return list.slice(start, end);
}

// Replace the spliceLinkedList function (around lines 650-684) with:
pub fn spliceLinkedList(list: *LinkedList, start: i32, end: i32) *LinkedList {
    return list.splice(start, end);
}

// For backward compatibility, keep these wrapper functions that delegate to the bounded methods.
// This allows existing code to continue working while gradually migrating to the new API.
// Eventually, these wrapper functions can be removed and callers can use the methods directly.
