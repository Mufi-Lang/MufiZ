const object_h = @import("object.zig");
const memory = @import("memory.zig");
const value_h = @import("value.zig");

const ObjString = object_h.ObjString;
const Obj = object_h.Obj;
const Value = value_h.Value;

const reallocate = memory.reallocate;
const markObject = memory.markObject;

const VAL_NIL: c_int = 1;
const VAL_BOOL: c_int = 0;
const TABLE_MAX_LOAD: f64 = 0.75;

pub const Table = extern struct {
    count: c_int,
    capacity: c_int,
    entries: [*c]Entry,
};

pub const Entry = extern struct {
    key: ?*ObjString,
    value: Value,
    deleted: bool,
};

fn memcmp(s1: ?*const anyopaque, s2: ?*const anyopaque, n: usize) c_int {
    const str1: [*c]const u8 = @ptrCast(s1.?);
    const str2: [*c]const u8 = @ptrCast(s2.?);
    const num: usize = @intCast(n);

    for (0..num) |i| {
        if (str1[i] != str2[i]) return @intCast(str1[i] - str2[i]);
    }

    return 0;
}

pub export fn initTable(table: *Table) callconv(.C) void {
    table.count = 0;
    table.capacity = 0;
    table.entries = null;
}

pub export fn freeTable(table: *Table) callconv(.C) void {
    _ = memory.FREE_ARRAY(Entry, table.entries, @as(usize, @intCast(table.capacity))) orelse unreachable;
    initTable(table);
}

pub export fn entries_(table: *Table) [*c]Entry {
    return table.entries;
}

pub export fn findEntry(entries: [*]Entry, capacity: c_int, key: ?*ObjString) callconv(.C) *Entry {
    var index: usize = @as(usize, @intCast(key.?.hash)) & @as(usize, @intCast(capacity - 1));
    while (true) {
        const entry: *Entry = &entries[index];
        if (entry.*.key == null or entry.*.deleted) {
            return entry;
        } else if (entry.*.key == key) {
            return entry;
        }
        index = (index + 1) & @as(usize, @intCast(capacity - 1));
    }
}

pub export fn tableGet(table: *Table, key: ?*ObjString, value: *Value) callconv(.C) bool {
    if (table.count == 0) return false;
    const entry = findEntry(table.entries, table.capacity, key);
    if (entry.*.key == null or entry.*.deleted) return false;

    value.* = entry.value;
    return true;
}

pub export fn adjustCapacity(table: *Table, capacity: c_int) callconv(.C) void {
    var entries: [*c]Entry = @ptrCast(@alignCast(reallocate(null, 0, @as(usize, @intCast(@sizeOf(Entry) * capacity)))));
    const c: usize = @intCast(capacity);

    for (0..c) |i| {
        entries[i].key = null;
        entries[i].value = .{ .type = VAL_NIL, .as = .{ .num_int = 0 } };
    }
    table.*.count = 0;

    for (0..@as(usize, @intCast(table.*.capacity))) |i| {
        const entry: [*c]Entry = &table.*.entries[i];
        if (entry.*.key == null) continue;
        const dest: [*c]Entry = findEntry(entries, capacity, entry.*.key);
        dest.*.key = entry.*.key;
        dest.*.value = entry.*.value;
        table.*.count += 1;
    }
    _ = memory.FREE_ARRAY(Entry, table.entries, @as(usize, @intCast(table.*.capacity)));
    table.*.entries = entries;
    table.*.capacity = capacity;
}

pub export fn tableSet(table: *Table, key: ?*ObjString, value: Value) bool {
    if (@as(f64, @floatFromInt(table.*.count + 1)) > (@as(f64, @floatFromInt(table.*.capacity)) * TABLE_MAX_LOAD)) {
        const capacity: c_int = @max(8, table.*.capacity * 2);
        adjustCapacity(table, capacity);
    }
    const entry: [*c]Entry = findEntry(table.*.entries, table.*.capacity, key);
    const isNewKey: bool = entry.*.key == null or entry.*.deleted;
    if (isNewKey and (entry.*.value.type == VAL_NIL)) {
        if (entry.*.deleted) {
            entry.*.deleted = false; // reusing deleted entry
        } else {
            table.*.count += 1;
        }
    }
    entry.*.key = key;
    entry.*.value = value;
    entry.*.deleted = false; // ensure deleted flag is reset
    return isNewKey;
}

pub export fn tableDelete(table: *Table, key: ?*ObjString) bool {
    if (table.*.count == 0) return false;
    const entry: [*c]Entry = findEntry(table.*.entries, table.*.capacity, key);
    if (entry.*.key == null or entry.*.deleted) return false;
    entry.*.deleted = true;
    return true;
}

pub export fn tableAddAll(from: *Table, to: *Table) void {
    var i: usize = 0;
    while (i < from.*.capacity) : (i += 1) {
        const entry: [*c]Entry = &from.*.entries[i];
        if (entry.*.key != null) {
            _ = tableSet(to, entry.*.key, entry.*.value);
        }
    }
}

pub export fn tableFindString(table: *Table, chars: [*c]const u8, length: c_int, hash: u64) callconv(.C) ?*ObjString {
    if (table.*.count == 0) return null;
    var index: usize = @as(usize, @intCast(hash)) & @as(usize, @intCast(table.*.capacity - 1));
    while (true) {
        const entry: [*c]Entry = &table.*.entries[index];
        if (entry.*.key == null) {
            if (entry.*.value.type == VAL_NIL) return null;
        } else if (!entry.*.deleted and ((entry.*.key.?.length == length) and (entry.*.key.?.hash == hash)) and (memcmp(@ptrCast(entry.*.key.?.chars), @ptrCast(chars), @as(usize, @intCast(length))) == 0)) {
            return entry.*.key;
        }
        index = (index + 1) & @as(usize, @intCast(table.*.capacity - 1));
    }
    return null;
}

pub export fn tableRemoveWhite(table: *Table) callconv(.C) void {
    for (0..@as(usize, @intCast(table.*.capacity))) |i| {
        const entry: [*c]Entry = &table.*.entries[i];
        if (entry.*.key != null and !entry.*.key.?.obj.isMarked) {
            _ = tableDelete(table, entry.*.key);
        }
    }
}

inline fn markValue(value: Value) void {
    if (value_h.IS_OBJ(value)) markObject(@ptrCast(@alignCast(value_h.AS_OBJ(value))));
}

pub export fn markTable(table: *Table) void {
    for (0..@as(usize, @intCast(table.*.capacity))) |i| {
        const entry: [*c]Entry = &table.entries[i];
        markObject(@ptrCast(@alignCast(entry.*.key)));
        markValue(entry.*.value);
    }
}
