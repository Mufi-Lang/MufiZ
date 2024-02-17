const ObjString = @cImport(@cInclude("object.h")).ObjString;
const Obj = value_h.Obj;
const memory = @cImport(@cInclude("memory.h"));
const table_h = @cImport(@cInclude("table.h"));
const value_h = @cImport(@cInclude("value.h"));
const reallocate = memory.reallocate;
const VAL_NIL: c_int = 1;
const VAL_BOOL: c_int = 0;
const Value = value_h.Value;

pub const Table = extern struct {
    count: c_int,
    capacity: c_int,
    entries: [*c]Entry,
};

pub const Entry = extern struct {
    key: ?*ObjString,
    value: Value,
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

// TODO: Cleanup 
pub export fn adjustCapacity(arg_table: [*c]Table, arg_capacity: c_int) callconv(.C) void {
    var table = arg_table;
    var capacity = arg_capacity;
    var entries: [*c]Entry = @as([*c]Entry, @ptrCast(@alignCast(reallocate(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))), @as(usize, @bitCast(@as(usize, @as(c_int, 0)))), @sizeOf(Entry) *% @as(usize, @bitCast(@as(usize, @intCast(capacity))))))));
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
        var i: usize = 0;
        while (i < table.*.capacity) : (i += 1) {
            var entry: [*c]Entry = &table.*.entries[i];
            if (entry.*.key == null) continue;
            var dest: [*c]Entry = findEntry(entries, capacity, entry.*.key);
            dest.*.key = entry.*.key;
            dest.*.value = entry.*.value;
            table.*.count += 1;
        }
    }
    _ = reallocate(@as(?*anyopaque, @ptrCast(table.*.entries)), @sizeOf(Entry) *% @as(usize, @bitCast(@as(usize, @intCast(table.*.capacity)))), @as(usize, @bitCast(@as(usize, 0))));
    table.*.entries = entries;
    table.*.capacity = capacity;
}
// TODO: Cleanup 
pub export fn tableSet(arg_table: [*c]Table, arg_key: [*c]ObjString, arg_value: Value) bool {
    var table = arg_table;
    var key = arg_key;
    var value = arg_value;
    if (@as(f64, @floatFromInt(table.*.count + @as(c_int, 1))) > (@as(f64, @floatFromInt(table.*.capacity)) * 0.75)) {
        var capacity: c_int = if (table.*.capacity < @as(c_int, 8)) @as(c_int, 8) else table.*.capacity * @as(c_int, 2);
        adjustCapacity(table, capacity);
    }
    var entry: [*c]Entry = findEntry(table.*.entries, table.*.capacity, key);
    var isNewKey: bool = entry.*.key == @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))));
    if ((@as(c_int, @intFromBool(isNewKey)) != 0) and (entry.*.value.type == @as(c_uint, @bitCast(VAL_NIL)))) {
        table.*.count += 1;
    }
    entry.*.key = key;
    entry.*.value = value;
    return isNewKey;
}
pub export fn tableDelete(table: *Table, key: ?*ObjString) bool {
    if (table.*.count == 0) return false;
    var entry: [*c]Entry = findEntry(table.*.entries, table.*.capacity, key);
    if (entry.*.key == null) return false;
    entry.*.key = null;
    entry.*.value = Value{
        .type = VAL_BOOL,
        .as = .{
            .boolean = true,
        },
    };
    return true;
}
pub export fn tableAddAll(from: *Table, to: *Table) void {
    var i: usize = 0;
    while (i < from.*.capacity) : (i += 1) {
        var entry: [*c]Entry = &from.*.entries[i];
        if (entry.*.key != null) {
            _ = tableSet(to, entry.*.key, entry.*.value);
        }
    }
}

//TODO: Cleanup 
pub export fn tableFindString(arg_table: [*c]Table, arg_chars: [*c]const u8, arg_length: c_int, arg_hash: u64) callconv(.C) [*c]ObjString {
    var table = arg_table;
    var chars = arg_chars;
    var length = arg_length;
    var hash = arg_hash;
    if (table.*.count == @as(c_int, 0)) return null;
    var index: usize = @as(usize, @intCast(hash)) & @as(usize, @intCast(table.*.capacity - 1));
    while (true) {
        var entry: [*c]Entry = &table.*.entries[@as(usize, @intCast(index))];
        if (entry.*.key == @as([*c]ObjString, @ptrCast(@alignCast(@as(?*anyopaque, @ptrFromInt(@as(c_int, 0))))))) {
            if (entry.*.value.type == @as(c_uint, @bitCast(VAL_NIL))) return null;
        } else if (((entry.*.key.?.length == length) and (entry.*.key.?.hash == hash)) and (memcmp(@ptrCast(entry.*.key.?.chars), @ptrCast(chars), @as(usize, @intCast(length))) == 0)) {
            return entry.*.key;
        }
        index = (index + 1) & @as(usize, @intCast(table.*.capacity - 1));
    }
    return null;
}

pub export fn tableRemoveWhite(arg_table: [*c]Table) callconv(.C) void {
    var table = arg_table;
    {
        var i: usize = 0;
        while (i < table.*.capacity) : (i += 1) {
            var entry: [*c]Entry = &table.*.entries[i];
            if (entry.*.key != null and !entry.*.key.?.obj.isMarked) {
                _ = tableDelete(table, entry.*.key);
            }
        }
    }
}
