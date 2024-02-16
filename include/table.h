/* 
 * File:   table.h
 * Author: Mustafif Khan
 * Brief:  Hashtable implementation using ObjString as Key, and Value as the Value
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_table_h
#define mufi_table_h

#include "common.h"
#include "value.h"

struct Entry{
    ObjString* key;
    Value value;
};

struct Table{
    int count;
    int capacity;
    struct Entry* entries;
};

//> Create an empty table
extern void initTable(struct Table* table);
//> Frees a table
extern void freeTable(struct Table* table);
extern struct Entry* findEntry(struct Entry* entries, int capacity, ObjString* key);
//> Finds entry with a given key
//> If an entry is found, return true, if not false
extern bool tableGet(struct Table* table, ObjString* key, Value* value);

extern void adjustCapacity(struct Table* table, int capacity);
//> Sets a new value into an entry inside the table using a key
//> Returns true if the entry is added
bool tableSet(struct Table* table, ObjString* key, Value value);
//> Removes an entry and adds a tombstone
bool tableDelete(struct Table* table, ObjString* key);
//> Copies all hash entries from one table to the other
void tableAddAll(struct Table* from, struct Table* to);
//> Finds a specified string inside a table
ObjString* tableFindString(struct Table* table, const char* chars, int length, uint64_t hash);
//> Removes the white objects in a table
void tableRemoveWhite(struct Table* table);
//> Marks all entries inside a table
void markTable(struct Table* table);
#endif
