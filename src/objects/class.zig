const std = @import("std");

const reallocate = @import("../memory.zig").reallocate;
const allocateObject = @import("../object.zig").allocateObject;
const ObjString = @import("../object.zig").ObjString;
const ObjClosure = @import("../object.zig").ObjClosure;
const Instance = @import("../object.zig").Instance;
const LinkedList = @import("../object.zig").LinkedList;
const table_h = @import("../table.zig");
const Table = table_h.Table;
const Value = @import("../value.zig").Value;
const obj_h = @import("obj.zig");
const Obj = obj_h.Obj;

/// Class struct with bounded methods
pub const Class = struct {
    obj: Obj,
    name: *ObjString,
    methods: Table,
    superclass: ?*Class,

    const Self = *@This();

    /// Creates a new class with the given name
    pub fn init(name: *ObjString) Self {
        const klass: Self = @ptrCast(@alignCast(allocateObject(@sizeOf(Class), .OBJ_CLASS)));
        klass.name = name;
        klass.superclass = null;
        table_h.initTable(&klass.methods);
        return klass;
    }

    /// Creates a new class (alias for init)
    pub fn new(name: *ObjString) Self {
        return Class.init(name);
    }

    /// Frees the class
    pub fn deinit(self: Self) void {
        table_h.freeTable(&self.methods);
        _ = reallocate(@as(?*anyopaque, @ptrCast(self)), @sizeOf(Class), 0);
    }

    /// Adds a method to the class
    pub fn addMethod(self: Self, name: *ObjString, method: *ObjClosure) bool {
        return table_h.tableSet(&self.methods, name, Value.init_obj(@ptrCast(method)));
    }

    /// Gets a method from the class
    pub fn getMethod(self: Self, name: *ObjString) ?*ObjClosure {
        var value: Value = undefined;
        if (table_h.tableGet(&self.methods, name, &value)) {
            if (value.is_obj() and value.as.obj.?.type == .OBJ_CLOSURE) {
                return @ptrCast(@alignCast(value.as.obj));
            }
        }
        return null;
    }

    /// Checks if the class has a method
    pub fn hasMethod(self: Self, name: *ObjString) bool {
        var value: Value = undefined;
        return table_h.tableGet(&self.methods, name, &value);
    }

    /// Removes a method from the class
    pub fn removeMethod(self: Self, name: *ObjString) bool {
        return table_h.tableDelete(&self.methods, name);
    }

    /// Sets the superclass
    pub fn setSuperclass(self: Self, superclass: ?*Class) void {
        self.superclass = superclass;
    }

    /// Gets the superclass
    pub fn getSuperclass(self: Self) ?*Class {
        return self.superclass;
    }

    /// Checks if this class inherits from another class
    pub fn inheritsFrom(self: Self, other: *Class) bool {
        var current: ?*Class = self.superclass;
        while (current) |klass| {
            if (klass == other) return true;
            current = klass.superclass;
        }
        return false;
    }

    /// Finds a method in this class or its superclasses
    pub fn findMethod(self: Self, name: *ObjString) ?*ObjClosure {
        // Check this class first
        if (self.getMethod(name)) |method| {
            return method;
        }

        // Check superclasses
        var current: ?*Class = self.superclass;
        while (current) |klass| {
            if (klass.getMethod(name)) |method| {
                return method;
            }
            current = klass.superclass;
        }

        return null;
    }

    /// Copies all methods from this class to another table
    pub fn copyMethodsTo(self: Self, destination: *Table) void {
        table_h.tableAddAll(&self.methods, destination);
    }

    /// Gets the number of methods
    pub fn methodCount(self: Self) usize {
        return self.methods.count;
    }

    /// Creates an instance of this class
    pub fn createInstance(self: Self) *Instance {
        return Instance.init(self);
    }

    /// Prints the class (for debugging)
    pub fn print(self: Self) void {
        std.debug.print("<class ", .{});
        for (0..self.name.length) |i| {
            std.debug.print("{c}", .{self.name.chars[i]});
        }
        std.debug.print(">", .{});
    }

    /// Gets all method names as a list
    pub fn getMethodNames(self: Self) *LinkedList {
        const list = LinkedList.init();

        if (self.methods.entries) |entries| {
            for (0..@intCast(self.methods.capacity)) |i| {
                if (entries[i].key != null and entries[i].isActive()) {
                    const keyValue = Value.init_obj(@ptrCast(entries[i].key));
                    list.push(keyValue);
                }
            }
        }

        return list;
    }

    /// Checks if two classes are equal (same object)
    pub fn equals(self: Self, other: Self) bool {
        return self == other;
    }

    /// Gets the inheritance depth
    pub fn inheritanceDepth(self: Self) usize {
        var depth: usize = 0;
        var current: ?*Class = self.superclass;
        while (current) |klass| {
            depth += 1;
            current = klass.superclass;
        }
        return depth;
    }

    /// Gets all superclasses as a list (from immediate parent to root)
    pub fn getSuperclasses(self: Self) *LinkedList {
        const list = LinkedList.init();

        var current: ?*Class = self.superclass;
        while (current) |klass| {
            list.push(Value.init_obj(@ptrCast(klass)));
            current = klass.superclass;
        }

        return list;
    }

    /// Checks if this class or any superclass has a method
    pub fn hasMethodInHierarchy(self: Self, name: *ObjString) bool {
        return self.findMethod(name) != null;
    }

    /// Iterator for methods
    pub const MethodIterator = struct {
        table: *const Table,
        index: usize,

        pub fn next(self: *MethodIterator) ?struct { name: *ObjString, method: *ObjClosure } {
            if (self.table.entries) |entries| {
                while (self.index < self.table.capacity) {
                    const i = self.index;
                    self.index += 1;

                    if (entries[i].key != null and entries[i].isActive()) {
                        if (entries[i].value.is_obj() and entries[i].value.as.obj.?.type == .OBJ_CLOSURE) {
                            return .{
                                .name = entries[i].key.?,
                                .method = @ptrCast(@alignCast(entries[i].value.as.obj)),
                            };
                        }
                    }
                }
            }
            return null;
        }
    };

    /// Creates an iterator for methods
    pub fn methodIterator(self: Self) MethodIterator {
        return MethodIterator{
            .table = &self.methods,
            .index = 0,
        };
    }
};
