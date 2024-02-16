#include <stdlib.h>
#include <string.h>

#include "../include/memory.h"
#include "../include/object.h"
#include "../include/table.h"
#include "../include/value.h"

#define TABLE_MAX_LOAD 0.75

// void initTable(struct Table* table) {
//     table->count = 0;
//     table->capacity = 0;
//     table->entries = NULL;
// }
// void freeTable(struct Table* table) {
//     FREE_ARRAY(struct Entry, table->entries, table->capacity);
//     initTable(table);
// }

// struct Entry* findEntry(struct Entry* entries, int capacity,
//                         ObjString* key) {
//     uint32_t index = key->hash & (capacity - 1);
//     struct Entry* tombstone = NULL;

//     for (;;) {
//         struct Entry* entry = &entries[index];
//         if (entry->key == NULL) {
//             if (IS_NIL(entry->value)) {
//                 // Empty entry.
//                 return tombstone != NULL ? tombstone : entry;
//             } else {
//                 // We found a tombstone.
//                 if (tombstone == NULL) tombstone = entry;
//             }
//         } else if (entry->key == key) {
//             // We found the key.
//             return entry;
//         }

//         index = (index + 1) & (capacity - 1);
//     }
// }
// bool tableGet(struct Table* table, ObjString* key, Value* value) {
//     if (table->count == 0) return false;

//     struct Entry* entry = findEntry(table->entries, table->capacity, key);
//     if (entry->key == NULL) return false;

//     *value = entry->value;
//     return true;
// }
// static void adjustCapacity(struct Table* table, int capacity) {
//     struct Entry* entries = ALLOCATE(struct Entry, capacity);
//     for (int i = 0; i < capacity; i++) {
//         entries[i].key = NULL;
//         entries[i].value = NIL_VAL;
//     }

//     table->count = 0;
//     for (int i = 0; i < table->capacity; i++) {
//         struct Entry* entry = &table->entries[i];
//         if (entry->key == NULL) continue;

//         struct Entry* dest = findEntry(entries, capacity, entry->key);
//         dest->key = entry->key;
//         dest->value = entry->value;
//         table->count++;
//     }

//     FREE_ARRAY(struct Entry, table->entries, table->capacity);
//     table->entries = entries;
//     table->capacity = capacity;
// }
bool tableSet(struct Table* table, ObjString* key, Value value) {
    if (table->count + 1 > table->capacity * TABLE_MAX_LOAD) {
        int capacity = GROW_CAPACITY(table->capacity);
        adjustCapacity(table, capacity);
    }

    struct Entry* entry = findEntry(table->entries, table->capacity, key);
    bool isNewKey = entry->key == NULL;
    if (isNewKey && IS_NIL(entry->value)) table->count++;

    entry->key = key;
    entry->value = value;
    return isNewKey;
}
bool tableDelete(struct Table* table, ObjString* key) {
    if (table->count == 0) return false;

    // Find the entry.
    struct Entry* entry = findEntry(table->entries, table->capacity, key);
    if (entry->key == NULL) return false;

    // Place a tombstone in the entry.
    entry->key = NULL;
    entry->value = BOOL_VAL(true);
    return true;
}
void tableAddAll(struct Table* from, struct Table* to) {
    for (int i = 0; i < from->capacity; i++) {
        struct Entry* entry = &from->entries[i];
        if (entry->key != NULL) {
            tableSet(to, entry->key, entry->value);
        }
    }
}

ObjString* tableFindString(struct Table* table, const char* chars,
                           int length, uint64_t hash) {
    if (table->count == 0) return NULL;

    uint64_t index = hash & (table->capacity - 1);
    for (;;) {
        struct Entry* entry = &table->entries[index];
        if (entry->key == NULL) {
            // Stop if we find an empty non-tombstone entry.
            if (IS_NIL(entry->value)) return NULL;
        } else if (entry->key->length == length &&
                   entry->key->hash == hash &&
                   memcmp(entry->key->chars, chars, length) == 0) {
            // We found it.
            return entry->key;
        }

        index = (index + 1) & (table->capacity - 1);
    }
}

void tableRemoveWhite(struct Table* table){
    for(int i = 0; i < table->capacity; i++){
        struct Entry* entry = &table->entries[i];
        if(entry->key != NULL && !entry->key->obj.isMarked){
            tableDelete(table, entry->key);
        }
    }
}

void markTable(struct Table* table){
    for(int i = 0; i < table->capacity; i++){
        struct Entry* entry = &table->entries[i];
        markObject((Obj*)entry->key);
        markValue(entry->value);
    }
}