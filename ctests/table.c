#include <stdlib.h>
#include <string.h>

#include "../include/memory.h"
#include "../include/object.h"
#include "../include/table.h"
#include "../include/value.h"

#define TABLE_MAX_LOAD 0.75

void initTable(struct Table *table)
{
    table->count = 0;
    table->capacity = 0;
    table->entries = NULL;
}
void freeTable(struct Table *table)
{
    FREE_ARRAY(struct Entry, table->entries, table->capacity);
    initTable(table);
}

struct Entry *findEntry(struct Entry *entries, int capacity,
                               ObjString *key)
{
    uint32_t index = key->hash % capacity;
    for (;;)
    {
        struct Entry *entry = &entries[index];

        if (entry->key == NULL || entry->deleted)
        {
            // empty or deleted entry
            return entry;
        }
        else if (entry->key == key)
        {
            // Found the key
            return entry;
        }

        index = (index + 1) % capacity;
    }
}

bool tableGet(struct Table *table, ObjString *key, Value *value)
{
    if (table->count == 0)
        return false;

    struct Entry *entry = findEntry(table->entries, table->capacity, key);
    if (entry->key == NULL || entry->deleted)
        return false;

    *value = entry->value;
    return true;
}

void adjustCapacity(struct Table *table, int capacity)
{
    struct Entry *entries = ALLOCATE(struct Entry, capacity);
    for (int i = 0; i < capacity; i++)
    {
        entries[i].key = NULL;
        entries[i].value = NIL_VAL;
    }

    table->count = 0;
    for (int i = 0; i < table->capacity; i++)
    {
        struct Entry *entry = &table->entries[i];
        if (entry->key == NULL)
            continue;

        struct Entry *dest = findEntry(entries, capacity, entry->key);
        dest->key = entry->key;
        dest->value = entry->value;
        table->count++;
    }

    FREE_ARRAY(struct Entry, table->entries, table->capacity);
    table->entries = entries;
    table->capacity = capacity;
}

bool tableSet(struct Table *table, ObjString *key, Value value)
{
    if (table->count + 1 > table->capacity * TABLE_MAX_LOAD)
    {
        int capacity = GROW_CAPACITY(table->capacity);
        adjustCapacity(table, capacity);
    }

    struct Entry *entry = findEntry(table->entries, table->capacity, key);
    bool isNewKey = entry->key == NULL || entry->deleted;
    if (isNewKey && IS_NIL(entry->value))
    {
        // If the entry is either empty or deleted, and its value is NIL, it's available for insertion.
        if (entry->deleted)
            entry->deleted = false; // Reusing a deleted entry.
        else
            table->count++; // Increment count only for new key insertion, not for reusing a deleted one.
    }

    entry->key = key;
    entry->value = value;
    entry->deleted = false; // Ensure deleted flag is reset.

    return isNewKey;
}

bool tableDelete(struct Table *table, ObjString *key)
{
    if (table->count == 0)
        return false;

    // Find the entry.
    struct Entry *entry = findEntry(table->entries, table->capacity, key);
    if (entry->key == NULL || entry->deleted)
        return false; // empty or already deleted

    entry->deleted = true;
    return true;
}

void tableAddAll(struct Table *from, struct Table *to)
{
    for (int i = 0; i < from->capacity; i++)
    {
        struct Entry *entry = &from->entries[i];
        if (entry->key != NULL)
        {
            tableSet(to, entry->key, entry->value);
        }
    }
}

ObjString *tableFindString(struct Table *table, const char *chars,
                           int length, uint64_t hash)
{
    if (table->count == 0)
        return NULL;

    uint64_t index = hash % table->capacity;
    for (;;)
    {
        struct Entry *entry = &table->entries[index];

        if (entry->key == NULL)
        {
            // Stop if we find an empty entry.
            if (IS_NIL(entry->value))
                return NULL;
        }
        else if (!entry->deleted && entry->key->length == length &&
                 entry->key->hash == hash &&
                 memcmp(entry->key->chars, chars, length) == 0)
        {
            // We found it.
            return entry->key;
        }

        index = (index + 1) % table->capacity;
    }
}

void tableRemoveWhite(struct Table *table)
{
    for (int i = 0; i < table->capacity; i++)
    {
        struct Entry *entry = &table->entries[i];
        if (entry->key != NULL && !entry->key->obj.isMarked)
        {
            tableDelete(table, entry->key);
        }
    }
}

void markTable(struct Table *table)
{
    for (int i = 0; i < table->capacity; i++)
    {
        struct Entry *entry = &table->entries[i];
        markObject((Obj *)entry->key);
        markValue(entry->value);
    }
}