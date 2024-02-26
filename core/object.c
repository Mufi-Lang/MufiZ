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

ObjArray *newArrayWithCap(int capacity)
{
    ObjArray *array = ALLOCATE_OBJ(ObjArray, OBJ_ARRAY);
    array->capacity = capacity;
    array->count = 0;
    array->values = ALLOCATE(Value, capacity);
    return array;
}

ObjArray *mergeArrays(ObjArray *a, ObjArray *b)
{
    ObjArray *newArray = newArrayWithCap(a->count + b->count);
    for (int i = 0; i < a->count; i++)
    {
        pushArray(newArray, a->values[i]);
    }
    for (int i = 0; i < b->count; i++)
    {
        pushArray(newArray, b->values[i]);
    }
    return newArray;
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

static int compareValues(const void *a, const void *b)
{
    if (IS_INT(*(Value *)a) && IS_INT(*(Value *)b))
    {
        return AS_INT(*(Value *)a) - AS_INT(*(Value *)b);
    }
    else if (IS_DOUBLE(*(Value *)a) && IS_DOUBLE(*(Value *)b))
    {
        return (int)(AS_DOUBLE(*(Value *)a) - AS_DOUBLE(*(Value *)b));
    }
    else
    {
        return 0;
    }
}

static struct Node *merge(struct Node *left, struct Node *right)
{
    if (left == NULL)
        return right;
    if (right == NULL)
        return left;
    if (valueCompare(left->data, right->data) < 0)
    {
        left->next = merge(left->next, right);
        left->next->prev = left;
        left->prev = NULL;
        return left;
    }
    else
    {
        right->next = merge(left, right->next);
        right->next->prev = right;
        right->prev = NULL;
        return right;
    }
}

static void split(ObjLinkedList *list, ObjLinkedList *left, ObjLinkedList *right)
{
    int count = list->count;
    int middle = count / 2;

    left->head = list->head;
    left->count = middle;
    right->count = count - middle;

    struct Node *current = list->head;
    for (int i = 0; i < middle - 1; ++i)
    {
        current = current->next;
    }

    left->tail = current;
    right->head = current->next;
    current->next = NULL;
    right->head->prev = NULL;
}

void mergeSort(ObjLinkedList *list)
{
    if (list->count < 2)
    {
        return;
    }

    ObjLinkedList left, right;
    split(list, &left, &right);

    mergeSort(&left);
    mergeSort(&right);

    list->head = merge(left.head, right.head);

    struct Node *current = list->head;
    while (current->next != NULL)
    {
        current = current->next;
    }
    list->tail = current;
}

void sortArray(ObjArray *array)
{
    qsort(array->values, array->count, sizeof(Value), compareValues);
}

bool equalArray(ObjArray *a, ObjArray *b)
{
    if (a->count != b->count)
    {
        return false;
    }
    for (int i = 0; i < a->count; i++)
    {
        if (!valuesEqual(a->values[i], b->values[i]))
        {
            return false;
        }
    }
    return true;
}

bool equalLinkedList(ObjLinkedList *a, ObjLinkedList *b)
{
    if (a->count != b->count)
    {
        return false;
    }
    struct Node *currentA = a->head;
    struct Node *currentB = b->head;
    while (currentA != NULL)
    {
        if (!valuesEqual(currentA->data, currentB->data))
        {
            return false;
        }
        currentA = currentA->next;
        currentB = currentB->next;
    }
    return true;
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

ObjHashTable *newHashTable()
{
    ObjHashTable *htable = ALLOCATE_OBJ(ObjHashTable, OBJ_HASH_TABLE);
    initTable(&htable->table);
    return htable;
}
bool putHashTable(ObjHashTable *table, ObjString *key, Value value)
{
    return tableSet(&table->table, key, value);
}
Value getHashTable(ObjHashTable *table, ObjString *key)
{
    Value value;
    if (tableGet(&table->table, key, &value))
    {
        return value;
    }
    else
    {
        return NIL_VAL;
    }
}

bool removeHashTable(ObjHashTable *table, ObjString *key)
{
    return tableDelete(&table->table, key);
}

void freeObjectHashTable(ObjHashTable *table)
{
    freeTable(&table->table);
    FREE(ObjHashTable, table);
}

void reverseArray(ObjArray *array)
{
    int i = 0;
    int j = array->count - 1;
    while (i < j)
    {
        Value temp = array->values[i];
        array->values[i] = array->values[j];
        array->values[j] = temp;
        i++;
        j--;
    }
}

void reverseLinkedList(ObjLinkedList *list)
{
    struct Node *current = list->head;
    while (current != NULL)
    {
        struct Node *temp = current->prev;
        current->prev = current->next;
        current->next = temp;
        current = current->prev;
    }
    struct Node *temp = current->prev;
    if (temp != NULL)
    {
        list->head = temp->prev;
    }
}

static bool valuesLess(Value a, Value b)
{
    if (IS_INT(a) && IS_INT(b))
    {
        return AS_INT(a) < AS_INT(b);
    }
    else if (IS_DOUBLE(a) && IS_DOUBLE(b))
    {
        return AS_DOUBLE(a) < AS_DOUBLE(b);
    }
    return false;
}

int searchArray(ObjArray *array, Value value)
{
    int low = 0;
    int high = array->count - 1;

    while (low <= high)
    {
        int mid = (low + high) / 2;
        Value midValue = array->values[mid];

        if (valuesEqual(midValue, value))
        {
            return mid;
        }
        else if (valuesLess(midValue, value))
        {
            low = mid + 1;
        }
        else
        {
            high = mid - 1;
        }
    }
    return -1;
}

int searchLinkedList(ObjLinkedList *list, Value value)
{
    struct Node *current = list->head;
    int index = 0;
    while (current != NULL)
    {
        if (valuesEqual(current->data, value))
        {
            return index;
        }
        current = current->next;
        index++;
    }
    return -1;
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

ObjMatrix initMatrix(int rows, int cols)
{
    ObjMatrix matrix;
    matrix.rows = rows;
    matrix.cols = cols;
    matrix.data = ALLOCATE(Value *, rows);
    for (int i = 0; i < rows; i++)
    {
        matrix.data[i] = ALLOCATE(Value, cols);
    }
    return matrix;
}

void freeMatrix(ObjMatrix *matrix)
{
    for (int i = 0; i < matrix->rows; i++)
    {
        FREE_ARRAY(Value, matrix->data[i], matrix->cols);
    }
    FREE_ARRAY(Value *, matrix->data, matrix->rows);
}

void printMatrix(ObjMatrix *matrix)
{
    for (int i = 0; i < matrix->rows; i++)
    {
        for (int j = 0; j < matrix->cols; j++)
        {
            printf("%g ", AS_DOUBLE(matrix->data[i][j]));
        }
        printf("\n");
    }
}

void setRow(ObjMatrix *matrix, int row, Value *values)
{
    for (int i = 0; i < matrix->cols; i++)
    {
        matrix->data[row][i] = values[i];
    }
}

void setCol(ObjMatrix *matrix, int col, Value *values)
{
    for (int i = 0; i < matrix->rows; i++)
    {
        matrix->data[i][col] = values[i];
    }
}

void setMatrix(ObjMatrix *matrix, int row, int col, Value value)
{
    if (row >= 0 && row < matrix->rows && col >= 0 && col < matrix->cols)
    {
        matrix->data[row][col] = value;
    }
    else
    {
        printf("Invalid position\n");
    }
}

Value getMatrix(ObjMatrix *matrix, int row, int col)
{
    if (row >= 0 && row < matrix->rows && col >= 0 && col < matrix->cols)
    {
        return matrix->data[row][col];
    }
    else
    {
        printf("Invalid position\n");
        return NIL_VAL;
    }
}

ObjMatrix addMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->rows != b->rows || a->cols != b->cols)
    {
        printf("ObjMatrix dimensions do not match\n");
        return initMatrix(0, 0);
    }
    ObjMatrix result = initMatrix(a->rows, a->cols);
    for (int i = 0; i < a->rows; i++)
    {
        for (int j = 0; j < a->cols; j++)
        {
            result.data[i][j] = DOUBLE_VAL(AS_DOUBLE(a->data[i][j]) + AS_DOUBLE(b->data[i][j]));
        }
    }
    return result;
}

ObjMatrix subMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->rows != b->rows || a->cols != b->cols)
    {
        printf("ObjMatrix dimensions do not match\n");
        return initMatrix(0, 0);
    }
    ObjMatrix result = initMatrix(a->rows, a->cols);
    for (int i = 0; i < a->rows; i++)
    {
        for (int j = 0; j < a->cols; j++)
        {
            result.data[i][j] = DOUBLE_VAL(AS_DOUBLE(a->data[i][j]) - AS_DOUBLE(b->data[i][j]));
        }
    }
    return result;
}

ObjMatrix mulMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->cols != b->rows)
    {
        printf("ObjMatrix dimensions do not match\n");
        return initMatrix(0, 0);
    }
    ObjMatrix result = initMatrix(a->rows, b->cols);
    for (int i = 0; i < a->rows; i++)
    {
        for (int j = 0; j < b->cols; j++)
        {
            Value sum = DOUBLE_VAL(0);
            for (int k = 0; k < a->cols; k++)
            {
                sum = DOUBLE_VAL(AS_DOUBLE(sum) + AS_DOUBLE(a->data[i][k]) * AS_DOUBLE(b->data[k][j]));
            }
            result.data[i][j] = sum;
        }
    }
    return result;
}

ObjMatrix divMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->rows != b->rows || a->cols != b->cols)
    {
        printf("ObjMatrix dimensions do not match\n");
        return initMatrix(0, 0);
    }
    ObjMatrix result = initMatrix(a->rows, a->cols);
    for (int i = 0; i < a->rows; i++)
    {
        for (int j = 0; j < a->cols; j++)
        {
            result.data[i][j] = DOUBLE_VAL(AS_DOUBLE(a->data[i][j]) / AS_DOUBLE(b->data[i][j]));
        }
    }
    return result;
}

ObjMatrix transposeMatrix(ObjMatrix *matrix)
{
    ObjMatrix result = initMatrix(matrix->cols, matrix->rows);
    for (int i = 0; i < matrix->rows; i++)
    {
        for (int j = 0; j < matrix->cols; j++)
        {
            result.data[j][i] = matrix->data[i][j];
        }
    }
    return result;
}

ObjMatrix scaleMatrix(ObjMatrix *matrix, Value scalar)
{
    ObjMatrix result = initMatrix(matrix->rows, matrix->cols);
    for (int i = 0; i < matrix->rows; i++)
    {
        for (int j = 0; j < matrix->cols; j++)
        {
            result.data[i][j] = DOUBLE_VAL(AS_DOUBLE(matrix->data[i][j]) * AS_DOUBLE(scalar));
        }
    }
    return result;
}

void rref(ObjMatrix *matrix)
{
    int lead = 0;
    for (int r = 0; r < matrix->rows; r++)
    {
        if (matrix->cols <= lead)
        {
            return;
        }
        int i = r;
        while (AS_DOUBLE(matrix->data[i][lead]) == 0)
        {
            i++;
            if (matrix->rows == i)
            {
                i = r;
                lead++;
                if (matrix->cols == lead)
                {
                    return;
                }
            }
        }
        swapRows(matrix, i, r);
        Value div = DOUBLE_VAL(AS_DOUBLE(matrix->data[r][lead]));
        for (int j = 0; j < matrix->cols; j++)
        {
            matrix->data[r][j] = DOUBLE_VAL(AS_DOUBLE(matrix->data[r][j]) / AS_DOUBLE(div));
        }
        for (int i = 0; i < matrix->rows; i++)
        {
            if (i != r)
            {
                Value sub = DOUBLE_VAL(AS_DOUBLE(matrix->data[i][lead]));
                for (int j = 0; j < matrix->cols; j++)
                {
                    matrix->data[i][j] = DOUBLE_VAL(AS_DOUBLE(matrix->data[i][j]) - AS_DOUBLE(sub) * AS_DOUBLE(matrix->data[r][j]));
                }
            }
        }
        lead++;
    }
}

void swapRows(ObjMatrix *matrix, int row1, int row2)
{
    Value *temp = matrix->data[row1];
    matrix->data[row1] = matrix->data[row2];
    matrix->data[row2] = temp;
}

ObjMatrix identityMatrix(int n)
{
    ObjMatrix matrix = initMatrix(n, n);
    for (int i = 0; i < n; i++)
    {
        matrix.data[i][i] = DOUBLE_VAL(1);
        for (int j = 0; j < n; j++)
        {
            if (j != i)
            {
                matrix.data[i][j] = DOUBLE_VAL(0);
            }
        }
    }
    return matrix;
}

void copyMatrix(ObjMatrix *a, ObjMatrix *b)
{
    for (int i = 0; i < a->rows; i++)
    {
        for (int j = 0; j < a->cols; j++)
        {
            b->data[i][j] = a->data[i][j];
        }
    }
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
    case OBJ_HASH_TABLE:
    {
        ObjHashTable *hashtable = AS_HASH_TABLE(value);
        printf("{");
        struct Entry *entries = hashtable->table.entries;
        int count = 0;
        for (int i = 0; i < hashtable->table.capacity; i++)
        {
            if (entries[i].key != NULL)
            {
                if (count > 0)
                {
                    printf(", ");
                }
                printValue(OBJ_VAL(entries[i].key));
                printf(": ");
                printValue(entries[i].value);
                count++;
            }
        }
        printf("}");
        break;
    }
    case OBJ_MATRIX:
    {
        printMatrix(AS_MATRIX(value));
        break;
    }
    }
}
