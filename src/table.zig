const object_h = @import("object.zig");
const memory = @import("memory.zig");
const value_h = @import("value.zig");
const memcmp = @import("mem_utils.zig").memcmp;
const std = @import("std");

const ObjString = object_h.ObjString;
const Obj = object_h.Obj;
const Value = value_h.Value;

const reallocate = memory.reallocate;
const markObject = memory.markObject;

const VAL_NIL: i32 = 1;
const VAL_BOOL: i32 = 0;
const TABLE_MAX_LOAD: f64 = 0.75;

pub const Table =  struct {
    count: usize,
    capacity: usize,
    entries: ?[*]Entry,
};

pub const Entry =  struct {
    key: ?*ObjString,
    value: Value,
    deleted: bool,
};

pub fn initTable(table: *Table) void {
    table.count = 0;
    table.capacity = 0;
    table.entries = null;
}

pub fn freeTable(table: *Table) void {
    if (table.entries) |entries| {
        _ = reallocate(@ptrCast(entries), @intCast(@sizeOf(Entry) * table.capacity), 0);
    }
    initTable(table);
}

pub fn entries_(table: *Table) [*]Entry {
    return table.entries orelse unreachable;
}

pub fn findEntry(entries: [*]Entry, capacity: i32, key: ?*ObjString) ?*Entry {
    // Check for empty table or null key
    if (capacity <= 0 or key == null) {
        return null;
    }

    const mask = capacity - 1;
    var index: usize = @as(usize, @intCast(key.?.hash)) & @as(usize, @intCast(mask));
    var firstTombstone: ?*Entry = null;

    // Track initial index to detect full table traversal
    const startIndex = index;

    while (true) {
        if (index >= @as(usize, @intCast(capacity))) {
            // Safety check to avoid out-of-bounds access
            return if (firstTombstone) |tombstone| tombstone else null;
        }

        const entry: *Entry = @ptrCast(&entries[index]);

        if (entry.key == null) {
            // Empty entry (either never used or a tombstone)
            if (entry.deleted) {
                // This is a tombstone - mark it as candidate if first seen
                if (firstTombstone == null) {
                    firstTombstone = entry;
                }
            } else {
                // If we found a tombstone, return that instead for insertion
                return if (firstTombstone) |tombstone| tombstone else entry;
            }
        } else if (entry.key == key) {
            // Found the key
            return entry;
        }

        // Linear probe
        index = (index + 1) & @as(usize, @intCast(mask));

        // Check if we've searched the whole table
        if (index == startIndex) {
            // If we've searched the whole table and found no empty spots,
            // return the first tombstone if found, or just the first entry
            return if (firstTombstone) |tombstone| tombstone else &entries[0];
        }
    }
}

pub fn tableGet(table: *Table, key: ?*ObjString, value: *Value) bool {
    if (table.count == 0 or key == null) return false;
    if (table.entries == null or table.capacity <= 0) return false;

    if (table.entries) |entries| {
        const entry = findEntry(entries, @intCast(table.capacity), key);
        // Check for null entry (could happen if findEntry fails)
        if (entry == null) return false;

        if (entry.?.key == null or entry.?.deleted) return false;
        value.* = entry.?.value;
        return true;
    } else {
        return false;
    }
}

pub fn adjustCapacity(table: *Table, capacity: i32) void {
    const new_size = @as(usize, @intCast(capacity)) * @sizeOf(Entry);
    const entries_ptr = reallocate(null, 0, new_size);
    const entries: [*]Entry = @ptrCast(@alignCast(entries_ptr));

    for (0..@intCast(capacity)) |i| {
        entries[i].key = null;
        entries[i].value = .{ .type = .VAL_NIL, .as = .{ .num_int = 0 } };
        entries[i].deleted = false;
    }
    table.count = 0;
    // Copy all entries to new table
    if (table.entries != null) {
        for (0..@intCast(table.capacity)) |i| {
            const entry = &table.entries.?[i];
            if (entry.key == null) continue;
            const dest = findEntry(entries, capacity, entry.key);
            if (dest) |d| {
                d.key = entry.key;
                d.value = entry.value;
                d.deleted = false;
                table.count += 1;
            }
        }
        _ = reallocate(@ptrCast(@alignCast(table.entries)), @intCast(table.capacity * @sizeOf(Entry)), 0);
    }

    table.entries = entries;
    table.capacity = @intCast(capacity);
}

pub fn tableSet(table: *Table, key: ?*ObjString, value: Value) bool {
    if (key == null) return false;

    if (@as(f64, @floatFromInt(table.count + 1)) > (@as(f64, @floatFromInt(table.capacity)) * TABLE_MAX_LOAD)) {
        const capacity: i32 = @max(8, @as(i32, @intCast(table.capacity * 2)));
        adjustCapacity(table, capacity);
    }

    if (table.entries == null) return false;

    const entry = findEntry(table.entries.?, @intCast(table.capacity), key);
    if (entry) |validEntry| {
        const isNewKey: bool = validEntry.key == null or validEntry.deleted;
        if (isNewKey and (validEntry.value.type == .VAL_NIL)) {
            if (validEntry.deleted) {
                validEntry.deleted = false; // reusing deleted entry
            } else {
                table.count += 1;
            }
        }
        validEntry.key = key;
        validEntry.value = value;
        validEntry.deleted = false; // ensure deleted flag is reset
        return isNewKey;
    }
    return false;
}

pub fn tableDelete(table: *Table, key: ?*ObjString) bool {
    if (table.count == 0) return false;
    if (table.entries == null) return false;

    if (table.entries) |entries| {
        const entry = findEntry(entries, @intCast(table.capacity), key);
        if (entry) |validEntry| {
            if (validEntry.key == null or validEntry.deleted) return false;
            validEntry.deleted = true;
            return true;
        }
    }
    return false;
}

pub fn tableAddAll(from: *Table, to: *Table) void {
    if (from.entries == null) return;

    if (from.entries) |entries| {
        var i: usize = 0;
        while (i < from.capacity) : (i += 1) {
            const entry = &entries[i];
            if (entry.key != null and !entry.deleted) {
                _ = tableSet(to, entry.key, entry.value);
            }
        }
    }
}

pub fn tableFindString(table: *Table, chars: [*]const u8, length: usize, hash: u64) ?*ObjString {
    // Early return if count is 0
    if (table.count <= 0 or table.entries == null) return null;

    // Calculate the initial index
    const cap = table.capacity;
    var index: usize = @as(usize, @intCast(hash & @as(u64, @intCast(cap -| 1))));

    // Get entries array
    if (table.entries) |entries| {
        while (true) {
            const entry = &entries[index];
            const key = entry.key;

            // Check for empty slot
            if (key == null) {
                if (entry.value.type == .VAL_NIL) return null;
            } else if (!entry.deleted) {
                // Check string matches
                if (key.?.length == length and key.?.hash == hash) {
                    // Compare contents
                    if (memcmp(@ptrCast(key.?.chars), @ptrCast(chars), @intCast(length)) == 0) {
                        return key;
                    }
                }
            }

            // Check next slot (linear probing)
            index = (index + 1) & @as(usize, @intCast(cap - 1));
        }
    }
    
    return null;
}

pub fn tableRemoveWhite(table: *Table) void {
    if (table.entries == null) return;

    for (0..@intCast(table.capacity)) |i| {
        const entry = &table.entries.?[i];
        if (entry.key != null and !entry.key.?.obj.isMarked) {
            _ = tableDelete(table, entry.key);
        }
    }
}

inline fn markValue(value: Value) void {
    if (value.is_obj()) markObject(@ptrCast(@alignCast(value.as_obj())));
}

pub fn markTable(table: *Table) void {
    if (table.entries == null) return;

    if (table.entries) |entries| {
        for (0..@intCast(table.capacity)) |i| {
            const entry = &entries[i];
            if (entry.key) |key| {
                markObject(@ptrCast(key));
            }
            markValue(entry.value);
        }
    }
}
