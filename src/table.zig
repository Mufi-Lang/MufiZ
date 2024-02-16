const value_h = @cImport(@cInclude("value.h"));
const Value = value_h.Value;
const ObjString = @cImport(@cInclude("object.h")).ObjString;
const memory = @cImport(@cInclude("memory.h"));

pub const Table = extern struct {
    count: usize,
    capacity: usize,
    entries: [*c]Entry,
};

pub const Entry = extern struct {
    key: [*c]ObjString,
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

pub export fn initTable(table: *Table) void {
    table.count = 0;
    table.capacity = 0;
    table.entries = null;
}

pub export fn freeTable(table: *Table) void {
    _ = memory.FREE_ARRAY(Entry, table.entries, table.capacity);
    initTable(table);
}

