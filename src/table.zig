const value_h = @cImport(@cInclude("value.h"));
const Value = value_h.Value;
const ObjString = @cImport(@cInclude("object.h")).ObjString;
const memory = @cImport(@cInclude("memory.h"));
const table_h = @cImport(@cInclude("table.h"));

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
