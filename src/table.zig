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
    key: [*c]ObjString,
    value: Value,
    deleted: bool,
};

fn memcmp(s1: ?*const anyopaque, s2: ?*const anyopaque, n: usize) c_int {
    const str1: [*c]const u8 = @ptrCast(s1.?);
    const str2: [*c]const u8 = @ptrCast(s2.?);
    const num: usize = @intCast(n);
    
    if (num == 0) return 0;
    
    const ptr1 = @as([*]const u8, @ptrCast(str1));
    const ptr2 = @as([*]const u8, @ptrCast(str2));
    var offset: usize = 0;
    
    // SIMD comparison using vector types (16 bytes at once)
    const Vec16 = @Vector(16, u8);
    while (offset + 16 <= num) {
        const v1 = @as(*align(1) const Vec16, @ptrCast(ptr1 + offset)).*;
        const v2 = @as(*align(1) const Vec16, @ptrCast(ptr2 + offset)).*;
        
        // Compare 16 bytes at once
        const mask = v1 != v2;
        if (@reduce(.Or, mask)) {
            // Find first differing byte in the SIMD vector
            inline for (0..16) |i| {
                if (mask[i]) {
                    return @intCast(ptr1[offset + i] - ptr2[offset + i]);
                }
            }
        }
        offset += 16;
    }
    
    // Process 8 bytes at a time for the remainder
    while (offset + 8 <= num) {
        const v1 = @as(*align(1) const u64, @ptrCast(ptr1 + offset)).*;
        const v2 = @as(*align(1) const u64, @ptrCast(ptr2 + offset)).*;
        if (v1 != v2) {
            // Find first differing byte
            inline for (0..8) |i| {
                const byte1 = @as(u8, @truncate(v1 >> @as(u6, @intCast(i * 8))));
                const byte2 = @as(u8, @truncate(v2 >> @as(u6, @intCast(i * 8))));
                if (byte1 != byte2) {
                    return @intCast(byte1 - byte2);
                }
            }
        }
        offset += 8;
    }
    
    // Handle remaining bytes
    while (offset < num) {
        if (ptr1[offset] != ptr2[offset]) {
            return @intCast(ptr1[offset] - ptr2[offset]);
        }
        offset += 1;
    }
    
    return 0;
}

pub export fn initTable(table: *Table) callconv(.C) void {
    table.count = 0;
    table.capacity = 0;
    table.entries = null;
}

pub export fn freeTable(table: *Table) callconv(.C) void {
    _ = reallocate(@ptrCast(@alignCast(table.entries)), @intCast(table.capacity), 0);
    initTable(table);
}

pub export fn entries_(table: *Table) [*c]Entry {
    return table.entries;
}

pub export fn findEntry(entries: [*]Entry, capacity: c_int, key: [*c]ObjString) callconv(.C) *Entry {
    var index: usize = @as(usize, @intCast(key.*.hash)) & @as(usize, @intCast(capacity - 1));
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
        entries[i].value = .{ .type = .VAL_NIL, .as = .{ .num_int = 0 } };
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
    _ = reallocate(table.*.entries, @intCast(table.*.capacity), 0);
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
    if (isNewKey and (entry.*.value.type == .VAL_NIL)) {
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
    // Early return if count is 0
    if (table.count <= 0) return null;

    // Calculate the initial index
    const cap = table.capacity;
    var index: usize = @as(usize, @intCast(hash & @as(u64, @intCast(cap -| 1))));

    // Get entries array
    const entries_ptr = table.entries;

    while (true) {
        const entry = &entries_ptr[index];
        const key = entry.key;

        // Check for empty slot
        if (key == null) {
            if (entry.value.type == .VAL_NIL) return null;
        } else if (!entry.deleted) {
            // Check string matches
            if (key.*.length == length and key.*.hash == hash) {
                // Compare contents
                if (memcmp(@ptrCast(key.*.chars), @ptrCast(chars), @intCast(length)) == 0) {
                    return key;
                }
            }
        }

        // Move to next slot
        index = (index +% 1) & @as(usize, @intCast(cap -| 1));
    }
}

pub export fn tableRemoveWhite(table: *Table) callconv(.C) void {
    for (0..@as(usize, @intCast(table.*.capacity))) |i| {
        const entry: [*c]Entry = &table.*.entries[i];
        if (entry.*.key != null and !entry.*.key.*.obj.isMarked) {
            _ = tableDelete(table, entry.*.key);
        }
    }
}

inline fn markValue(value: Value) void {
    if (value.is_obj()) markObject(@ptrCast(@alignCast(value.as_obj())));
}

pub export fn markTable(table: *Table) void {
    for (0..@as(usize, @intCast(table.*.capacity))) |i| {
        const entry: [*c]Entry = &table.entries[i];
        markObject(@ptrCast(@alignCast(entry.*.key)));
        markValue(entry.*.value);
    }
}
