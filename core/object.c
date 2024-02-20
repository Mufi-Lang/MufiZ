#include <stdio.h>
#include <string.h>

#include "../include/object.h"
#include "../include/memory.h"
#include "../include/value.h"
#include "../include/vm.h"
#include "../include/table.h"
#include "../include/wyhash.h"

#define ALLOCATE_OBJ(type, objectType) \
    ((type *)allocateObject(sizeof(type), objectType))

static Obj *allocateObject(size_t size, ObjType type)
{
    Obj *object = (Obj *)reallocate(NULL, 0, size);
    object->type = type;
    object->isMarked = false;
    object->next = vm.objects;
    vm.objects = object;

#ifdef DEBUG_LOG_GC
    printf("%p allocate %zu for %d\n", (void *)object, size, type);
#endif

    return object;
}

ObjArray *newArray()
{
    ObjArray *array = ALLOCATE_OBJ(ObjArray, OBJ_ARRAY);
    array->capacity = 0;
    array->count = 0;
    array->values = NULL;
    return array;
}

void pushArray(ObjArray *array, Value value)
{
    if (array->capacity < array->count + 1)
    {
        int oldCapacity = array->capacity;
        array->capacity = GROW_CAPACITY(oldCapacity);
        array->values = GROW_ARRAY(Value, array->values, oldCapacity, array->capacity);
    }
    array->values[array->count++] = value;
}

Value popArray(ObjArray *array)
{
    if (array->count == 0)
    {
        return NIL_VAL;
    }
    return array->values[--array->count];
}

void freeObjectArray(ObjArray *array)
{
    FREE_ARRAY(Value, array->values, array->capacity);
    FREE(ObjArray, array);
}

ObjLinkedList *newLinkedList()
{
    ObjLinkedList *list = ALLOCATE_OBJ(ObjLinkedList, OBJ_LINKED_LIST);
    list->head = NULL;
    list->tail = NULL;
    list->count = 0;
    return list;
}

void pushFront(ObjLinkedList *list, Value value)
{
    struct Node *node = ALLOCATE(struct Node, 1);
    node->data = value;
    node->prev = NULL;
    node->next = list->head;
    if (list->head != NULL)
    {
        list->head->prev = node;
    }
    list->head = node;
    if (list->tail == NULL)
    {
        list->tail = node;
    }
    list->count++;
}
void pushBack(ObjLinkedList *list, Value value)
{
    struct Node *node = ALLOCATE(struct Node, 1);
    node->data = value;
    node->prev = list->tail;
    node->next = NULL;
    if (list->tail != NULL)
    {
        list->tail->next = node;
    }
    list->tail = node;
    if (list->head == NULL)
    {
        list->head = node;
    }
    list->count++;
}
Value popFront(ObjLinkedList *list)
{
    if (list->head == NULL)
    {
        return NIL_VAL;
    }
    struct Node *node = list->head;
    Value data = node->data;
    list->head = node->next;
    if (list->head != NULL)
    {
        list->head->prev = NULL;
    }
    if (list->tail == node)
    {
        list->tail = NULL;
    }
    list->count--;
    FREE(struct Node, node);
    return data;
}
Value popBack(ObjLinkedList *list)
{
    if (list->tail == NULL)
    {
        return NIL_VAL;
    }
    struct Node *node = list->tail;
    Value data = node->data;
    list->tail = node->prev;
    if (list->tail != NULL)
    {
        list->tail->next = NULL;
    }
    if (list->head == node)
    {
        list->head = NULL;
    }
    list->count--;
    FREE(struct Node, node);
    return data;
}
void freeObjectLinkedList(ObjLinkedList *list)
{
    struct Node *current = list->head;
    while (current != NULL)
    {
        struct Node *next = current->next;
        FREE(struct Node, current);
        current = next;
    }
    FREE(ObjLinkedList, list);
}

ObjBoundMethod *newBoundMethod(Value receiver, ObjClosure *method)
{
    ObjBoundMethod *bound = ALLOCATE_OBJ(ObjBoundMethod, OBJ_BOUND_METHOD);
    bound->receiver = receiver;
    bound->method = method;
    return bound;
}

ObjClass *newClass(ObjString *name)
{
    ObjClass *klass = ALLOCATE_OBJ(ObjClass, OBJ_CLASS);
    klass->name = name;
    initTable(&klass->methods);
    return klass;
}

ObjClosure *newClosure(ObjFunction *function)
{
    ObjUpvalue **upvalues = ALLOCATE(ObjUpvalue *, function->upvalueCount);
    for (int i = 0; i < function->upvalueCount; i++)
    {
        upvalues[i] = NULL;
    }

    ObjClosure *closure = ALLOCATE_OBJ(ObjClosure, OBJ_CLOSURE);
    closure->function = function;
    closure->upvalues = upvalues;
    closure->upvalueCount = function->upvalueCount;
    return closure;
}

ObjFunction *newFunction()
{
    ObjFunction *function = ALLOCATE_OBJ(ObjFunction, OBJ_FUNCTION);
    function->arity = 0;
    function->upvalueCount = 0;
    function->name = NULL;
    initChunk(&function->chunk);
    return function;
}

ObjInstance *newInstance(ObjClass *klass)
{
    ObjInstance *instance = ALLOCATE_OBJ(ObjInstance, OBJ_INSTANCE);
    instance->klass = klass;
    initTable(&instance->fields);
    return instance;
}

ObjNative *newNative(NativeFn function)
{
    ObjNative *native = ALLOCATE_OBJ(ObjNative, OBJ_NATIVE);
    native->function = function;
    return native;
}

ObjString *allocateString(char *chars, int length, uint64_t hash)
{
    ObjString *string = ALLOCATE_OBJ(ObjString, OBJ_STRING);
    string->length = length;
    string->chars = chars;
    string->hash = hash;
    push(OBJ_VAL(string));
    tableSet(&vm.strings, string, NIL_VAL);
    pop();
    return string;
}

// FNV-1a hashing algorithm
uint64_t hashString(const char *key, int length)
{
    uint64_t hash = 2166136261u;
    for (int i = 0; i < length; i++)
    {
        hash ^= (uint8_t)key[i];
        hash *= 16777619;
    }
    return hash;
}

ObjString *takeString(char *chars, int length)
{
    uint64_t hash = hashString(chars, length);
    ObjString *interned = tableFindString(&vm.strings, chars, length, hash);
    if (interned != NULL)
    {
        FREE_ARRAY(char, chars, length + 1);
        return interned;
    }
    return allocateString(chars, length, hash);
}

ObjString *copyString(const char *chars, int length)
{
    uint64_t hash = hashString(chars, length);
    ObjString *interned = tableFindString(&vm.strings, chars, length, hash);
    if (interned != NULL)
        return interned;
    char *heapChars = ALLOCATE(char, length + 1);
    memcpy(heapChars, chars, length);
    heapChars[length] = '\0';
    return allocateString(heapChars, length, hash);
}

ObjUpvalue *newUpvalue(Value *slot)
{
    ObjUpvalue *upvalue = ALLOCATE_OBJ(ObjUpvalue, OBJ_UPVALUE);
    upvalue->location = slot;
    upvalue->closed = NIL_VAL;
    upvalue->next = NULL;
    return upvalue;
}

static void printFunction(ObjFunction *function)
{
    if (function->name == NULL)
    {
        printf("<script>");
        return;
    }
    printf("<fn %s>", function->name->chars);
}
void printObject(Value value)
{
    switch (OBJ_TYPE(value))
    {
    case OBJ_BOUND_METHOD:
    {
        printFunction(AS_BOUND_METHOD(value)->method->function);
        break;
    }
    case OBJ_CLASS:
        printf("%s", AS_CLASS(value)->name->chars);
        break;
    case OBJ_CLOSURE:
        printFunction(AS_CLOSURE(value)->function);
        break;
    case OBJ_FUNCTION:
        printFunction(AS_FUNCTION(value));
        break;
    case OBJ_INSTANCE:
        printf("%s instance", AS_INSTANCE(value)->klass->name->chars);
        break;
    case OBJ_NATIVE:
        printf("<native fn>");
        break;
    case OBJ_STRING:
        printf("%s", AS_CSTRING(value));
        break;
    case OBJ_UPVALUE:
        printf("upvalue");
        break;
    case OBJ_ARRAY:
    {
        printf("[");
        for (int i = 0; i < AS_ARRAY(value)->count; i++)
        {
            printValue(AS_ARRAY(value)->values[i]);
            if (i != AS_ARRAY(value)->count - 1)
            {
                printf(", ");
            }
        }
        printf("]");
        break;
    }
    case OBJ_LINKED_LIST:
    {
        printf("[");
        struct Node *current = AS_LINKED_LIST(value)->head;
        while (current != NULL)
        {
            printValue(current->data);
            if (current->next != NULL)
            {
                printf(", ");
            }
            current = current->next;
        }
        printf("]");
        break;
    }
    }
}
