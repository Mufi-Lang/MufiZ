const std = @import("std");

const reallocate = @import("../memory.zig").reallocate;
const allocateObject = @import("../object.zig").allocateObject;
const Value = @import("../value.zig").Value;
const printValue = @import("../value.zig").printValue;
const valuesEqual = @import("../value.zig").valuesEqual;
const valueCompare = @import("../value.zig").valueCompare;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

pub const Node = struct {
    data: Value,
    next: ?*Node,
    prev: ?*Node,
};

/// LinkedList struct with bounded methods, following the FloatVector pattern
pub const LinkedList = struct {
    obj: Obj,
    head: ?*Node,
    tail: ?*Node,
    count: i32,
    pos: usize, // Iterator position

    const Self = *@This();

    /// Creates a new empty linked list
    pub fn init() Self {
        const list: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(LinkedList), .OBJ_LINKED_LIST)));
        list.head = null;
        list.tail = null;
        list.count = 0;
        list.pos = 0;
        return list;
    }

    /// Creates a new linked list (alias for init)
    pub fn new() Self {
        return LinkedList.init();
    }

    /// Frees the linked list and all its nodes
    pub fn deinit(self: Self) void {
        var current: ?*Node = self.head;
        while (current) |node| {
            const next: ?*Node = node.next;
            _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
            current = next;
        }
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(LinkedList), 0);
    }

    /// Prints the linked list
    pub fn print(self: Self) void {
        std.debug.print("[", .{});
        var current = self.head;
        var first = true;
        while (current) |node| {
            if (!first) std.debug.print(", ", .{});
            first = false;
            printValue(node.data);
            current = node.next;
        }
        std.debug.print("]", .{});
    }

    /// Adds a value to the front of the list
    pub fn push_front(self: Self, value: Value) void {
        const node: *Node = @as(*Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node)))));
        node.data = value;
        node.prev = null;
        node.next = self.head;

        if (self.head) |head| {
            head.prev = node;
        }
        self.head = node;

        if (self.tail == null) {
            self.tail = node;
        }
        self.count += 1;
    }

    /// Adds a value to the back of the list
    pub fn push(self: Self, value: Value) void {
        const node: *Node = @as(*Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node)))));
        node.data = value;
        node.prev = self.tail;
        node.next = null;

        if (self.tail) |tail| {
            tail.next = node;
        }
        self.tail = node;

        if (self.head == null) {
            self.head = node;
        }
        self.count += 1;
    }

    /// Adds multiple values to the back of the list
    pub fn pushMany(self: Self, values: []const Value) void {
        for (values) |value| {
            self.push(value);
        }
    }

    /// Removes and returns the first element
    pub fn pop_front(self: Self) Value {
        const node = self.head orelse return Value.init_nil();
        const data: Value = node.data;

        self.head = node.next;
        if (self.head) |head| {
            head.prev = null;
        }
        if (self.tail == node) {
            self.tail = null;
        }
        self.count -= 1;
        _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
        return data;
    }

    /// Removes and returns the last element
    pub fn pop(self: Self) Value {
        const node = self.tail orelse return Value.init_nil();
        const data: Value = node.data;

        self.tail = node.prev;
        if (self.tail) |tail| {
            tail.next = null;
        }
        if (self.head == node) {
            self.head = null;
        }
        self.count -= 1;
        _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
        return data;
    }

    /// Gets the value at the specified index
    pub fn get(self: Self, index: i32) Value {
        if (index < 0 or index >= self.count) {
            return Value.init_nil();
        }

        var current = self.head;
        var i: i32 = 0;
        while (i < index) : (i += 1) {
            current = current.?.next;
        }
        return current.?.data;
    }

    /// Sets the value at the specified index
    pub fn set(self: Self, index: i32, value: Value) void {
        if (index < 0 or index >= self.count) {
            return;
        }

        var current = self.head;
        var i: i32 = 0;
        while (i < index) : (i += 1) {
            current = current.?.next;
        }
        current.?.data = value;
    }

    /// Inserts a value at the specified index
    pub fn insert(self: Self, index: i32, value: Value) void {
        if (index < 0 or index > self.count) {
            return;
        }

        if (index == 0) {
            self.push_front(value);
            return;
        }

        if (index == self.count) {
            self.push(value);
            return;
        }

        var current = self.head;
        var i: i32 = 0;
        while (i < index - 1) : (i += 1) {
            current = current.?.next;
        }

        const node: *Node = @as(*Node, @ptrCast(@alignCast(reallocate(null, 0, @sizeOf(Node)))));
        node.data = value;
        node.prev = current;
        node.next = current.?.next;

        if (current.?.next) |next| {
            next.prev = node;
        }
        current.?.next = node;

        self.count += 1;
    }

    /// Removes the element at the specified index
    pub fn remove(self: Self, index: i32) Value {
        if (index < 0 or index >= self.count) {
            return Value.init_nil();
        }

        if (index == 0) {
            return self.pop_front();
        }

        if (index == self.count - 1) {
            return self.pop();
        }

        var current = self.head;
        var i: i32 = 0;
        while (i < index) : (i += 1) {
            current = current.?.next;
        }

        const node = current.?;
        const data = node.data;

        if (node.prev) |prev| {
            prev.next = node.next;
        }
        if (node.next) |next| {
            next.prev = node.prev;
        }

        self.count -= 1;
        _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
        return data;
    }

    /// Clears all elements from the list
    pub fn clear(self: Self) void {
        var current: ?*Node = self.head;
        while (current) |node| {
            const next: ?*Node = node.next;
            _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
            current = next;
        }
        self.head = null;
        self.tail = null;
        self.count = 0;
        self.pos = 0;
    }

    /// Creates a copy of the list
    pub fn clone(self: Self) Self {
        const newList = LinkedList.init();
        var current: ?*Node = self.head;
        while (current) |node| {
            newList.push(node.data);
            current = node.next;
        }
        return newList;
    }

    /// Searches for a value and returns its index (-1 if not found)
    pub fn search(self: Self, value: Value) i32 {
        if (self.head == null) {
            return -1;
        }

        var current = self.head;
        var index: i32 = 0;

        while (current) |node| {
            if (valuesEqual(node.data, value)) {
                return index;
            }
            current = node.next;
            index += 1;
        }

        return -1;
    }

    /// Reverses the list in place
    pub fn reverse(self: Self) void {
        if (self.head == null) {
            return;
        }

        var current = self.head;
        while (current) |node| {
            // Swap next and prev pointers
            const temp = node.next;
            node.next = node.prev;
            node.prev = temp;
            current = temp;
        }

        // Swap head and tail
        const temp = self.head;
        self.head = self.tail;
        self.tail = temp;
    }

    /// Sorts the list using merge sort
    pub fn sort(self: Self) void {
        if (self.count < 2) {
            return;
        }

        // Create temporary list structures for splitting
        var left = LinkedList{
            .obj = self.obj,
            .head = null,
            .tail = null,
            .count = 0,
            .pos = 0,
        };
        var right = LinkedList{
            .obj = self.obj,
            .head = null,
            .tail = null,
            .count = 0,
            .pos = 0,
        };

        // Split the list into two halves
        self.split(&left, &right);

        // Recursively sort both halves
        left.sort();
        right.sort();

        // Merge the sorted halves back
        self.merge(&left, &right);
    }

    /// Splits the list into two halves (internal helper for merge sort)
    fn split(self: Self, left: *LinkedList, right: *LinkedList) void {
        if (self.head == null or self.count <= 1) {
            left.head = self.head;
            left.tail = self.tail;
            left.count = self.count;
            right.head = null;
            right.tail = null;
            right.count = 0;
            return;
        }

        // Find the middle using slow/fast pointer technique
        var slow = self.head;
        var fast = self.head;
        var prev: ?*Node = null;

        while (fast != null and fast.?.next != null) {
            prev = slow;
            slow = slow.?.next;
            fast = fast.?.next.?.next;
        }

        // Split at the middle
        if (prev) |p| {
            p.next = null;
        }
        if (slow) |s| {
            s.prev = null;
        }

        // Set up left half
        left.head = self.head;
        left.tail = prev;
        left.count = @divTrunc(self.count, 2);

        // Set up right half
        right.head = slow;
        right.tail = self.tail;
        right.count = self.count - left.count;
    }

    /// Merges two sorted lists (internal helper for merge sort)
    fn merge(self: Self, left: *LinkedList, right: *LinkedList) void {
        self.head = null;
        self.tail = null;
        self.count = 0;

        var currentLeft = left.head;
        var currentRight = right.head;

        // Merge elements in sorted order
        while (currentLeft != null and currentRight != null) {
            if (valueCompare(currentLeft.?.data, currentRight.?.data) < 0) {
                self.pushNode(currentLeft.?);
                currentLeft = currentLeft.?.next;
            } else {
                self.pushNode(currentRight.?);
                currentRight = currentRight.?.next;
            }
        }

        // Add remaining elements from left
        while (currentLeft != null) {
            self.pushNode(currentLeft.?);
            currentLeft = currentLeft.?.next;
        }

        // Add remaining elements from right
        while (currentRight != null) {
            self.pushNode(currentRight.?);
            currentRight = currentRight.?.next;
        }
    }

    /// Helper function to push an existing node's value
    fn pushNode(self: Self, node: *Node) void {
        self.push(node.data);
    }

    /// Creates a slice of the list from start to end (exclusive)
    pub fn slice(self: Self, start: i32, end: i32) Self {
        const sliced = LinkedList.init();
        var current = self.head;
        var index: i32 = 0;

        while (current) |node| {
            if (index >= start and index < end) {
                sliced.push(node.data);
            }
            current = node.next;
            index += 1;
        }

        return sliced;
    }

    /// Removes and returns elements from start to end (exclusive)
    pub fn splice(self: Self, start: i32, end: i32) Self {
        const spliced = LinkedList.init();
        var current = self.head;
        var index: i32 = 0;

        while (current) |node| {
            const next = node.next;

            if (index >= start and index < end) {
                // Add to spliced list
                spliced.push(node.data);

                // Remove from original list
                if (node.prev) |prev| {
                    prev.next = node.next;
                } else {
                    self.head = node.next;
                }

                if (node.next) |n| {
                    n.prev = node.prev;
                } else {
                    self.tail = node.prev;
                }

                self.count -= 1;
                _ = reallocate(@as(?*anyopaque, @ptrCast(node)), @sizeOf(Node), 0);
            }

            current = next;
            index += 1;
        }

        return spliced;
    }

    pub fn merge_lists(self: Self, other: Self) Self {
        var current = other.head;
        while (current) |node| {
            self.push(node.data);
            current = node.next;
        }
        return self;
    }
};
