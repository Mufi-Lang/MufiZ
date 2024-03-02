#include <stdio.h>
#include <string.h>
#include <immintrin.h>

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

static Value add_val(Value a, Value b)
{
    if (IS_INT(a) && IS_INT(b))
    {
        return INT_VAL(AS_INT(a) + AS_INT(b));
    }
    else if (IS_DOUBLE(a) && IS_DOUBLE(b))
    {
        return DOUBLE_VAL(AS_DOUBLE(a) + AS_DOUBLE(b));
    }
    else
    {
        return NIL_VAL;
    }
}

static Value sub_val(Value a, Value b)
{
    if (IS_INT(a) && IS_INT(b))
    {
        return INT_VAL(AS_INT(a) - AS_INT(b));
    }
    else if (IS_DOUBLE(a) && IS_DOUBLE(b))
    {
        return DOUBLE_VAL(AS_DOUBLE(a) - AS_DOUBLE(b));
    }
    else
    {
        return NIL_VAL;
    }
}

static Value mul_val(Value a, Value b)
{
    if (IS_INT(a) && IS_INT(b))
    {
        return INT_VAL(AS_INT(a) * AS_INT(b));
    }
    else if (IS_DOUBLE(a) && IS_DOUBLE(b))
    {
        return DOUBLE_VAL(AS_DOUBLE(a) * AS_DOUBLE(b));
    }
    else
    {
        return NIL_VAL;
    }
}

static Value div_val(Value a, Value b)
{
    if (IS_INT(a) && IS_INT(b))
    {
        return INT_VAL(AS_INT(a) / AS_INT(b));
    }
    else if (IS_DOUBLE(a) && IS_DOUBLE(b))
    {
        return DOUBLE_VAL(AS_DOUBLE(a) / AS_DOUBLE(b));
    }
    else
    {
        return NIL_VAL;
    }
}

ObjArray *newArray()
{
    ObjArray *array = ALLOCATE_OBJ(ObjArray, OBJ_ARRAY);
    array->capacity = 0;
    array->count = 0;
    array->values = NULL;
    array->_static = false;
    return array;
}

ObjArray *newArrayWithCap(int capacity, bool _static)
{
    ObjArray *array = ALLOCATE_OBJ(ObjArray, OBJ_ARRAY);
    array->capacity = capacity;
    array->count = 0;
    array->values = ALLOCATE(Value, capacity);
    array->_static = _static;
    return array;
}

ObjArray *mergeArrays(ObjArray *a, ObjArray *b)
{
    bool _static = a->_static && b->_static;
    ObjArray *newArray = newArrayWithCap(a->count + b->count, _static);
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
    if (array->capacity < array->count + 1 && !array->_static)
    {
        int oldCapacity = array->capacity;
        array->capacity = GROW_CAPACITY(oldCapacity);
        array->values = GROW_ARRAY(Value, array->values, oldCapacity, array->capacity);
    }
    else if (array->capacity < array->count + 1 && array->_static)
    {
        printf("Array is full");
        return;
    }

    array->values[array->count++] = value;
}

static void overWriteArray(ObjArray *array, int index, Value value)
{
    if (index < 0 || index >= array->count)
    {
        printf("Index out of bounds");
        return;
    }
    array->values[index] = value;
}

void insertArray(ObjArray *array, int index, Value value)
{
    if (index < 0 || index > array->count)
    {
        printf("Index out of bounds");
        return;
    }
    if (array->capacity < array->count + 1 && !array->_static)
    {
        int oldCapacity = array->capacity;
        array->capacity = GROW_CAPACITY(oldCapacity);
        array->values = GROW_ARRAY(Value, array->values, oldCapacity, array->capacity);
    }
    else if (array->capacity < array->count + 1 && array->_static)
    {
        printf("Array is full");
        return;
    }

    for (int i = array->count; i > index; i--)
    {
        array->values[i] = array->values[i - 1];
    }
    array->values[index] = value;
    array->count++;
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

ObjArray *sliceArray(ObjArray *array, int start, int end)
{
    ObjArray *sliced = newArrayWithCap(end - start, true);
    for (int i = start; i < end; i++)
    {
        pushArray(sliced, array->values[i]);
    }
    return sliced;
}

ObjArray *addArray(ObjArray *a, ObjArray *b)
{
    if (a->count != b->count)
    {
        printf("Arrays must have the same length");
        return NULL;
    }
    bool _static = a->_static && b->_static;
    ObjArray *result = newArrayWithCap(a->count, _static);
    for (int i = 0; i < a->count; i++)
    {
        pushArray(result, add_val(a->values[i], b->values[i]));
    }
    return result;
}

ObjArray *subArray(ObjArray *a, ObjArray *b)
{
    if (a->count != b->count)
    {
        printf("Arrays must have the same length");
        return NULL;
    }
    bool _static = a->_static && b->_static;
    ObjArray *result = newArrayWithCap(a->count, _static);
    for (int i = 0; i < a->count; i++)
    {
        pushArray(result, sub_val(a->values[i], b->values[i]));
    }
    return result;
}
ObjArray *mulArray(ObjArray *a, ObjArray *b)
{
    if (a->count != b->count)
    {
        printf("Arrays must have the same length");
        return NULL;
    }
    bool _static = a->_static && b->_static;
    ObjArray *result = newArrayWithCap(a->count, _static);
    for (int i = 0; i < a->count; i++)
    {
        pushArray(result, mul_val(a->values[i], b->values[i]));
    }
    return result;
}
ObjArray *divArray(ObjArray *a, ObjArray *b)
{
    if (a->count != b->count)
    {
        printf("Arrays must have the same length");
        return NULL;
    }
    bool _static = a->_static && b->_static;
    ObjArray *result = newArrayWithCap(a->count, _static);
    for (int i = 0; i < a->count; i++)
    {
        pushArray(result, div_val(a->values[i], b->values[i]));
    }
    return result;
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

ObjMatrix *initMatrix(int rows, int cols)
{
    ObjMatrix *matrix = ALLOCATE_OBJ(ObjMatrix, OBJ_MATRIX);
    matrix->rows = rows;
    matrix->cols = cols;
    matrix->len = rows * cols;
    matrix->data = newArrayWithCap(matrix->len, true);
    for (int i = 0; i < matrix->len; i++)
    {
        pushArray(matrix->data, DOUBLE_VAL(0.0));
    }
    return matrix;
}

// static Value getValue(ObjMatrix *mat, int row, int col)
// {
//     if (row >= 0 && row < mat->rows && col >= 0 && col < mat->cols)
//     {
//         return mat->data->values[row * mat->cols + col];
//     }
//     return NIL_VAL; // Return -1 or any other appropriate value to indicate error
// }

void printMatrix(ObjMatrix *matrix)
{
    if (matrix != NULL)
    {
        if (matrix->data->count > 0)
        {
            {
                for (int i = 0; i < matrix->len; ++i)
                {
                    printValue(matrix->data->values[i]);
                    printf(" ");
                    if ((i + 1) % matrix->cols == 0)
                    {
                        printf("\n");
                    }
                }
            }
        }
        else
        {
            printf("[]\n");
        }
    }
}

void setRow(ObjMatrix *matrix, int row, ObjArray *values)
{
    if (matrix != NULL && values != NULL && row >= 0 && row < matrix->rows)
    {
        for (int col = 0; col < matrix->cols; ++col)
        {
            overWriteArray(matrix->data, row * matrix->cols + col, values->values[col]);
        }
    }
}

void setCol(ObjMatrix *matrix, int col, ObjArray *values)
{
    if (matrix != NULL && values != NULL && col >= 0 && col < matrix->cols)
    {
        for (int row = 0; row < matrix->rows; ++row)
        {
            overWriteArray(matrix->data, row * matrix->cols + col, values->values[row]);
        }
    }
}
void setMatrix(ObjMatrix *matrix, int row, int col, Value value)
{
    if (matrix != NULL && row >= 0 && row < matrix->rows && col >= 0 && col < matrix->cols)
    {
        overWriteArray(matrix->data, row * matrix->cols + col, value);
    }
}
Value getMatrix(ObjMatrix *matrix, int row, int col)
{
    if (matrix != NULL && row >= 0 && row < matrix->rows && col >= 0 && col < matrix->cols)
    {
        return matrix->data->values[row * matrix->cols + col];
    }
    return NIL_VAL;
}

void swapRow(ObjMatrix *matrix, int row1, int row2)
{
    if (matrix != NULL && row1 >= 0 && row1 < matrix->rows && row2 >= 0 && row2 < matrix->rows)
    {
        for (int col = 0; col < matrix->cols; ++col)
        {
            Value temp = matrix->data->values[row1 * matrix->cols + col];
            overWriteArray(matrix->data, row1 * matrix->cols + col, matrix->data->values[row2 * matrix->cols + col]);
            overWriteArray(matrix->data, row2 * matrix->cols + col, temp);
        }
    }
}

void rref(ObjMatrix *matrix)
{
    int lead = 0;
    for (int r = 0; r < matrix->rows; r++)
    {
        if (lead >= matrix->cols)
        {
            return;
        }
        int i = r;
        while (AS_DOUBLE(getMatrix(matrix, i, lead)) == 0.0)
        {
            i++;
            if (i == matrix->rows)
            {
                i = r;
                lead++;
                if (lead == matrix->cols)
                {
                    return;
                }
            }
        }
        swapRow(matrix, i, r);
        Value div = getMatrix(matrix, r, lead);
        if (AS_DOUBLE(div) != 0.0)
        {
            for (int j = 0; j < matrix->cols; j++)
            {
                Value temp = DOUBLE_VAL(AS_DOUBLE(getMatrix(matrix, r, j)) / AS_DOUBLE(div));
                setMatrix(matrix, r, j, temp);
            }
        }
        for (int i = 0; i < matrix->rows; i++)
        {
            if (i != r)
            {
                Value sub = getMatrix(matrix, i, lead);
                for (int j = 0; j < matrix->cols; j++)
                {
                    Value temp = DOUBLE_VAL(AS_DOUBLE(getMatrix(matrix, i, j)) - AS_DOUBLE(getMatrix(matrix, r, j)) * AS_DOUBLE(sub));
                    setMatrix(matrix, i, j, temp);
                }
            }
        }
        lead++;
    }
}

int rank(ObjMatrix *matrix)
{
    ObjMatrix *copy = initMatrix(matrix->rows, matrix->cols);
    for (int i = 0; i < matrix->len; i++)
    {
        copy->data->values[i] = matrix->data->values[i];
    }
    rref(copy);
    int rank = 0;
    for (int i = 0; i < copy->rows; i++)
    {
        for (int j = 0; j < copy->cols; j++)
        {
            if (AS_DOUBLE(getMatrix(copy, i, j)) != 0.0)
            {
                rank++;
                break;
            }
        }
    }
    freeObjectArray(copy->data);
    FREE(ObjMatrix, copy);
    return rank;
}

ObjMatrix *addMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->rows != b->rows || a->cols != b->cols)
    {
        printf("Matrix dimensions do not match");
        return NULL;
    }
    ObjMatrix *result = initMatrix(a->rows, a->cols);
    for (int i = 0; i < a->len; i++)
    {
        overWriteArray(result->data, i, DOUBLE_VAL(AS_DOUBLE(a->data->values[i]) + AS_DOUBLE(b->data->values[i])));
    }
    return result;
}

ObjMatrix *subMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->rows != b->rows || a->cols != b->cols)
    {
        printf("Matrix dimensions do not match");
        return NULL;
    }
    ObjMatrix *result = initMatrix(a->rows, a->cols);
    for (int i = 0; i < a->len; i++)
    {
        overWriteArray(result->data, i, DOUBLE_VAL(AS_DOUBLE(a->data->values[i]) - AS_DOUBLE(b->data->values[i])));
    }
    return result;
}

ObjMatrix *mulMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->cols != b->rows)
    {
        printf("Matrix dimensions do not match");
        return NULL;
    }
    ObjMatrix *result = initMatrix(a->rows, b->cols);
    for (int i = 0; i < a->rows; i++)
    {
        for (int j = 0; j < b->cols; j++)
        {
            Value sum = DOUBLE_VAL(0.0);
            for (int k = 0; k < a->cols; k++)
            {
                Value temp = DOUBLE_VAL(AS_DOUBLE(getMatrix(a, i, k)) * AS_DOUBLE(getMatrix(b, k, j)));
                sum = DOUBLE_VAL(AS_DOUBLE(sum) + AS_DOUBLE(temp));
            }
            setMatrix(result, i, j, sum);
        }
    }
    return result;
}

ObjMatrix *divMatrix(ObjMatrix *a, ObjMatrix *b)
{
    if (a->rows != b->rows || a->cols != b->cols)
    {
        printf("Matrix dimensions do not match");
        return NULL;
    }
    ObjMatrix *result = initMatrix(a->rows, a->cols);
    for (int i = 0; i < a->len; i++)
    {
        overWriteArray(result->data, i, DOUBLE_VAL(AS_DOUBLE(a->data->values[i]) / AS_DOUBLE(b->data->values[i])));
    }
    return result;
}

ObjMatrix *transposeMatrix(ObjMatrix *matrix)
{
    ObjMatrix *result = initMatrix(matrix->cols, matrix->rows);
    for (int i = 0; i < matrix->rows; i++)
    {
        for (int j = 0; j < matrix->cols; j++)
        {
            setMatrix(result, j, i, getMatrix(matrix, i, j));
        }
    }
    return result;
}

ObjMatrix *identityMatrix(int n)
{
    ObjMatrix *result = initMatrix(n, n);
    for (int i = 0; i < n; i++)
    {
        setMatrix(result, i, i, DOUBLE_VAL(1.0));
    }
    return result;
}

double determinant(ObjMatrix *matrix)
{
    if (matrix->rows != matrix->cols)
    {
        printf("Matrix is not square");
        return 0.0;
    }
    if (matrix->rows == 1)
    {
        return AS_DOUBLE(getMatrix(matrix, 0, 0));
    }
    if (matrix->rows == 2)
    {
        return AS_DOUBLE(getMatrix(matrix, 0, 0)) * AS_DOUBLE(getMatrix(matrix, 1, 1)) - AS_DOUBLE(getMatrix(matrix, 0, 1)) * AS_DOUBLE(getMatrix(matrix, 1, 0));
    }
    double det = 0.0;
    for (int i = 0; i < matrix->rows; i++)
    {
        ObjMatrix *submatrix = initMatrix(matrix->rows - 1, matrix->cols - 1);
        int subi = 0;
        for (int row = 1; row < matrix->rows; row++)
        {
            int subj = 0;
            for (int col = 0; col < matrix->cols; col++)
            {
                if (col == i)
                {
                    continue;
                }
                setMatrix(submatrix, subi, subj, getMatrix(matrix, row, col));
                subj++;
            }
            subi++;
        }
        double sign = (i % 2 == 0) ? 1.0 : -1.0;
        det += sign * AS_DOUBLE(getMatrix(matrix, 0, i)) * determinant(submatrix);
        freeObjectArray(submatrix->data);
        FREE(ObjMatrix, submatrix);
    }
    return det;
}

FloatVector *initFloatVector(int size)
{
    FloatVector *vector = ALLOCATE_OBJ(FloatVector, OBJ_FVECTOR);
    vector->size = size;
    vector->count = 0;
    vector->data = ALLOCATE(float, size);
    return vector;
}

void freeFloatVector(FloatVector *vector)
{
    FREE_ARRAY(float, vector->data, vector->size);
    FREE(FloatVector, vector);
}

void pushFloatVector(FloatVector *vector, float value)
{
    if (vector->count + 1 > vector->size)
    {
        printf("Vector is full\n");
        return;
    }
    vector->data[vector->count] = value;
    vector->count++;
}

void printFloatVector(FloatVector *vector)
{
    printf("[");
    for (int i = 0; i < vector->count; i++)
    {
        printf("%.2f ", vector->data[i]);
    }
    printf("]");
    printf("\n");
}

void setFloatVector(FloatVector *vector, int index, float value)
{
    if (index < 0 || index >= vector->count)
    {
        printf("Index out of bounds\n");
        return;
    }
    vector->data[index] = value;
}

float getFloatVector(FloatVector *vector, int index)
{
    if (index < 0 || index >= vector->count)
    {
        printf("Index out of bounds\n");
        return 0;
    }
    return vector->data[index];
}

FloatVector *addFloatVector(FloatVector *vector1, FloatVector *vector2)
{
    if (vector1->size != vector2->size)
    {
        printf("Vectors are not of the same size\n");
        return NULL;
    }
    FloatVector *result = initFloatVector(vector1->size);
#if defined(__AVX2__)
    printf("Using AVX2\n");
    for (size_t i = 0; i < vector1->count; i += 8)
    {
        __m256 simd_arr1 = _mm256_loadu_ps(&vector1->data[i]);             // Load 8 floats from arr1
        __m256 simd_arr2 = _mm256_loadu_ps(&vector2->data[i]);             // Load 8 floats from arr2
        __m256 simd_result = _mm256_add_ps(simd_arr1, simd_arr2); // SIMD addition
        _mm256_storeu_ps(&result->data[i], simd_result);                // Store result back to memory
    }
    result->count = vector1->count;
    return result;
#endif
    printf("Using normal\n");
    for (int i = 0; i < vector1->size; i++)
    {
        result->data[i] = vector1->data[i] + vector2->data[i];
    }
    result->count = vector1->count;
    return result;

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
    case OBJ_FVECTOR: 
    {
        FloatVector *vector = AS_FVECTOR(value);
        printf("[");
        for (int i = 0; i < vector->count; i++)
        {
            printf("%.2f", vector->data[i]);
            if (i != vector->count - 1)
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
