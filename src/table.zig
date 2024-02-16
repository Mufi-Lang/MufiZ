const value_h = @cImport(@cInclude("value.h"));
const Value = value_h.Value;
const ObjString = @cImport(@cInclude("object.h")).ObjString;
const memory = @cImport(@cInclude("memory.h"));
const table_h = @cImport(@cInclude("table.h"));
const reallocate = memory.reallocate;
const VAL_NIL: c_int = 1;
pub const Table = extern struct {
    count: c_int,
    capacity: c_int,
    entries: [*c]Entry,
};

pub const Entry = extern struct {
    key: ?*ObjString,
    value: Value,
};

// //> Create an empty table
// void initTable(struct Table* table);
// //> Frees a table
// void freeTable(struct Table* table);
// //> Finds entry with a given key
// //> If an entry is found, return true, if not false
// bool tableGet(struct Table* table, ObjString* key, Value* value);
// //> Sets a new value into an entry inside the table using a key
// //> Returns true if the entry is added
// bool tableSet(struct Table* table, ObjString* key, Value value);
// //> Removes an entry and adds a tombstone
// bool tableDelete(struct Table* table, ObjString* key);
// //> Copies all hash entries from one table to the other
// void tableAddAll(struct Table* from, struct Table* to);
// //> Finds a specified string inside a table
// ObjString* tableFindString(struct Table* table, const char* chars, int length, uint64_t hash);
// //> Removes the white objects in a table
// void tableRemoveWhite(struct Table* table);
// //> Marks all entries inside a table
// void markTable(struct Table* table);

const TABLE_MAX_LOAD: f64 = 0.75;

pub export fn initTable(table: *Table) callconv(.C) void {
    table.count = 0;
    table.capacity = 0;
    table.entries = null;
}

pub export fn freeTable(table: *Table) callconv(.C) void {
    _ = memory.FREE_ARRAY(Entry, table.entries, @as(usize, @intCast(table.capacity)));
    initTable(table);
}

pub export fn findEntry(entries: [*]Entry, capacity: c_int, key: ?*ObjString) callconv(.C) *Entry {
    var index: usize = @as(usize, @as(usize, @intCast(key.?.hash)) & @as(usize, @intCast((capacity - 1))));
    var tombstone: ?*Entry = null;

    while (true) {
        var entry: *Entry = &entries[index];
        if (entry.*.key == null) {
            if (value_h.IS_NIL(entry.*.value)) {
                if (tombstone != null) return tombstone.? else return entry;
            } else {
                if (tombstone == null) tombstone = entry;
            }
        } else if (entry.*.key == key) {
            return entry;
        }
        index = (index + 1) & @as(usize, @intCast(capacity - 1));
    }
}

pub export fn tableGet(table: *Table, key: ?*ObjString, value: *Value) callconv(.C) bool {
    if (table.count == 0) return false;
    var entry = findEntry(table.entries, table.capacity, key);
    if (entry.*.key == null) return false;

    value.* = entry.value;
    return true;
}

pub export fn adjustCapacity(arg_table: [*c]Table, arg_capacity: c_int) callconv(.C) void {
    var table = arg_table;
    var capacity = arg_capacity;
    var entries: [*c]Entry = @as([*c]Entry, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(c_longlong, @as(c_int, 0)))), @sizeOf(Entry) *% @as(c_ulonglong, @bitCast(@as(c_longlong, capacity)))))));
    {
        var i: c_int = 0;
        while (i < capacity) : (i += 1) {
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.key = null;
            (blk: {
                const tmp = i;
                if (tmp >= 0) break :blk entries + @as(usize, @intCast(tmp)) else break :blk entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*.value = Value{
                .type = @as(c_uint, @bitCast(VAL_NIL)),
                .as = .{
                    .num_int = @as(c_int, 0),
                },
            };
        }
    }
    table.*.count = 0;
    {
        var i: c_int = 0;
        while (i < table.*.capacity) : (i += 1) {
            var entry: [*c]Entry = &(blk: {
                const tmp = i;
                if (tmp >= 0) break :blk table.*.entries + @as(usize, @intCast(tmp)) else break :blk table.*.entries - ~@as(usize, @bitCast(@as(isize, @intCast(tmp)) +% -1));
            }).*;
            if (entry.*.key == @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) continue;
            var dest: [*c]Entry = findEntry(entries, capacity, entry.*.key);
            dest.*.key = entry.*.key;
            dest.*.value = entry.*.value;
            table.*.count += 1;
        }
    }
    _ = reallocate(@as(?*anyopaque, @ptrCast(table.*.entries)), @sizeOf(Entry) *% @as(c_ulonglong, @bitCast(@as(c_longlong, table.*.capacity))), @as(usize, @bitCast(@as(c_longlong, @as(c_int, 0)))));
    table.*.entries = entries;
    table.*.capacity = capacity;
}
