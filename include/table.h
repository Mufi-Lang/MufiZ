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


typedef struct{
    ObjString* key;
    Value value;
}Entry;

typedef struct{
    int count;
    int capacity;
    Entry* entries;
}Table;

//> Create an empty table
void initTable(Table* table);
//> Frees a table
void freeTable(Table* table);
//> Finds entry with a given key
//> If an entry is found, return true, if not false
bool tableGet(Table* table, ObjString* key, Value* value);
//> Sets a new value into an entry inside the table using a key
//> Returns true if the entry is added
bool tableSet(Table* table, ObjString* key, Value value);
//> Removes an entry and adds a tombstone
bool tableDelete(Table* table, ObjString* key);
//> Copies all hash entries from one table to the other
void tableAddAll(Table* from, Table* to);
//> Finds a specified string inside a table
ObjString* tableFindString(Table* table, const char* chars, int length, uint32_t hash);
//> Removes the white objects in a table
void tableRemoveWhite(Table* table);
//> Marks all entries inside a table
void markTable(Table* table);
#endif
