const std = @import("std");

const reallocate = @import("../memory.zig").reallocate;
const allocateObject = @import("../object.zig").allocateObject;
const ObjString = @import("../object.zig").ObjString;
const ObjClass = @import("../object.zig").ObjClass;
const table_h = @import("../table.zig");
const Table = table_h.Table;
const Value = @import("../value.zig").Value;
const LinkedList = @import("linked_list.zig").LinkedList;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

/// Instance struct with bounded methods
pub const Instance = struct {
    obj: Obj,
    klass: *ObjClass,
    fields: Table,

    const Self = *@This();

    /// Creates a new instance of the given class
    pub fn init(klass: *ObjClass) Self {
        const instance: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Instance), .OBJ_INSTANCE)));
        instance.klass = klass;
        table_h.initTable(&instance.fields);
        return instance;
    }

    /// Creates a new instance (alias for init)
    pub fn new(klass: *ObjClass) Self {
        return Instance.init(klass);
    }

    /// Frees the instance
    pub fn deinit(self: Self) void {
        table_h.freeTable(&self.fields);
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(Instance), 0);
    }

    /// Sets a field value
    pub fn setField(self: Self, name: *ObjString, value: Value) bool {
        return table_h.tableSet(&self.fields, name, value);
    }

    /// Gets a field value
    pub fn getField(self: Self, name: *ObjString) ?Value {
        var value: Value = undefined;
        if (table_h.tableGet(&self.fields, name, &value)) {
            return value;
        }
        return null;
    }

    /// Gets a field value or returns a default
    pub fn getFieldOrDefault(self: Self, name: *ObjString, default: Value) Value {
        var value: Value = undefined;
        if (table_h.tableGet(&self.fields, name, &value)) {
            return value;
        }
        return default;
    }

    /// Checks if the instance has a field
    pub fn hasField(self: Self, name: *ObjString) bool {
        var value: Value = undefined;
        return table_h.tableGet(&self.fields, name, &value);
    }

    /// Removes a field
    pub fn removeField(self: Self, name: *ObjString) bool {
        return table_h.tableDelete(&self.fields, name);
    }

    /// Clears all fields
    pub fn clearFields(self: Self) void {
        table_h.freeTable(&self.fields);
        table_h.initTable(&self.fields);
    }

    /// Gets the number of fields
    pub fn fieldCount(self: Self) usize {
        return self.fields.count;
    }

    /// Checks if the instance has no fields
    pub fn hasNoFields(self: Self) bool {
        return self.fields.count == 0;
    }

    /// Gets the class of this instance
    pub fn getClass(self: Self) *ObjClass {
        return self.klass;
    }

    /// Checks if this instance is of a specific class
    pub fn isInstanceOf(self: Self, klass: *ObjClass) bool {
        return self.klass == klass;
    }

    /// Checks if this instance is of a class or its subclass
    pub fn isKindOf(self: Self, klass: *ObjClass) bool {
        if (self.klass == klass) return true;

        // Check if our class inherits from the given class
        var current: ?*ObjClass = self.klass.superclass;
        while (current) |superclass| {
            if (superclass == klass) return true;
            current = superclass.superclass;
        }
        return false;
    }

    /// Copies all fields to another table
    pub fn copyFieldsTo(self: Self, destination: *Table) void {
        table_h.tableAddAll(&self.fields, destination);
    }

    /// Copies all fields from another table
    pub fn copyFieldsFrom(self: Self, source: *Table) void {
        table_h.tableAddAll(source, &self.fields);
    }

    /// Creates a shallow copy of this instance
    pub fn clone(self: Self) Self {
        const newInstance = Instance.init(self.klass);
        self.copyFieldsTo(&newInstance.fields);
        return newInstance;
    }

    /// Prints the instance (for debugging)
    pub fn print(self: Self) void {
        std.debug.print("<instance of ", .{});
        for (0..self.klass.name.length) |i| {
            std.debug.print("{c}", .{self.klass.name.chars[i]});
        }
        std.debug.print(">", .{});
    }

    /// Prints the instance with its fields (for debugging)
    pub fn printWithFields(self: Self) void {
        std.debug.print("<instance of ", .{});
        for (0..self.klass.name.length) |i| {
            std.debug.print("{c}", .{self.klass.name.chars[i]});
        }
        std.debug.print(" {{", .{});

        if (self.fields.entries) |entries| {
            var first = true;
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    if (!first) std.debug.print(", ", .{});
                    first = false;

                    // Print field name
                    for (0..entries[i].key.?.length) |j| {
                        std.debug.print("{c}", .{entries[i].key.?.chars[j]});
                    }
                    std.debug.print(": ", .{});

                    // Print field value (simplified)
                    printValue(entries[i].value);
                }
            }
        }

        std.debug.print("}}>", .{});
    }

    /// Gets all field names as a list
    pub fn getFieldNames(self: Self) *LinkedList {
        const list = LinkedList.init();

        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const keyValue = Value.init_obj(@ptrCast(entries[i].key));
                    list.push(keyValue);
                }
            }
        }

        return list;
    }

    /// Gets all field values as a list
    pub fn getFieldValues(self: Self) *LinkedList {
        const list = LinkedList.init();

        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    list.push(entries[i].value);
                }
            }
        }

        return list;
    }

    /// Gets all fields as key-value pairs
    pub fn getFieldPairs(self: Self) *LinkedList {
        const ObjPair = @import("../object.zig").ObjPair;
        const list = LinkedList.init();

        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const keyValue = Value.init_obj(@ptrCast(entries[i].key));
                    const pair = ObjPair.create(keyValue, entries[i].value);
                    const pairValue = Value.init_obj(@ptrCast(pair));
                    list.push(pairValue);
                }
            }
        }

        return list;
    }

    /// Checks if two instances are equal (same object)
    pub fn equals(self: Self, other: Self) bool {
        return self == other;
    }

    /// Checks if two instances have the same fields
    pub fn fieldsEqual(self: Self, other: Self) bool {
        if (self.fields.count != other.fields.count) return false;

        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const otherValue = other.getField(entries[i].key.?);
                    if (otherValue == null) return false;
                    if (!valuesEqual(entries[i].value, otherValue.?)) return false;
                }
            }
        }

        return true;
    }

    /// Iterator for fields
    pub const FieldIterator = struct {
        table: *const Table,
        index: usize,

        pub fn next(self: *FieldIterator) ?struct { name: *ObjString, value: Value } {
            if (self.table.entries) |entries| {
                while (self.index < self.table.capacity) {
                    const i = self.index;
                    self.index += 1;

                    if (entries[i].key != null and entries[i].isActive()) {
                        return .{
                            .name = entries[i].key.?,
                            .value = entries[i].value,
                        };
                    }
                }
            }
            return null;
        }
    };

    /// Creates an iterator for fields
    pub fn fieldIterator(self: Self) FieldIterator {
        return FieldIterator{
            .table = &self.fields,
            .index = 0,
        };
    }

    /// Applies a function to each field
    pub fn foreachField(self: Self, func: fn (name: *ObjString, value: Value) void) void {
        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    func(entries[i].key.?, entries[i].value);
                }
            }
        }
    }

    /// Maps field values to create a new instance
    pub fn mapFields(self: Self, func: fn (name: *ObjString, value: Value) Value) Self {
        const newInstance = Instance.init(self.klass);

        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const newValue = func(entries[i].key.?, entries[i].value);
                    _ = newInstance.setField(entries[i].key.?, newValue);
                }
            }
        }

        return newInstance;
    }

    /// Filters fields to create a new instance
    pub fn filterFields(self: Self, predicate: fn (name: *ObjString, value: Value) bool) Self {
        const newInstance = Instance.init(self.klass);

        if (self.fields.entries) |entries| {
            for (0..@intCast(self.fields.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    if (predicate(entries[i].key.?, entries[i].value)) {
                        _ = newInstance.setField(entries[i].key.?, entries[i].value);
                    }
                }
            }
        }

        return newInstance;
    }
};

// Helper function to print a Value (simplified version)
fn printValue(value: Value) void {
    if (value.is_number()) {
        if (value.is_int()) {
            std.debug.print("{d}", .{value.as.number});
        } else {
            std.debug.print("{d:.2}", .{value.as_num_double()});
        }
    } else if (value.is_bool()) {
        std.debug.print("{}", .{value.as.boolean});
    } else if (value.is_nil()) {
        std.debug.print("nil", .{});
    } else if (value.is_obj()) {
        std.debug.print("<object>", .{});
    }
}

// Helper function for value equality
fn valuesEqual(a: Value, b: Value) bool {
    const value_h = @import("../value.zig");
    return value_h.valuesEqual(a, b);
}
