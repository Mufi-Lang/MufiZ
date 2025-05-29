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
const TABLE_MIN_CAPACITY: i32 = 8;

pub const Table = struct {
    count: usize,
    capacity: usize,
    entries: ?[*]Entry,
    
    pub fn init() Table {
        return Table{
            .count = 0,
            .capacity = 0,
            .entries = null,
        };
    }
    
    pub fn deinit(self: *Table) void {
        freeTable(self);
    }
    
    pub fn isEmpty(self: *const Table) bool {
        return self.count == 0;
    }
    
    pub fn loadFactor(self: *const Table) f64 {
        if (self.capacity == 0) return 0.0;
        return @as(f64, @floatFromInt(self.count)) / @as(f64, @floatFromInt(self.capacity));
    }
};

pub const Entry = struct {
    key: ?*ObjString,
    value: Value,
    deleted: bool,
    
    pub fn init() Entry {
        return Entry{
            .key = null,
            .value = .{ .type = .VAL_NIL, .as = .{ .num_int = 0 } },
            .deleted = false,
        };
    }
    
    pub fn isEmpty(self: *const Entry) bool {
        return self.key == null and !self.deleted;
    }
    
    pub fn isTombstone(self: *const Entry) bool {
        return self.key == null and self.deleted;
    }
    
    pub fn isActive(self: *const Entry) bool {
        return self.key != null and !self.deleted;
    }
};

pub fn initTable(table: *Table) void {
    table.* = Table.init();
}

pub fn freeTable(table: *Table) void {
    if (table.entries) |entries| {
        _ = reallocate(@ptrCast(entries), @intCast(@sizeOf(Entry) * table.capacity), 0);
    }
    table.* = Table.init();
}

fn nextPowerOfTwo(n: usize) usize {
    if (n == 0) return 1;
    var power: usize = 1;
    while (power < n) {
        power <<= 1;
    }
    return power;
}

fn isValidCapacity(capacity: i32) bool {
    return capacity > 0 and (capacity & (capacity - 1)) == 0; // Must be power of 2
}

fn hash1(hash: u64, capacity: usize) usize {
    return @as(usize, @intCast(hash)) & (capacity - 1);
}

fn hash2(hash: u64) usize {
    // Secondary hash for double hashing - must be odd
    return (@as(usize, @intCast(hash)) >> 16) | 1;
}

pub fn findEntry(entries: [*]Entry, capacity: i32, key: ?*ObjString) ?*Entry {
    if (capacity <= 0 or key == null or !isValidCapacity(capacity)) {
        return null;
    }

    const cap = @as(usize, @intCast(capacity));
    var index = hash1(key.?.hash, cap);
    const step = hash2(key.?.hash);
    var firstTombstone: ?*Entry = null;
    var probeCount: usize = 0;

    while (probeCount < cap) {
        const entry = &entries[index];

        if (entry.isEmpty()) {
            return if (firstTombstone) |tombstone| tombstone else entry;
        } else if (entry.isTombstone()) {
            if (firstTombstone == null) {
                firstTombstone = entry;
            }
        } else if (entry.key == key) {
            return entry;
        }

        index = (index + step) & (cap - 1);
        probeCount += 1;
    }

    return firstTombstone;
}

pub fn tableGet(table: *Table, key: ?*ObjString, value: *Value) bool {
    if (table.isEmpty() or key == null or table.entries == null) {
        return false;
    }

    const entry = findEntry(table.entries.?, @intCast(table.capacity), key) orelse return false;
    
    if (!entry.isActive()) {
        return false;
    }

    value.* = entry.value;
    return true;
}

fn adjustCapacity(table: *Table, new_capacity: i32) void {
    if (!isValidCapacity(new_capacity)) {
        return;
    }
    
    const capacity = @as(usize, @intCast(new_capacity));
    const new_size = capacity * @sizeOf(Entry);
    const entries_ptr = reallocate(null, 0, new_size);
    const new_entries: [*]Entry = @ptrCast(@alignCast(entries_ptr));

    // Initialize all entries
    for (0..capacity) |i| {
        new_entries[i] = Entry.init();
    }

    // Save old entries for rehashing
    const old_entries = table.entries;
    const old_capacity = table.capacity;

    // Update table with new entries
    table.entries = new_entries;
    table.capacity = capacity;
    table.count = 0;

    // Rehash existing entries
    if (old_entries) |entries| {
        for (0..old_capacity) |i| {
            const entry = &entries[i];
            if (entry.isActive()) {
                _ = tableSet(table, entry.key, entry.value);
            }
        }
        // Free old entries
        _ = reallocate(@ptrCast(@alignCast(entries)), @intCast(old_capacity * @sizeOf(Entry)), 0);
    }
}

pub fn tableSet(table: *Table, key: ?*ObjString, value: Value) bool {
    if (key == null) return false;

    // Check if we need to resize
    if (table.loadFactor() > TABLE_MAX_LOAD) {
        const new_capacity = @max(TABLE_MIN_CAPACITY, @as(i32, @intCast(nextPowerOfTwo(table.capacity * 2))));
        adjustCapacity(table, new_capacity);
    }

    // Ensure we have entries array
    if (table.entries == null) {
        adjustCapacity(table, TABLE_MIN_CAPACITY);
    }

    const entry = findEntry(table.entries.?, @intCast(table.capacity), key) orelse return false;
    
    const is_new_key = !entry.isActive();
    
    if (is_new_key) {
        table.count += 1;
    }

    entry.key = key;
    entry.value = value;
    entry.deleted = false;
    
    return is_new_key;
}

pub fn tableDelete(table: *Table, key: ?*ObjString) bool {
    if (table.isEmpty() or key == null or table.entries == null) {
        return false;
    }

    const entry = findEntry(table.entries.?, @intCast(table.capacity), key) orelse return false;
    
    if (!entry.isActive()) {
        return false;
    }

    // Mark as tombstone
    entry.key = null;
    entry.deleted = true;
    
    return true;
}

pub fn tableAddAll(from: *Table, to: *Table) void {
    if (from.entries == null or from.isEmpty()) return;

    for (0..from.capacity) |i| {
        const entry = &from.entries.?[i];
        if (entry.isActive()) {
            _ = tableSet(to, entry.key, entry.value);
        }
    }
}

pub fn tableFindString(table: *Table, chars: [*]const u8, length: usize, hash: u64) ?*ObjString {
    if (table.isEmpty() or table.entries == null) return null;

    const cap = table.capacity;
    var index = hash1(hash, cap);
    const step = hash2(hash);
    var probeCount: usize = 0;

    while (probeCount < cap) {
        const entry = &table.entries.?[index];

        if (entry.isEmpty()) {
            return null;
        } else if (entry.isActive()) {
            const key = entry.key.?;
            if (key.length == length and key.hash == hash) {
                if (memcmp(@ptrCast(key.chars), @ptrCast(chars), @intCast(length)) == 0) {
                    return key;
                }
            }
        }

        index = (index + step) & (cap - 1);
        probeCount += 1;
    }
    
    return null;
}

pub fn tableRemoveWhite(table: *Table) void {
    if (table.entries == null) return;

    for (0..table.capacity) |i| {
        const entry = &table.entries.?[i];
        if (entry.isActive() and !entry.key.?.obj.isMarked) {
            _ = tableDelete(table, entry.key);
        }
    }
}

inline fn markValue(value: Value) void {
    if (value.is_obj()) markObject(@ptrCast(@alignCast(value.as_obj())));
}

pub fn markTable(table: *Table) void {
    if (table.entries == null) return;

    for (0..table.capacity) |i| {
        const entry = &table.entries.?[i];
        if (entry.key) |key| {
            markObject(@ptrCast(key));
        }
        markValue(entry.value);
    }
}

// Additional utility functions for debugging and statistics
pub fn tableStats(table: *Table) struct { count: usize, capacity: usize, load_factor: f64, tombstones: usize } {
    var tombstones: usize = 0;
    
    if (table.entries) |entries| {
        for (0..table.capacity) |i| {
            if (entries[i].isTombstone()) {
                tombstones += 1;
            }
        }
    }
    
    return .{
        .count = table.count,
        .capacity = table.capacity,
        .load_factor = table.loadFactor(),
        .tombstones = tombstones,
    };
}

pub fn tableContains(table: *Table, key: ?*ObjString) bool {
    var dummy_value: Value = undefined;
    return tableGet(table, key, &dummy_value);
}