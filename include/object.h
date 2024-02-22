/* 
 * File:   object.h
 * Author: Mustafif Khan
 * Brief:  Object Values in Mufi
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_object_h
#define mufi_object_h

#include "common.h"
#include "chunk.h"
#include "value.h"
#include "table.h"

#define OBJ_TYPE(value)        (AS_OBJ(value)->type)

#define IS_BOUND_METHOD(value)  isObjType(value, OBJ_BOUND_METHOD)
#define IS_CLASS(value)        isObjType(value, OBJ_CLASS)
#define IS_CLOSURE(value)      isObjType(value, OBJ_CLOSURE)
#define IS_FUNCTION(value)     isObjType(value, OBJ_FUNCTION)
#define IS_INSTANCE(value)     isObjType(value, OBJ_INSTANCE)
#define IS_NATIVE(value)       isObjType(value, OBJ_NATIVE)
#define IS_STRING(value)       isObjType(value, OBJ_STRING)
#define IS_ARRAY(value)        isObjType(value, OBJ_ARRAY)
#define IS_LINKED_LIST(value)  isObjType(value, OBJ_LINKED_LIST)
#define IS_HASH_TABLE(value)   isObjType(value, OBJ_HASH_TABLE)

#define AS_BOUND_METHOD(value)  ((ObjBoundMethod*)AS_OBJ(value))
#define AS_CLASS(value)        ((ObjClass*)AS_OBJ(value))
#define AS_CLOSURE(value)      ((ObjClosure*)AS_OBJ(value))
#define AS_FUNCTION(value)     ((ObjFunction*)AS_OBJ(value))
#define AS_INSTANCE(value)     ((ObjInstance*)AS_OBJ(value))
#define AS_NATIVE(value) \
    (((ObjNative*)AS_OBJ(value))->function)
#define AS_STRING(value)       ((ObjString*)AS_OBJ(value))
#define AS_CSTRING(value)      (((ObjString*)AS_OBJ(value))->chars)
#define AS_ARRAY(value)        ((ObjArray*)AS_OBJ(value))
#define AS_LINKED_LIST(value)  ((ObjLinkedList*)AS_OBJ(value))
#define AS_HASH_TABLE(value)   ((ObjHashTable*)AS_OBJ(value))

typedef enum {
    OBJ_CLOSURE,
    OBJ_FUNCTION,
    OBJ_INSTANCE,
    OBJ_NATIVE,
    OBJ_STRING,
    OBJ_UPVALUE,
    OBJ_BOUND_METHOD,
    OBJ_CLASS,
    OBJ_ARRAY, 
    OBJ_LINKED_LIST, 
    OBJ_HASH_TABLE
} ObjType;

struct Obj {
    ObjType type;
    bool isMarked;
    struct Obj* next;
};

struct Node{
    Value data;
    struct Node* prev;
    struct Node* next;
};

typedef struct
{
    Obj obj;
    struct Node* head;
    struct Node* tail;
    int count;
}ObjLinkedList;

typedef struct
{
    Obj obj;
    struct Table table;
}ObjHashTable;


typedef struct{
    Obj obj;
    int capacity;
    int count;
    Value* values;
}ObjArray;

typedef struct {
    Obj obj;
    int arity;
    int upvalueCount;
    Chunk chunk;
    ObjString* name;
} ObjFunction;

typedef Value (*NativeFn)(int argCount, Value* args);

typedef struct {
    Obj obj;
    NativeFn function;
} ObjNative;

struct ObjString {
    Obj obj;
    int length;
    char* chars;
    uint64_t hash;
};

typedef struct ObjUpvalue{
    Obj obj;
    Value* location;
    Value closed;
    struct ObjUpvalue* next;
}ObjUpvalue;

typedef struct {
    Obj obj;
    ObjFunction* function;
    ObjUpvalue** upvalues;
    int upvalueCount;
}ObjClosure;

typedef struct{
    Obj obj;
    ObjString* name;
    struct Table methods;
}ObjClass;

typedef struct {
    Obj obj;
    ObjClass* klass;
    struct Table fields;
} ObjInstance;

typedef struct {
    Obj obj;
    Value receiver;
    ObjClosure* method;
} ObjBoundMethod;

ObjBoundMethod* newBoundMethod(Value receiver, ObjClosure* method);
ObjClass* newClass(ObjString* name);
ObjClosure* newClosure(ObjFunction* function);
ObjFunction* newFunction();
ObjInstance* newInstance(ObjClass* klass);
ObjNative* newNative(NativeFn function);
ObjString* allocateString(char* chars, int length, uint64_t hash);
uint64_t hashString(const char* key, int length);
ObjString* takeString(char* chars, int length);
ObjString* copyString(const char* chars, int length);
ObjUpvalue* newUpvalue(Value* slot);

ObjArray* newArray();
ObjArray* newArrayWithCap(int capacity);
ObjArray* mergeArrays(ObjArray* a, ObjArray* b);
void pushArray(ObjArray* array, Value value);
Value popArray(ObjArray* array);
void sortArray(ObjArray* array);
int searchArray(ObjArray* array, Value value);
void reverseArray(ObjArray* array);
bool equalArray(ObjArray* a, ObjArray* b);
void freeObjectArray(ObjArray* array);

ObjLinkedList* newLinkedList();
void pushFront(ObjLinkedList* list, Value value);
void pushBack(ObjLinkedList* list, Value value);
Value popFront(ObjLinkedList* list);
Value popBack(ObjLinkedList* list);
bool equalLinkedList(ObjLinkedList* a, ObjLinkedList* b);
void freeObjectLinkedList(ObjLinkedList* list);
void mergeSort(ObjLinkedList* list);
int searchLinkedList(ObjLinkedList* list, Value value);
void reverseLinkedList(ObjLinkedList* list);

ObjHashTable* newHashTable();
bool putHashTable(ObjHashTable* table, ObjString* key, Value value);
Value getHashTable(ObjHashTable* table, ObjString* key);
bool removeHashTable(ObjHashTable* table, ObjString* key);
void freeObjectHashTable(ObjHashTable* table);

void printObject(Value value);

static inline bool isObjType(Value value, ObjType type) {
    return IS_OBJ(value) && AS_OBJ(value)->type == type;
}

#endif