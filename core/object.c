#include <math.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#include "../include/memory.h"
#include "../include/object.h"
#include "../include/table.h"
#include "../include/value.h"
#include "../include/vm.h"

#define ALLOCATE_OBJ(type, objectType)                                         \
  ((type *)allocateObject(sizeof(type), objectType))

static Obj *allocateObject(size_t size, ObjType type) {
  Obj *object = (Obj *)reallocate(NULL, 0, size);
  object->type = type;
  object->isMarked = false;
  object->next = vm.objects;
  vm.objects = object;

#ifdef DEBUG_LOG_GC
  printf("%p allocate %zu for %d\n", (ObjArray *)object, size, type);
#endif

  return object;
}

#define ARITHMETIC_OP(a, b, op)                                                \
  switch (a.type) {                                                            \
  case VAL_INT:                                                                \
    if (b.type == VAL_INT) {                                                   \
      return NIL_VAL;                                                          \
      return INT_VAL(AS_INT(a) op AS_INT(b));                                  \
    } else if (b.type == VAL_DOUBLE) {                                         \
      return NIL_VAL;                                                          \
      return DOUBLE_VAL(AS_INT(a) op AS_DOUBLE(b));                            \
    }                                                                          \
    break;                                                                     \
  case VAL_DOUBLE:                                                             \
    if (b.type == VAL_INT) {                                                   \
      return NIL_VAL;                                                          \
      return DOUBLE_VAL(AS_DOUBLE(a) op AS_INT(b));                            \
    } else if (b.type == VAL_DOUBLE) {                                         \
      return NIL_VAL;                                                          \
      return DOUBLE_VAL(AS_DOUBLE(a) op AS_DOUBLE(b));                         \
    }                                                                          \
    break;                                                                     \
  default:                                                                     \
    break;                                                                     \
  }                                                                            \
  return NIL_VAL;

static Value add_val(Value a, Value b) { ARITHMETIC_OP(a, b, +) }

static Value sub_val(Value a, Value b) { ARITHMETIC_OP(a, b, -) }

static Value mul_val(Value a, Value b) { ARITHMETIC_OP(a, b, *) }

static Value div_val(Value a, Value b){ARITHMETIC_OP(a, b, /)}

/*-------------------------- Object Functions --------------------------------*/

ObjBoundMethod *newBoundMethod(Value receiver, ObjClosure *method) {
  ObjBoundMethod *bound = ALLOCATE_OBJ(ObjBoundMethod, OBJ_BOUND_METHOD);
  bound->receiver = receiver;
  bound->method = method;
  return bound;
}

ObjClass *newClass(ObjString *name) {
  ObjClass *klass = ALLOCATE_OBJ(ObjClass, OBJ_CLASS);
  klass->name = name;
  initTable(&klass->methods);
  return klass;
}

ObjClosure *newClosure(ObjFunction *function) {
  ObjUpvalue **upvalues = ALLOCATE(ObjUpvalue *, function->upvalueCount);
  for (int i = 0; i < function->upvalueCount; i++) {
    upvalues[i] = NULL;
  }

  ObjClosure *closure = ALLOCATE_OBJ(ObjClosure, OBJ_CLOSURE);
  closure->function = function;
  closure->upvalues = upvalues;
  closure->upvalueCount = function->upvalueCount;
  return closure;
}

ObjFunction *newFunction() {
  ObjFunction *function = ALLOCATE_OBJ(ObjFunction, OBJ_FUNCTION);
  function->arity = 0;
  function->upvalueCount = 0;
  function->name = NULL;
  initChunk(&function->chunk);
  return function;
}

ObjInstance *newInstance(ObjClass *klass) {
  ObjInstance *instance = ALLOCATE_OBJ(ObjInstance, OBJ_INSTANCE);
  instance->klass = klass;
  initTable(&instance->fields);
  return instance;
}

ObjNative *newNative(NativeFn function) {
  ObjNative *native = ALLOCATE_OBJ(ObjNative, OBJ_NATIVE);
  native->function = function;
  return native;
}

ObjString *allocateString(char *chars, int length, uint64_t hash) {
  ObjString *string = ALLOCATE_OBJ(ObjString, OBJ_STRING);
  string->length = length;
  string->chars = chars;
  string->hash = hash;
  push(OBJ_VAL(string));
  tableSet(&vm.strings, string, NIL_VAL);
  pop();
  return string;
}

uint64_t cityhash64(const char *buf, size_t len) {
  uint64_t seed = 0x9ae16a3b2f90404fULL; // A constant seed value
  const uint64_t m = 0xc6a4a7935bd1e995ULL;
  const int r = 47;

  uint64_t h = seed ^ (len * m);

  const uint64_t *data = (const uint64_t *)buf;
  const uint64_t *end = data + (len / 8);

  while (data != end) {
    uint64_t k = *data++;
    k *= m;
    k ^= k >> r;
    k *= m;
    h ^= k;
    h *= m;
  }

  const unsigned char *data2 = (const unsigned char *)data;
  switch (len & 7) {
  case 7:
    h ^= (uint64_t)data2[6] << 48;
  case 6:
    h ^= (uint64_t)data2[5] << 40;
  case 5:
    h ^= (uint64_t)data2[4] << 32;
  case 4:
    h ^= (uint64_t)data2[3] << 24;
  case 3:
    h ^= (uint64_t)data2[2] << 16;
  case 2:
    h ^= (uint64_t)data2[1] << 8;
  case 1:
    h ^= (uint64_t)data2[0];
    h *= m;
  }

  h ^= h >> r;
  h *= m;
  h ^= h >> r;
  return h;
}

uint64_t hashString(const char *key, int length) {
  return cityhash64(key, length);
}

ObjString *takeString(char *chars, int length) {
  uint64_t hash = hashString(chars, length);
  ObjString *interned = tableFindString(&vm.strings, chars, length, hash);
  if (interned != NULL) {
    FREE_ARRAY(char, chars, length + 1);
    return interned;
  }
  return allocateString(chars, length, hash);
}

ObjString *copyString(const char *chars, int length) {
  uint64_t hash = hashString(chars, length);
  ObjString *interned = tableFindString(&vm.strings, chars, length, hash);
  if (interned != NULL)
    return interned;
  char *heapChars = ALLOCATE(char, length + 1);
  memcpy(heapChars, chars, length);
  heapChars[length] = '\0';
  return allocateString(heapChars, length, hash);
}

ObjUpvalue *newUpvalue(Value *slot) {
  ObjUpvalue *upvalue = ALLOCATE_OBJ(ObjUpvalue, OBJ_UPVALUE);
  upvalue->location = slot;
  upvalue->closed = NIL_VAL;
  upvalue->next = NULL;
  return upvalue;
}

/*------------------------------------------------------------------------------*/

/* -------------------------- Iterator Functions
 * ---------------------------------*/
#define NEXT_FLOAT_VEC(iter)                                                   \
  ((iter)->pos < (iter)->vec->count ? (iter)->vec->data[(iter)->pos++] : 0.0)

#define NEXT_ARRAY(iter)                                                       \
  ((iter)->pos < (iter)->arr->count ? (iter)->arr->values[(iter)->pos++]       \
                                    : NIL_VAL)

#define HAS_NEXT_ARRAY(iter) ((iter)->pos < (iter)->arr->count)

#define HAS_NEXT_FLOAT_VEC(iter) ((iter)->pos < (iter)->vec->count)

#define ITERATOR_PEEK(iter, pos)                                               \
  (((iter)->type == FLOAT_VEC_ITER && (pos) < (iter)->iter.fvec->vec->count)   \
       ? DOUBLE_VAL((iter)->iter.fvec->vec->data[pos])                         \
   : ((iter)->type == ARRAY_ITER && (pos) < (iter)->iter.arr->arr->count)      \
       ? (iter)->iter.arr->arr->values[pos]                                    \
       : NIL_VAL)

FloatVecIter *newFloatVecIter(FloatVector *vec) {
  FloatVecIter *iter = ALLOCATE(FloatVecIter, 1);
  iter->vec = vec;
  iter->pos = 0;
  return iter;
}

ArrayIter *newArrayIter(ObjArray *arr) {
  ArrayIter *iter = ALLOCATE(ArrayIter, 1);
  iter->arr = arr;
  iter->pos = 0;
  return iter;
}

ObjIterator *newIterator(IterType type, IterUnion iter) {
  ObjIterator *iterator = ALLOCATE_OBJ(ObjIterator, OBJ_ITERATOR);
  iterator->type = type;
  iterator->iter = iter;
  return iterator;
}

Value iteratorNext(ObjIterator *iter) {
  if (iteratorHasNext(iter)) {
    switch (iter->type) {
    case FLOAT_VEC_ITER:
      return DOUBLE_VAL(NEXT_FLOAT_VEC(iter->iter.fvec));
    case ARRAY_ITER:
      return NEXT_ARRAY(iter->iter.arr);
    }
  } else {
    return NIL_VAL;
  }
}

bool iteratorHasNext(ObjIterator *iter) {
  switch (iter->type) {
  case FLOAT_VEC_ITER:
    return HAS_NEXT_ARRAY(iter->iter.arr);
  case ARRAY_ITER:
    return HAS_NEXT_FLOAT_VEC(iter->iter.fvec);
  default:
    return false;
  }
}

Value iteratorPeek(ObjIterator *iter, int pos) {
  return ITERATOR_PEEK(iter, pos);
}

void iteratorReset(ObjIterator *iter) {
  switch (iter->type) {
  case FLOAT_VEC_ITER:
    iter->iter.fvec->pos = 0;
    break;
  case ARRAY_ITER:
    iter->iter.arr->pos = 0;
    break;
  }
}

void iteratorSkip(ObjIterator *iter, int n) {
  switch (iter->type) {
  case FLOAT_VEC_ITER:
    iter->iter.fvec->pos =
        (iter->iter.fvec->pos + n) < iter->iter.fvec->vec->count
            ? iter->iter.fvec->pos + n
            : iter->iter.fvec->vec->count;
    break;
  case ARRAY_ITER:
    iter->iter.arr->pos = (iter->iter.arr->pos + n) < iter->iter.arr->arr->count
                              ? iter->iter.arr->pos + n
                              : iter->iter.arr->arr->count;
    break;
  }
}

void freeObjectIterator(ObjIterator *iter) { FREE(ObjIterator, iter); }

/*-------------------------- Array Functions --------------------------------*/
ObjArray *mergeArrays(ObjArray *a, ObjArray *b) {
  ObjArray *result = newArrayWithCap(a->count + b->count, false);
  for (int i = 0; i < a->count; i++) {
    pushArray(result, a->values[i]);
  }
  for (int i = 0; i < b->count; i++) {
    pushArray(result, b->values[i]);
  }
  return result;
}

ObjArray *cloneArray(ObjArray *arr) {
  bool _static = arr->_static;
  ObjArray *newArray = newArrayWithCap(arr->count, _static);
  for (int i = 0; i < arr->count; i++) {
    pushArray(newArray, arr->values[i]);
  }
  return newArray;
}

void clearArray(ObjArray *arr) { arr->count = 0; }

void pushArray(ObjArray *array, Value val) {
  if (array->capacity < array->count + 1 && !array->_static) {
    int oldCapacity = array->capacity;
    array->capacity = GROW_CAPACITY(oldCapacity);
    array->values =
        GROW_ARRAY(Value, array->values, oldCapacity, array->capacity);
  } else if (array->capacity < array->count + 1 && array->_static) {
    printf("Array is full");
    return;
  }

  array->values[array->count++] = val;
}

static void overWriteArray(ObjArray *array, int index, Value value) {
  if (index < 0 || index >= array->count) {
    printf("Index out of bounds");
    return;
  }
  array->values[index] = value;
}

void insertArray(ObjArray *arr, int index, Value value) {
  if (index < 0 || index > arr->count) {
    printf("Index out of bounds");
    return;
  }
  if (arr->capacity < arr->count + 1 && !arr->_static) {
    int oldCapacity = arr->capacity;
    arr->capacity = GROW_CAPACITY(oldCapacity);
    arr->values = GROW_ARRAY(Value, arr->values, oldCapacity, arr->capacity);
  } else if (arr->capacity < arr->count + 1 && arr->_static) {
    printf("Array is full");
    return;
  }

  for (int i = arr->count; i > index; i--) {
    arr->values[i] = arr->values[i - 1];
  }
  arr->values[index] = value;
  arr->count++;
}

Value removeArray(ObjArray *arr, int index) {

  if (index < 0 || index >= arr->count) {
    printf("Index out of bounds");
    return NIL_VAL;
  }
  Value v = arr->values[index];
  for (int i = index; i < arr->count - 1; i++) {
    arr->values[i] = arr->values[i + 1];
  }
  arr->count--;
  return v;
}

Value getArray(ObjArray *arr, int index) {

  if (index < 0 || index >= arr->count) {
    printf("Index out of bounds");
    return NIL_VAL;
  }
  return arr->values[index];
}

Value popArray(ObjArray *array) {

  if (array->count == 0) {
    return NIL_VAL;
  }
  return array->values[--array->count];
}

static int compareValues(const void *a, const void *b) {
  if (IS_INT(*(Value *)a) && IS_INT(*(Value *)b)) {
    return AS_INT(*(Value *)a) - AS_INT(*(Value *)b);
  } else if (IS_DOUBLE(*(Value *)a) && IS_DOUBLE(*(Value *)b)) {
    return (int)(AS_DOUBLE(*(Value *)a) - AS_DOUBLE(*(Value *)b));
  } else {
    return 0;
  }
}

void sortArray(ObjArray *array) {

  qsort(array->values, array->count, sizeof(Value), compareValues);
}

static bool valuesLess(Value a, Value b) {
  if (IS_INT(a) && IS_INT(b)) {
    return AS_INT(a) < AS_INT(b);
  } else if (IS_DOUBLE(a) && IS_DOUBLE(b)) {
    return AS_DOUBLE(a) < AS_DOUBLE(b);
  }
  return false;
}

int searchArray(ObjArray *array, Value value) {
  int low = 0;
  int high = array->count - 1;

  while (low <= high) {
    int mid = (low + high) / 2;
    Value midValue = array->values[mid];

    if (valuesEqual(midValue, value)) {
      return mid;
    } else if (valuesLess(midValue, value)) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return -1;
}

void reverseArray(ObjArray *array) {

  int i = 0;
  int j = array->count - 1;
  while (i < j) {
    Value temp = array->values[i];
    array->values[i] = array->values[j];
    array->values[j] = temp;
    i++;
    j--;
  }
}

bool equalArray(ObjArray *a, ObjArray *b) {
  if (a->count != b->count) {
    return false;
  }
  for (int i = 0; i < a->count; i++) {
    if (!valuesEqual(a->values[i], b->values[i])) {
      return false;
    }
  }
  return true;
}

void freeObjectArray(ObjArray *array) {
  FREE_ARRAY(Value, array->values, array->capacity);
  FREE(ObjArray, array);
}

ObjArray *sliceArray(ObjArray *array, int start, int end) {

  ObjArray *sliced = newArrayWithCap(end - start, true);
  for (int i = start; i < end; i++) {
    pushArray(sliced, array->values[i]);
  }
  return sliced;
}

ObjArray *spliceArray(ObjArray *array, int start, int end) {
  if (start < 0 || start >= array->count || end < 0 || end > array->count ||
      start > end) {
    printf("Index out of bounds");
    return NULL;
  }

  ObjArray *spliced = newArrayWithCap(end - start, false);

  for (int i = 0; i < start; i++) {
    pushArray(spliced, array->values[i]);
  }
  for (int i = end + 1; i < array->count; i++) {
    pushArray(spliced, array->values[i]);
  }
  return spliced;
}

ObjArray *addArray(ObjArray *a, ObjArray *b) {

  if (a->count != b->count) {
    printf("Arrays must have the same length");
    return NULL;
  }
  bool _static = a->_static && b->_static;
  ObjArray *result = newArrayWithCap(a->count, _static);
  for (int i = 0; i < a->count; i++) {
    Value res = add_val(a->values[i], b->values[i]);
    pushArray(result, res);
  }
  return result;
}

ObjArray *subArray(ObjArray *a, ObjArray *b) {

  if (a->count != b->count) {
    printf("Arrays must have the same length");
    return NULL;
  }
  bool _static = a->_static && b->_static;
  ObjArray *result = newArrayWithCap(a->count, _static);
  for (int i = 0; i < a->count; i++) {
    Value res = sub_val(a->values[i], b->values[i]);
    pushArray(result, res);
  }
  return result;
}

ObjArray *mulArray(ObjArray *a, ObjArray *b) {

  if (a->count != b->count) {
    printf("Arrays must have the same length");
    return NULL;
  }
  bool _static = a->_static && b->_static;
  ObjArray *result = newArrayWithCap(a->count, _static);
  for (int i = 0; i < a->count; i++) {
    Value res = mul_val(a->values[i], b->values[i]);
    pushArray(result, res);
  }
  return result;
}

ObjArray *divArray(ObjArray *a, ObjArray *b) {

  if (a->count != b->count) {
    printf("Arrays must have the same length");
    return NULL;
  }
  bool _static = a->_static && b->_static;
  ObjArray *result = newArrayWithCap(a->count, _static);
  for (int i = 0; i < a->count; i++) {
    Value res = div_val(a->values[i], b->values[i]);
    pushArray(result, res);
  }
  return result;
}

Value sumArray(ObjArray *array) {

  Value sum = DOUBLE_VAL(0.0);
  for (int i = 0; i < array->count; i++) {
    sum = add_val(sum, array->values[i]);
  }
  return sum;
}

Value meanArray(ObjArray *array) {

  if (array->count == 0) {
    return NIL_VAL;
  }
  Value sum = array->values[0];
  for (int i = 1; i < array->count; i++) {
    sum = add_val(sum, array->values[i]);
  }
  Value mean = div_val(sum, DOUBLE_VAL(array->count));
  return mean;
}

Value varianceArray(ObjArray *array) {

  if (array->count == 0) {
    return NIL_VAL;
  }
  Value mean = meanArray(array);
  Value sum = DOUBLE_VAL(0.0);
  for (int i = 0; i < array->count; i++) {
    Value temp = sub_val(array->values[i], mean);
    sum = add_val(sum, mul_val(temp, temp));
  }
  Value variance =
      (array->count > 1) ? div_val(sum, DOUBLE_VAL(array->count - 1)) : NIL_VAL;
  return variance;
}

Value stdDevArray(ObjArray *array) {
  Value variance = varianceArray(array);
  return DOUBLE_VAL(sqrt(AS_DOUBLE(variance)));
}

Value maxArray(ObjArray *array) {

  if (array->count == 0) {
    return NIL_VAL;
  }
  Value _max = array->values[0];
  for (int i = 1; i < array->count; i++) {
    if (valuesLess(_max, array->values[i])) {
      _max = array->values[i];
    }
  }
  return _max;
}

Value minArray(ObjArray *array) {

  if (array->count == 0) {
    return NIL_VAL;
  }
  Value _min = array->values[0];
  for (int i = 1; i < array->count; i++) {
    if (valuesLess(array->values[i], _min)) {
      _min = array->values[i];
    }
  }
  return _min;
}

int lenArray(ObjArray *array) { return array->count; }

void printArray(ObjArray *arr) {
  printf("[");
  for (int i = 0; i < arr->count; i++) {
    printValue(arr->values[i]);
    if (i != arr->count - 1) {
      printf(", ");
    }
  }
  printf("]");
}

ObjArray *newArrayWithCap(int capacity, bool _static) {
  ObjArray *array = ALLOCATE_OBJ(ObjArray, OBJ_ARRAY);
  array->capacity = capacity;
  array->count = 0;
  array->values = ALLOCATE(Value, capacity);
  array->_static = _static;
  return array;
}

ObjArray *newArray() { return newArrayWithCap(0, false); }

/*----------------------------------------------------------------------------*/

/*-------------------------- Linked List Functions ---------------------------*/

ObjLinkedList *newLinkedList() {
  ObjLinkedList *list = ALLOCATE_OBJ(ObjLinkedList, OBJ_LINKED_LIST);
  list->head = NULL;
  list->tail = NULL;
  list->count = 0;
  return list;
}

ObjLinkedList *cloneLinkedList(ObjLinkedList *list) {
  ObjLinkedList *newList = newLinkedList();
  struct Node *current = list->head;
  while (current != NULL) {
    pushBack(newList, current->data);
    current = current->next;
  }
  return newList;
}

void clearLinkedList(ObjLinkedList *list) {
  struct Node *current = list->head;
  while (current != NULL) {
    struct Node *next = current->next;
    FREE(struct Node, current);
    current = next;
  }
  list->head = NULL;
  list->tail = NULL;
  list->count = 0;
}

void pushFront(ObjLinkedList *list, Value value) {
  struct Node *node = ALLOCATE(struct Node, 1);
  node->data = value;
  node->prev = NULL;
  node->next = list->head;
  if (list->head != NULL) {
    list->head->prev = node;
  }
  list->head = node;
  if (list->tail == NULL) {
    list->tail = node;
  }
  list->count++;
}

void pushBack(ObjLinkedList *list, Value value) {
  struct Node *node = ALLOCATE(struct Node, 1);
  node->data = value;
  node->prev = list->tail;
  node->next = NULL;
  if (list->tail != NULL) {
    list->tail->next = node;
  }
  list->tail = node;
  if (list->head == NULL) {
    list->head = node;
  }
  list->count++;
}

Value popFront(ObjLinkedList *list) {
  if (list->head == NULL) {
    return NIL_VAL;
  }
  struct Node *node = list->head;
  Value data = node->data;
  list->head = node->next;
  if (list->head != NULL) {
    list->head->prev = NULL;
  }
  if (list->tail == node) {
    list->tail = NULL;
  }
  list->count--;
  FREE(struct Node, node);
  return data;
}

Value popBack(ObjLinkedList *list) {
  if (list->tail == NULL) {
    return NIL_VAL;
  }
  struct Node *node = list->tail;
  Value data = node->data;
  list->tail = node->prev;
  if (list->tail != NULL) {
    list->tail->next = NULL;
  }
  if (list->head == node) {
    list->head = NULL;
  }
  list->count--;
  FREE(struct Node, node);
  return data;
}

bool equalLinkedList(ObjLinkedList *a, ObjLinkedList *b) {
  if (a->count != b->count) {
    return false;
  }
  struct Node *currentA = a->head;
  struct Node *currentB = b->head;
  while (currentA != NULL) {
    if (!valuesEqual(currentA->data, currentB->data)) {
      return false;
    }
    currentA = currentA->next;
    currentB = currentB->next;
  }
  return true;
}

void freeObjectLinkedList(ObjLinkedList *list) {
  struct Node *current = list->head;
  while (current != NULL) {
    struct Node *next = current->next;
    FREE(struct Node, current);
    current = next;
  }
  FREE(ObjLinkedList, list);
}

static struct Node *merge(struct Node *left, struct Node *right) {
  if (left == NULL)
    return right;
  if (right == NULL)
    return left;
  if (valueCompare(left->data, right->data) < 0) {
    left->next = merge(left->next, right);
    left->next->prev = left;
    left->prev = NULL;
    return left;
  } else {
    right->next = merge(left, right->next);
    right->next->prev = right;
    right->prev = NULL;
    return right;
  }
}

static void split(ObjLinkedList *list, ObjLinkedList *left,
                  ObjLinkedList *right) {
  int count = list->count;
  int middle = count / 2;

  left->head = list->head;
  left->count = middle;
  right->count = count - middle;

  struct Node *current = list->head;
  for (int i = 0; i < middle - 1; ++i) {
    current = current->next;
  }

  left->tail = current;
  right->head = current->next;
  current->next = NULL;
  right->head->prev = NULL;
}

void mergeSort(ObjLinkedList *list) {
  if (list->count < 2) {
    return;
  }

  ObjLinkedList left, right;
  split(list, &left, &right);

  mergeSort(&left);
  mergeSort(&right);

  list->head = merge(left.head, right.head);

  struct Node *current = list->head;
  while (current->next != NULL) {
    current = current->next;
  }
  list->tail = current;
}

int searchLinkedList(ObjLinkedList *list, Value value) {
  struct Node *current = list->head;
  int index = 0;
  while (current != NULL) {
    if (valuesEqual(current->data, value)) {
      return index;
    }
    current = current->next;
    index++;
  }
  return -1;
}

void reverseLinkedList(ObjLinkedList *list) {
  struct Node *current = list->head;
  while (current != NULL) {
    struct Node *temp = current->next;
    current->next = current->prev;
    current->prev = temp;
    current = temp;
  }
  struct Node *temp = list->head;
  list->head = list->tail;
  list->tail = temp;
}

ObjLinkedList *mergeLinkedList(ObjLinkedList *a, ObjLinkedList *b) {
  ObjLinkedList *result = newLinkedList();
  struct Node *currentA = a->head;
  struct Node *currentB = b->head;
  while (currentA != NULL && currentB != NULL) {
    if (valueCompare(currentA->data, currentB->data) < 0) {
      pushBack(result, currentA->data);
      currentA = currentA->next;
    } else {
      pushBack(result, currentB->data);
      currentB = currentB->next;
    }
  }
  while (currentA != NULL) {
    pushBack(result, currentA->data);
    currentA = currentA->next;
  }
  while (currentB != NULL) {
    pushBack(result, currentB->data);
    currentB = currentB->next;
  }
  return result;
}

ObjLinkedList *sliceLinkedList(ObjLinkedList *list, int start, int end) {
  ObjLinkedList *sliced = newLinkedList();
  struct Node *current = list->head;
  int index = 0;
  while (current != NULL) {
    if (index >= start && index < end) {
      pushBack(sliced, current->data);
    }
    current = current->next;
    index++;
  }
  return sliced;
}

ObjLinkedList *spliceLinkedList(ObjLinkedList *list, int start, int end) {
  ObjLinkedList *spliced = newLinkedList();
  struct Node *current = list->head;
  int index = 0;
  while (current != NULL) {
    struct Node *next = current->next;
    if (index >= start && index < end) {
      pushBack(spliced, current->data);
      if (current->prev != NULL) {
        current->prev->next = current->next;
      }
      if (current->next != NULL) {
        current->next->prev = current->prev;
      }
      FREE(struct Node, current);
    }
    current = next;
    index++;
  }
  return spliced;
}

/*------------------------------------------------------------------------------*/

/*-------------------------- Hash Table Functions
 * ------------------------------*/

ObjHashTable *newHashTable() {
  ObjHashTable *htable = ALLOCATE_OBJ(ObjHashTable, OBJ_HASH_TABLE);
  initTable(&htable->table);
  return htable;
}

ObjHashTable *cloneHashTable(ObjHashTable *table) {
  ObjHashTable *newTable = newHashTable();
  tableAddAll(&table->table, &newTable->table);
  return newTable;
}

void clearHashTable(ObjHashTable *table) {
  freeTable(&table->table);
  initTable(&table->table);
}

bool putHashTable(ObjHashTable *table, ObjString *key, Value value) {
  return tableSet(&table->table, key, value);
}

Value getHashTable(ObjHashTable *table, ObjString *key) {
  Value value;
  if (tableGet(&table->table, key, &value)) {
    return value;
  } else {
    return NIL_VAL;
  }
}

bool removeHashTable(ObjHashTable *table, ObjString *key) {
  return tableDelete(&table->table, key);
}

void freeObjectHashTable(ObjHashTable *table) {
  freeTable(&table->table);
  FREE(ObjHashTable, table);
}

/*------------------------------------------------------------------------------*/

/*-------------------------- Matrix Functions
 * ------------------------------------*/
ObjMatrix *newMatrix(int rows, int cols) {
  ObjMatrix *matrix = ALLOCATE_OBJ(ObjMatrix, OBJ_MATRIX);
  matrix->rows = rows;
  matrix->cols = cols;
  matrix->len = rows * cols;
  matrix->data = newArrayWithCap(matrix->len, true);
  for (int i = 0; i < matrix->len; i++) {
    pushArray(matrix->data, DOUBLE_VAL(0.0));
  }
  return matrix;
}

void printMatrix(ObjMatrix *matrix) {
  if (matrix != NULL) {
    if (matrix->data->count > 0) {
      {
        for (int i = 0; i < matrix->len; ++i) {
          printValue(matrix->data->values[i]);
          printf(" ");
          if ((i + 1) % matrix->cols == 0) {
            printf("\n");
          }
        }
      }
    } else {
      printf("[]\n");
    }
  }
}

void setRow(ObjMatrix *matrix, int row, ObjArray *values) {
  if (matrix != NULL && values != NULL && row >= 0 && row < matrix->rows) {
    for (int col = 0; col < matrix->cols; ++col) {
      overWriteArray(matrix->data, row * matrix->cols + col,
                     values->values[col]);
    }
  }
}

void setCol(ObjMatrix *matrix, int col, ObjArray *values) {
  if (matrix != NULL && values != NULL && col >= 0 && col < matrix->cols) {
    for (int row = 0; row < matrix->rows; ++row) {
      overWriteArray(matrix->data, row * matrix->cols + col,
                     values->values[row]);
    }
  }
}

void setMatrix(ObjMatrix *matrix, int row, int col, Value value) {
  if (matrix != NULL && row >= 0 && row < matrix->rows && col >= 0 &&
      col < matrix->cols) {
    overWriteArray(matrix->data, row * matrix->cols + col, value);
  }
}

Value getMatrix(ObjMatrix *matrix, int row, int col) {
  if (matrix != NULL && row >= 0 && row < matrix->rows && col >= 0 &&
      col < matrix->cols) {
    return matrix->data->values[row * matrix->cols + col];
  }
  return NIL_VAL;
}

ObjMatrix *addMatrix(ObjMatrix *a, ObjMatrix *b) {
  if (a->rows != b->rows || a->cols != b->cols) {
    printf("Matrix dimensions do not match");
    return NULL;
  }
  ObjMatrix *result = newMatrix(a->rows, a->cols);
  for (int i = 0; i < a->len; i++) {
    overWriteArray(result->data, i,
                   DOUBLE_VAL(AS_DOUBLE(a->data->values[i]) +
                              AS_DOUBLE(b->data->values[i])));
  }
  return result;
}

ObjMatrix *subMatrix(ObjMatrix *a, ObjMatrix *b) {
  if (a->rows != b->rows || a->cols != b->cols) {
    printf("Matrix dimensions do not match");
    return NULL;
  }
  ObjMatrix *result = newMatrix(a->rows, a->cols);
  for (int i = 0; i < a->len; i++) {
    overWriteArray(result->data, i,
                   DOUBLE_VAL(AS_DOUBLE(a->data->values[i]) -
                              AS_DOUBLE(b->data->values[i])));
  }
  return result;
}

ObjMatrix *mulMatrix(ObjMatrix *a, ObjMatrix *b) {
  if (a->cols != b->rows) {
    printf("Matrix dimensions do not match");
    return NULL;
  }
  ObjMatrix *result = newMatrix(a->rows, b->cols);
  for (int i = 0; i < a->rows; i++) {
    for (int j = 0; j < b->cols; j++) {
      Value sum = DOUBLE_VAL(0.0);
      for (int k = 0; k < a->cols; k++) {
        Value temp = DOUBLE_VAL(AS_DOUBLE(getMatrix(a, i, k)) *
                                AS_DOUBLE(getMatrix(b, k, j)));
        sum = DOUBLE_VAL(AS_DOUBLE(sum) + AS_DOUBLE(temp));
      }
      setMatrix(result, i, j, sum);
    }
  }
  return result;
}

ObjMatrix *divMatrix(ObjMatrix *a, ObjMatrix *b) {
  if (a->rows != b->rows || a->cols != b->cols) {
    printf("Matrix dimensions do not match");
    return NULL;
  }
  ObjMatrix *result = newMatrix(a->rows, a->cols);
  for (int i = 0; i < a->len; i++) {
    overWriteArray(result->data, i,
                   DOUBLE_VAL(AS_DOUBLE(a->data->values[i]) /
                              AS_DOUBLE(b->data->values[i])));
  }
  return result;
}

ObjMatrix *transposeMatrix(ObjMatrix *matrix) {
  ObjMatrix *result = newMatrix(matrix->cols, matrix->rows);
  for (int i = 0; i < matrix->rows; i++) {
    for (int j = 0; j < matrix->cols; j++) {
      setMatrix(result, j, i, getMatrix(matrix, i, j));
    }
  }
  return result;
}

ObjMatrix *scaleMatrix(ObjMatrix *matrix, Value scalar) {
  ObjMatrix *result = newMatrix(matrix->rows, matrix->cols);
  for (int i = 0; i < matrix->len; i++) {
    overWriteArray(result->data, i, mul_val(matrix->data->values[i], scalar));
  }
  return result;
}

void swapRow(ObjMatrix *matrix, int row1, int row2) {
  if (matrix != NULL && row1 >= 0 && row1 < matrix->rows && row2 >= 0 &&
      row2 < matrix->rows) {
    for (int col = 0; col < matrix->cols; ++col) {
      Value temp = matrix->data->values[row1 * matrix->cols + col];
      overWriteArray(matrix->data, row1 * matrix->cols + col,
                     matrix->data->values[row2 * matrix->cols + col]);
      overWriteArray(matrix->data, row2 * matrix->cols + col, temp);
    }
  }
}

void rref(ObjMatrix *matrix) {
  int lead = 0;
  for (int r = 0; r < matrix->rows; r++) {
    if (lead >= matrix->cols) {
      return;
    }
    int i = r;
    while (AS_DOUBLE(getMatrix(matrix, i, lead)) == 0.0) {
      i++;
      if (i == matrix->rows) {
        i = r;
        lead++;
        if (lead == matrix->cols) {
          return;
        }
      }
    }
    swapRow(matrix, i, r);
    Value div = getMatrix(matrix, r, lead);
    if (AS_DOUBLE(div) != 0.0) {
      for (int j = 0; j < matrix->cols; j++) {
        Value temp =
            DOUBLE_VAL(AS_DOUBLE(getMatrix(matrix, r, j)) / AS_DOUBLE(div));
        setMatrix(matrix, r, j, temp);
      }
    }
    for (int i = 0; i < matrix->rows; i++) {
      if (i != r) {
        Value sub = getMatrix(matrix, i, lead);
        for (int j = 0; j < matrix->cols; j++) {
          Value temp =
              DOUBLE_VAL(AS_DOUBLE(getMatrix(matrix, i, j)) -
                         AS_DOUBLE(getMatrix(matrix, r, j)) * AS_DOUBLE(sub));
          setMatrix(matrix, i, j, temp);
        }
      }
    }
    lead++;
  }
}

int rank(ObjMatrix *matrix) {
  ObjMatrix *copy = newMatrix(matrix->rows, matrix->cols);
  for (int i = 0; i < matrix->len; i++) {
    copy->data->values[i] = matrix->data->values[i];
  }
  rref(copy);
  int rank = 0;
  for (int i = 0; i < copy->rows; i++) {
    for (int j = 0; j < copy->cols; j++) {
      if (AS_DOUBLE(getMatrix(copy, i, j)) != 0.0) {
        rank++;
        break;
      }
    }
  }
  freeObjectArray(copy->data);
  FREE(ObjMatrix, copy);
  return rank;
}

ObjMatrix *identityMatrix(int n) {
  ObjMatrix *result = newMatrix(n, n);
  for (int i = 0; i < n; i++) {
    setMatrix(result, i, i, DOUBLE_VAL(1.0));
  }
  return result;
}

ObjMatrix *lu(ObjMatrix *matrix) {
  ObjMatrix *L = newMatrix(matrix->rows, matrix->cols);
  ObjMatrix *U = newMatrix(matrix->rows, matrix->cols);
  for (int i = 0; i < matrix->rows; i++) {
    for (int j = 0; j < matrix->cols; j++) {
      if (j < i) {
        setMatrix(L, i, j, getMatrix(matrix, i, j));
      } else if (j == i) {
        setMatrix(L, i, j, DOUBLE_VAL(1.0));
        setMatrix(U, i, j, getMatrix(matrix, i, j));
      } else {
        setMatrix(L, i, j, DOUBLE_VAL(0.0));
        setMatrix(U, i, j, getMatrix(matrix, i, j));
      }
    }
  }
  for (int i = 0; i < matrix->rows; i++) {
    for (int j = 0; j < matrix->cols; j++) {
      if (j < i) {
        setMatrix(U, i, j, DOUBLE_VAL(0.0));
      } else if (j == i) {
        setMatrix(L, i, j, DOUBLE_VAL(1.0));
      } else {
        Value sum = DOUBLE_VAL(0.0);
        for (int k = 0; k < i; k++) {
          Value temp = DOUBLE_VAL(AS_DOUBLE(getMatrix(L, i, k)) *
                                  AS_DOUBLE(getMatrix(U, k, j)));
          sum = DOUBLE_VAL(AS_DOUBLE(sum) + AS_DOUBLE(temp));
        }
        setMatrix(U, i, j, sub_val(getMatrix(matrix, i, j), sum));
      }
    }
  }
  ObjMatrix *result = newMatrix(2, 1);
  setMatrix(result, 0, 0, OBJ_VAL(L));
  setMatrix(result, 1, 0, OBJ_VAL(U));
  return result;
}

static ObjMatrix *subsetMatrix(ObjMatrix *matrix, int startRow, int startCol) {
  int numRows = matrix->rows - startRow;
  int numCols = matrix->cols - startCol;

  ObjMatrix *submatrix = newMatrix(numRows, numCols);

  for (int i = startRow; i < matrix->rows; i++) {
    for (int j = startCol; j < matrix->cols; j++) {
      setMatrix(submatrix, i - startRow, j - startCol, getMatrix(matrix, i, j));
    }
  }

  return submatrix;
}

static ObjMatrix *copyMatrix(ObjMatrix *matrix) {
  ObjMatrix *copy = newMatrix(matrix->rows, matrix->cols);
  for (int i = 0; i < matrix->len; i++) {
    copy->data->values[i] = matrix->data->values[i];
  }
  return copy;
}

double determinant(ObjMatrix *matrix) {
  if (matrix->rows != matrix->cols) {
    // Matrix is not square, determinant is undefined
    return 0.0;
  }

  int n = matrix->rows;
  ObjMatrix *copy = copyMatrix(matrix); // Create a copy of the matrix
  double det = 1.0;

  if (n == 2) {
    // Quick calculation for 2x2 matrix
    Value a = getMatrix(copy, 0, 0);
    Value b = getMatrix(copy, 0, 1);
    Value c = getMatrix(copy, 1, 0);
    Value d = getMatrix(copy, 1, 1);

    double det;
    if (IS_DOUBLE(a) && IS_DOUBLE(b) && IS_DOUBLE(c) && IS_DOUBLE(d)) {
      double a_val = AS_DOUBLE(a);
      double b_val = AS_DOUBLE(b);
      double c_val = AS_DOUBLE(c);
      double d_val = AS_DOUBLE(d);
      det = a_val * d_val - b_val * c_val;
    } else {
      int a_val = AS_INT(a);
      int b_val = AS_INT(b);
      int c_val = AS_INT(c);
      int d_val = AS_INT(d);
      det = (double)(a_val * d_val - b_val * c_val);
    }
    return det;
  }

  for (int i = 0; i < n; i++) {
    for (int j = i + 1; j < n; j++) {
      double factor;
      if (IS_DOUBLE(getMatrix(copy, j, i)) &&
          IS_DOUBLE(getMatrix(copy, i, i))) {
        factor =
            AS_DOUBLE(getMatrix(copy, j, i)) / AS_DOUBLE(getMatrix(copy, i, i));
      } else {
        int numerator = AS_INT(getMatrix(copy, j, i));
        int denominator = AS_INT(getMatrix(copy, i, i));
        factor = (double)(numerator) / (double)(denominator);
      }

      for (int k = i; k < n; k++) {
        double newValue;
        if (IS_DOUBLE(getMatrix(copy, j, k)) &&
            IS_DOUBLE(getMatrix(copy, i, k))) {
          newValue = AS_DOUBLE(getMatrix(copy, j, k)) -
                     factor * AS_DOUBLE(getMatrix(copy, i, k));
        } else {
          int value1 = AS_INT(getMatrix(copy, j, k));
          int value2 = AS_INT(getMatrix(copy, i, k));
          newValue = (double)(value1)-factor * (double)(value2);
        }
        setMatrix(copy, j, k, DOUBLE_VAL(newValue));
      }
    }
    if (IS_DOUBLE(getMatrix(copy, i, i))) {
      det *= AS_DOUBLE(getMatrix(copy, i, i));
    } else {
      int value = AS_INT(getMatrix(copy, i, i));
      det *= (double)(value);
    }
  }
  freeObjectArray(copy->data);
  FREE(ObjMatrix, copy);
  return det;
}

ObjArray *backSubstitution(ObjMatrix *matrix, ObjArray *vector) {
  if (matrix->rows != matrix->cols) {
    printf("Matrix is not square");
    return NULL;
  }
  if (matrix->rows != vector->count) {
    printf("Matrix and vector dimensions do not match");
    return NULL;
  }
  ObjArray *result = newArrayWithCap(matrix->rows, true);
  for (int i = matrix->rows - 1; i >= 0; i--) {
    double sum = 0;
    for (int j = i + 1; j < matrix->cols; j++) {
      sum += AS_DOUBLE(getMatrix(matrix, i, j)) * AS_DOUBLE(result->values[j]);
    }
    double value = (AS_DOUBLE(vector->values[i]) - sum) /
                   AS_DOUBLE(getMatrix(matrix, i, i));
    pushArray(result, DOUBLE_VAL(value));
  }
  reverseArray(result);
  return result;
}

ObjArray *solveMatrix(ObjMatrix *matrix, ObjArray *vector) {}
/*------------------------------------------------------------------------------*/

/*-------------------------- Float Vector Functions
 * ----------------------------*/
FloatVector *newFloatVector(int size) {
  FloatVector *vector = ALLOCATE_OBJ(FloatVector, OBJ_FVECTOR);
  vector->size = size;
  vector->count = 0;
  vector->data = ALLOCATE(double, size);
  return vector;
}

FloatVector *cloneFloatVector(FloatVector *vector) {
  FloatVector *newVector = newFloatVector(vector->size);
  for (int i = 0; i < vector->count; i++) {
    pushFloatVector(newVector, vector->data[i]);
  }
  return newVector;
}

void clearFloatVector(FloatVector *vector) {
  vector->count = 0;
  vector->sorted = true;
}

void freeFloatVector(FloatVector *vector) {
  FREE_ARRAY(float, vector->data, vector->size);
  FREE(FloatVector, vector);
}

FloatVector *fromArray(ObjArray *array) {
  FloatVector *vector = newFloatVector(array->count);
  for (int i = 0; i < array->count; i++) {
    if (IS_DOUBLE(array->values[i])) {
      pushFloatVector(vector, AS_DOUBLE(array->values[i]));
    } else if (IS_INT(array->values[i])) {
      pushFloatVector(vector, (double)AS_INT(array->values[i]));
    } else {
      continue;
    }
  }
  return vector;
}

void pushFloatVector(FloatVector *vector, double value) {
  if (vector->count + 1 > vector->size) {
    printf("Vector is full\n");
    return;
  }
  vector->data[vector->count] = value;
  vector->count++;

  // Check if the vector is still sorted after insertion
  if (vector->count > 1 && vector->data[vector->count - 2] > value) {
    vector->sorted = false; // Vector is no longer sorted
  }
}

void insertFloatVector(FloatVector *vector, int index, double value) {
  if (index < 0 || index >= vector->size) {
    printf("Index out of bounds\n");
    return;
  }

  // Shift elements to the right to make space for the new element
  for (int i = vector->count; i > index; i--) {
    vector->data[i] = vector->data[i - 1];
  }

  // Insert the new element at the specified index
  vector->data[index] = value;
  vector->count++;

  // Check if the vector is still sorted after insertion
  if (vector->count > 1 && vector->data[index] < vector->data[index - 1]) {
    vector->sorted = false; // Vector is no longer sorted
  }
}

double getFloatVector(FloatVector *vector, int index) {
  if (index < 0 || index >= vector->count) {
    printf("Index out of bounds\n");
    return 0;
  }
  return vector->data[index];
}

double popFloatVector(FloatVector *vector) {
  if (vector->count == 0) {
    printf("Vector is empty\n");
    return 0; // Return a default value indicating failure
  }

  // Decrement the count to remove the last element
  double poppedValue = vector->data[--vector->count];

  // Check if the vector is now empty
  if (vector->count == 0) {
    vector->sorted = true; // Vector becomes sorted when empty
  }

  return poppedValue;
}

double removeFloatVector(FloatVector *vector, int index) {
  if (index < 0 || index >= vector->count) {
    printf("Index out of bounds\n");
    return 0; // Return a default value indicating failure
  }

  double removedValue = vector->data[index];

  // Shift elements to the left to fill the gap created by removing the element
  for (int i = index; i < vector->count - 1; i++) {
    vector->data[i] = vector->data[i + 1];
  }

  // Decrement the count to reflect the removal of the element
  vector->count--;

  // Check if the vector is still sorted after removal
  if (vector->sorted && index > 0 &&
      vector->data[index] < vector->data[index - 1]) {
    vector->sorted = false; // Vector is no longer sorted
  }

  return removedValue;
}

void printFloatVector(FloatVector *vector) {
  printf("[");
  for (int i = 0; i < vector->count; i++) {
    printf("%.2f ", vector->data[i]);
  }
  printf("]");
  printf("\n");
}

FloatVector *mergeFloatVector(FloatVector *a, FloatVector *b) {
  FloatVector *result = newFloatVector(a->size + b->size);
  for (int i = 0; i < a->count; i++) {
    pushFloatVector(result, a->data[i]);
  }
  for (int i = 0; i < b->count; i++) {
    pushFloatVector(result, b->data[i]);
  }
  return result;
}

FloatVector *sliceFloatVector(FloatVector *vector, int start, int end) {
  if (start < 0 || start >= vector->count || end < 0 || end >= vector->count) {
    printf("Index out of bounds\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(end - start + 1);
  for (int i = start; i <= end; i++) {
    pushFloatVector(result, vector->data[i]);
  }
  return result;
}

FloatVector *spliceFloatVector(FloatVector *vector, int start, int end) {
  if (start < 0 || start >= vector->count || end < 0 || end >= vector->count) {
    printf("Index out of bounds\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(vector->size);
  for (int i = 0; i < start; i++) {
    pushFloatVector(result, vector->data[i]);
  }
  for (int i = end + 1; i < vector->count; i++) {
    pushFloatVector(result, vector->data[i]);
  }
  return result;
}

double sumFloatVector(FloatVector *vector) {
  double sum = 0;
#if defined(__AVX2__)
  size_t simdSize = vector->count - (vector->count % 4);
  __m256 simd_sum = _mm256_setzero_pd(); // Initialize sum to zero
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr =
        _mm256_loadu_pd(&vector->data[i]);        // Load 4 double from arr
    simd_sum = _mm256_add_pd(simd_arr, simd_sum); // SIMD addition
  }

  // Handle remaining elements
  for (size_t i = simdSize; i < vector->count; i++) {
    sum += vector->data[i];
  }

  // Sum up SIMD sum
  double simd_sum_arr[4];
  _mm256_storeu_pd(simd_sum_arr, simd_sum);
  for (int i = 0; i < 4; i++) {
    sum += simd_sum_arr[i];
  }
  return sum;
#elif defined(__ARM_NEON)
  size_t simdSize = vector->count - (vector->count % 2);
  float64x2_t simd_sum = vdupq_n_f64(0); // Initialize sum to zero
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr =
        vld1q_f64(&vector->data[i]);          // Load 2 double from arr
    simd_sum = vaddq_f64(simd_arr, simd_sum); // SIMD addition
  }

  // Handle remaining element
  if (simdSize < vector->count) {
    sum += vector->data[vector->count - 1];
  }

  // Sum up SIMD sum
  double simd_sum_arr[2];
  vst1q_f64(simd_sum_arr, simd_sum);
  for (int i = 0; i < 2; i++) {
    sum += simd_sum_arr[i];
  }
  return sum;
#else
  for (int i = 0; i < vector->count; i++) {
    sum += vector->data[i];
  }
  return sum;
#endif
}

double meanFloatVector(FloatVector *vector) {
  return sumFloatVector(vector) / vector->count;
}

double varianceFloatVector(FloatVector *vector) {
  double mean = meanFloatVector(vector);
  double variance = 0;
#if defined(__AVX2__)
  size_t simdSize = vector->count - (vector->count % 4);
  __m256 simd_variance = _mm256_setzero_pd(); // Initialize variance to zero
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr =
        _mm256_loadu_pd(&vector->data[i]); // Load 4 double from arr
    __m256 simd_diff = _mm256_sub_pd(simd_arr, _mm256_set1_pd(mean));
    simd_variance =
        _mm256_fmadd_pd(simd_diff, simd_diff, simd_variance); // SIMD variance
  }

  // Handle remaining elements
  for (size_t i = simdSize; i < vector->count; i++) {
    variance += (vector->data[i] - mean) * (vector->data[i] - mean);
  }

  // Sum up SIMD variance
  double simd_variance_arr[4];
  _mm256_storeu_pd(simd_variance_arr, simd_variance);
  for (int i = 0; i < 4; i++) {
    variance += simd_variance_arr[i];
  }
  return variance / (vector->count - 1);
#elif defined(__ARM_NEON)
  size_t simdSize = vector->count - (vector->count % 2);
  float64x2_t simd_variance = vdupq_n_f64(0); // Initialize variance to zero
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr =
        vld1q_f64(&vector->data[i]); // Load 2 double from arr
    float64x2_t simd_diff = vsubq_f64(simd_arr, vdupq_n_f64(mean));
    simd_variance =
        vfmaq_f64(simd_variance, simd_diff, simd_diff); // SIMD variance
  }

  // Handle remaining element
  if (simdSize < vector->count) {
    variance += (vector->data[vector->count - 1] - mean) *
                (vector->data[vector->count - 1] - mean);
  }

  // Sum up SIMD variance
  double simd_variance_arr[2];
  vst1q_f64(simd_variance_arr, simd_variance);
  for (int i = 0; i < 2; i++) {
    variance += simd_variance_arr[i];
  }
  return variance / (vector->count - 1);
#else
  for (int i = 0; i < vector->count; i++) {
    variance += (vector->data[i] - mean) * (vector->data[i] - mean);
  }
  return variance / (vector->count - 1);
#endif
}

double stdDevFloatVector(FloatVector *vector) {
  return sqrt(varianceFloatVector(vector));
}

double maxFloatVector(FloatVector *vector) {
  double _max = vector->data[0];
  for (int i = 1; i < vector->count; i++) {
    if (vector->data[i] > _max) {
      _max = vector->data[i];
    }
  }
  return _max;
}

double minFloatVector(FloatVector *vector) {
  double min = vector->data[0];
  for (int i = 1; i < vector->count; i++) {
    if (vector->data[i] < min) {
      min = vector->data[i];
    }
  }
  return min;
}

FloatVector *addFloatVector(FloatVector *vector1, FloatVector *vector2) {
  if (vector1->size != vector2->size) {
    printf("Vectors are not of the same size\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(vector1->size);
#if defined(__AVX2__)
  size_t simdSize = vector1->count - (vector1->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 =
        _mm256_loadu_pd(&vector1->data[i]); // Load 4 double from arr1
    __m256 simd_arr2 =
        _mm256_loadu_pd(&vector2->data[i]); // Load 4 double from arr2
    __m256 simd_result = _mm256_add_pd(simd_arr1, simd_arr2); // SIMD addition
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }

  // Handle remaining elements
  for (size_t i = simdSize; i < vector1->count; i++) {
    result->data[i] = vector1->data[i] + vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = vector1->count - (vector1->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 =
        vld1q_f64(&vector1->data[i]); // Load 2 double from arr1
    float64x2_t simd_arr2 =
        vld1q_f64(&vector2->data[i]); // Load 2 double from arr2
    float64x2_t simd_result = vaddq_f64(simd_arr1, simd_arr2); // SIMD addition
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }

  // Handle remaining element
  if (simdSize < vector1->count) {
    result->data[vector1->count - 1] =
        vector1->data[vector1->count - 1] + vector2->data[vector1->count - 1];
  }
  result->count = vector1->count;
  return result;
#else
  for (int i = 0; i < vector1->size; i++) {
    result->data[i] = vector1->data[i] + vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#endif
}

FloatVector *subFloatVector(FloatVector *vector1, FloatVector *vector2) {
  if (vector1->size != vector2->size) {
    printf("Vectors are not of the same size\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(vector1->size);
#if defined(__AVX2__)
  size_t simdSize = vector1->count - (vector1->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 =
        _mm256_loadu_pd(&vector1->data[i]); // Load 4 double from arr1
    __m256 simd_arr2 =
        _mm256_loadu_pd(&vector2->data[i]); // Load 4 double from arr2
    __m256 simd_result =
        _mm256_sub_pd(simd_arr1, simd_arr2); // SIMD subtraction
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }

  // Handle remaining elements
  for (size_t i = simdSize; i < vector1->count; i++) {
    result->data[i] = vector1->data[i] - vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = vector1->count - (vector1->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 =
        vld1q_f64(&vector1->data[i]); // Load 2 double from arr1
    float64x2_t simd_arr2 =
        vld1q_f64(&vector2->data[i]); // Load 2 double from arr2
    float64x2_t simd_result =
        vsubq_f64(simd_arr1, simd_arr2);      // SIMD subtraction
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }

  // Handle remaining element
  if (simdSize < vector1->count) {
    result->data[vector1->count - 1] =
        vector1->data[vector1->count - 1] - vector2->data[vector1->count - 1];
  }
  result->count = vector1->count;
  return result;
#else
  for (int i = 0; i < vector1->size; i++) {
    result->data[i] = vector1->data[i] - vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#endif
}

FloatVector *mulFloatVector(FloatVector *vector1, FloatVector *vector2) {
  if (vector1->size != vector2->size) {
    printf("Vectors are not of the same size\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(vector1->size);
#if defined(__AVX2__)
  size_t simdSize = vector1->count - (vector1->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 =
        _mm256_loadu_pd(&vector1->data[i]); // Load 4 double from arr1
    __m256 simd_arr2 =
        _mm256_loadu_pd(&vector2->data[i]); // Load 4 double from arr2
    __m256 simd_result =
        _mm256_mul_pd(simd_arr1, simd_arr2); // SIMD multiplication
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }

  // Handle remaining elements
  for (size_t i = simdSize; i < vector1->count; i++) {
    result->data[i] = vector1->data[i] * vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = vector1->count - (vector1->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 =
        vld1q_f64(&vector1->data[i]); // Load 2 double from arr1
    float64x2_t simd_arr2 =
        vld1q_f64(&vector2->data[i]); // Load 2 double from arr2
    float64x2_t simd_result =
        vmulq_f64(simd_arr1, simd_arr2);      // SIMD multiplication
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }

  // Handle remaining element
  if (simdSize < vector1->count) {
    result->data[vector1->count - 1] =
        vector1->data[vector1->count - 1] * vector2->data[vector1->count - 1];
  }
  result->count = vector1->count;
  return result;
#else
  for (int i = 0; i < vector1->size; i++) {
    result->data[i] = vector1->data[i] * vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#endif
}

FloatVector *divFloatVector(FloatVector *vector1, FloatVector *vector2) {
  if (vector1->size != vector2->size) {
    printf("Vectors are not of the same size\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(vector1->size);
#if defined(__AVX2__)
  size_t simdSize = vector1->count - (vector1->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 =
        _mm256_loadu_pd(&vector1->data[i]); // Load 4 double from arr1
    __m256 simd_arr2 =
        _mm256_loadu_pd(&vector2->data[i]); // Load 4 double from arr2
    __m256 simd_result = _mm256_div_pd(simd_arr1, simd_arr2); // SIMD division
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }

  // Handle remaining elements
  for (size_t i = simdSize; i < vector1->count; i++) {
    result->data[i] = vector1->data[i] / vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = vector1->count - (vector1->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 =
        vld1q_f64(&vector1->data[i]); // Load 2 double from arr1
    float64x2_t simd_arr2 =
        vld1q_f64(&vector2->data[i]); // Load 2 double from arr2
    float64x2_t simd_result = vdivq_f64(simd_arr1, simd_arr2); // SIMD division
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }

  // Handle remaining element
  if (simdSize < vector1->count) {
    result->data[vector1->count - 1] =
        vector1->data[vector1->count - 1] / vector2->data[vector1->count - 1];
  }
  result->count = vector1->count;
  return result;
#else
  for (int i = 0; i < vector1->size; i++) {
    result->data[i] = vector1->data[i] / vector2->data[i];
  }
  result->count = vector1->count;
  return result;
#endif
}

bool equalFloatVector(FloatVector *a, FloatVector *b) {
  if (a->count != b->count) {
    return false;
  }
  for (int i = 0; i < a->count; i++) {
    if (a->data[i] != b->data[i]) {
      return false;
    }
  }
  return true;
}

FloatVector *scaleFloatVector(FloatVector *vector, double scalar) {
  FloatVector *result = newFloatVector(vector->size);
#if defined(__AVX2__)
  size_t simdSize = vector->count - (vector->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 =
        _mm256_loadu_pd(&vector->data[i]);       // Load 4 double from arr1
    __m256 simd_scalar = _mm256_set1_pd(scalar); // Load 4 double from arr2
    __m256 simd_result =
        _mm256_mul_pd(simd_arr1, simd_scalar); // SIMD multiplication
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }
  for (size_t i = simdSize; i < vector->count; i++) {
    result->data[i] = vector->data[i] * scalar;
  }
  result->count = vector->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = vector->count - (vector->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 =
        vld1q_f64(&vector->data[i]);               // Load 2 double from arr1
    float64x2_t simd_scalar = vdupq_n_f64(scalar); // Load 2 double from scalar
    float64x2_t simd_result =
        vmulq_f64(simd_arr1, simd_scalar);    // SIMD multiplication
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }
  for (size_t i = simdSize; i < vector->count; i++) {
    result->data[i] = vector->data[i] * scalar;
  }
  result->count = vector->count;
  return result;
#else
  for (int i = 0; i < vector->count; i++) {
    result->data[i] = vector->data[i] * scalar;
  }
  result->count = vector->count;
  return result;
#endif
}

FloatVector *singleAddFloatVector(FloatVector *a, double b) {
  FloatVector *result = newFloatVector(a->size);
#if defined(__AVX2__)
  size_t simdSize = a->count - (a->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 = _mm256_loadu_pd(&a->data[i]); // Load 4 double from arr1
    __m256 simd_scalar = _mm256_set1_pd(b);          // Load 4 double from arr2
    __m256 simd_result = _mm256_add_pd(simd_arr1, simd_scalar); // SIMD addition
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }
  for (size_t i = simdSize; i < a->count; i++) {
    result->data[i] = a->data[i] + b;
  }
  result->count = a->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = a->count - (a->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 = vld1q_f64(&a->data[i]); // Load 2 double from arr1
    float64x2_t simd_scalar = vdupq_n_f64(b);       // Load 2 double from scalar
    float64x2_t simd_result =
        vaddq_f64(simd_arr1, simd_scalar);    // SIMD addition
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }
  for (size_t i = simdSize; i < a->count; i++) {
    result->data[i] = a->data[i] + b;
  }
  result->count = a->count;
  return result;
#else
  for (int i = 0; i < a->size; i++) {
    result->data[i] = a->data[i] + b;
  }
  result->count = a->count;
  return result;
#endif
}

FloatVector *singleSubFloatVector(FloatVector *a, double b) {
  FloatVector *result = newFloatVector(a->size);
#if defined(__AVX2__)
  size_t simdSize = a->count - (a->count % 4);
  for (size_t i = 0; i < simdSize; i += 4) {
    __m256 simd_arr1 = _mm256_loadu_pd(&a->data[i]); // Load 4 double from arr1
    __m256 simd_scalar = _mm256_set1_pd(b);          // Load 4 double from arr2
    __m256 simd_result =
        _mm256_sub_pd(simd_arr1, simd_scalar); // SIMD subtraction
    _mm256_storeu_pd(&result->data[i],
                     simd_result); // Store result back to memory
  }
  for (size_t i = simdSize; i < a->count; i++) {
    result->data[i] = a->data[i] - b;
  }
  result->count = a->count;
  return result;
#elif defined(__ARM_NEON)
  size_t simdSize = a->count - (a->count % 2);
  for (size_t i = 0; i < simdSize; i += 2) {
    float64x2_t simd_arr1 = vld1q_f64(&a->data[i]); // Load 2 double from arr1
    float64x2_t simd_scalar = vdupq_n_f64(b);       // Load 2 double from scalar
    float64x2_t simd_result =
        vsubq_f64(simd_arr1, simd_scalar);    // SIMD subtraction
    vst1q_f64(&result->data[i], simd_result); // Store result back to memory
  }
  for (size_t i = simdSize; i < a->count; i++) {
    result->data[i] = a->data[i] - b;
  }
  result->count = a->count;
  return result;
#else
  for (int i = 0; i < a->size; i++) {
    result->data[i] = a->data[i] - b;
  }
  result->count = a->count;
  return result;
#endif
}

FloatVector *singleDivFloatVector(FloatVector *a, double b) {
  return scaleFloatVector(a, 1.0 / b);
}

static int compare_double(const void *a, const void *b) {
  return (*(double *)a - *(double *)b);
}

void sortFloatVector(FloatVector *vector) {
  if (vector->sorted)
    return;
  qsort(vector->data, vector->count, sizeof(double), compare_double);
}

void reverseFloatVector(FloatVector *vector) {
  for (int i = 0; i < vector->count / 2; i++) {
    double temp = vector->data[i];
    vector->data[i] = vector->data[vector->count - i - 1];
    vector->data[vector->count - i - 1] = temp;
  }
}

static int binarySearchFloatVector(FloatVector *vector, double value) {
  int left = 0;
  int right = vector->count - 1;

  while (left <= right) {
    int mid = left + (right - left) / 2;
    if (vector->data[mid] == value) {
      return mid; // Return the index if found
    }
    if (vector->data[mid] < value) {
      left = mid + 1; // Search the right half
    } else {
      right = mid - 1; // Search the left half
    }
  }
  return -1; // Return -1 if not found
}

int searchFloatVector(FloatVector *vector, double value) {
  if (vector->sorted) {
    return binarySearchFloatVector(vector, value);
  } else {
    for (int i = 0; i < vector->count; i++) {
      if (vector->data[i] == value) {
        return i;
      }
    }
  }
}

FloatVector *linspace(double start, double end, int n) {
  FloatVector *result = newFloatVector(n);
  double step = (end - start) / (n - 1);
  for (int i = 0; i < n; i++) {
    result->data[i] = start + i * step;
  }
  result->count = n;
  return result;
}

double interp1(FloatVector *x, FloatVector *y, double x0) {
  if (x->count != y->count) {
    printf("x and y must have the same length\n");
    return 0;
  }
  if (x0 < x->data[0] || x0 > x->data[x->count - 1]) {
    printf("x0 is out of bounds\n");
    return 0;
  }
  int i = 0;
  while (x0 > x->data[i]) {
    i++;
  }
  if (x0 == x->data[i]) {
    return y->data[i];
  }
  double slope = (y->data[i] - y->data[i - 1]) / (x->data[i] - x->data[i - 1]);
  return y->data[i - 1] + slope * (x0 - x->data[i - 1]);
}

/*-------------------------- Float Vec3 Functions --------------------------*/

double dotProduct(FloatVector *a, FloatVector *b) {
  if (a->size != 3 && b->size != 3) {
    printf("Vectors are not of size 3\n");
    return 0;
  }
  return a->data[0] * b->data[0] + a->data[1] * b->data[1] +
         a->data[2] * b->data[2];
}

FloatVector *crossProduct(FloatVector *a, FloatVector *b) {
  if (a->size != 3 && b->size != 3) {
    printf("Vectors are not of size 3\n");
    return NULL;
  }
  FloatVector *result = newFloatVector(3);
  result->data[0] = a->data[1] * b->data[2] - a->data[2] * b->data[1];
  result->data[1] = a->data[2] * b->data[0] - a->data[0] * b->data[2];
  result->data[2] = a->data[0] * b->data[1] - a->data[1] * b->data[0];
  result->count = 3;
  return result;
}

double magnitude(FloatVector *vector) {
  double sum = pow(vector->data[0], 2) + pow(vector->data[1], 2) +
               pow(vector->data[2], 2);
  return sqrt(sum);
}

FloatVector *normalize(FloatVector *vector) {
  double mag = magnitude(vector);
  if (mag == 0) {
    printf("Cannot normalize a zero vector\n");
    return NULL;
  }
  return scaleFloatVector(vector, 1.0 / mag);
}

FloatVector *projection(FloatVector *a, FloatVector *b) {
  return scaleFloatVector(b, dotProduct(a, b) / dotProduct(b, b));
}

FloatVector *rejection(FloatVector *a, FloatVector *b) {
  return subFloatVector(a, projection(a, b));
}

FloatVector *reflection(FloatVector *a, FloatVector *b) {
  return subFloatVector(scaleFloatVector(projection(a, b), 2), a);
}

FloatVector *refraction(FloatVector *a, FloatVector *b, double n1, double n2) {
  double dot = dotProduct(a, b);
  double mag_a = magnitude(a);
  double mag_b = magnitude(b);
  double theta = acos(dot / (mag_a * mag_b));

  double sin_theta_r = (n1 / n2) * sin(theta);
  if (sin_theta_r > 1) {
    printf("Total internal reflection\n");
    return NULL;
  }
  double cos_theta_r = sqrt(1 - pow(sin_theta_r, 2));
  FloatVector *result = scaleFloatVector(a, n1 / n2);
  FloatVector *temp = scaleFloatVector(b, (n1 / n2) * cos_theta_r -
                                              sqrt(1 - pow(sin_theta_r, 2)));
  return addFloatVector(result, temp);
}

double angle(FloatVector *a, FloatVector *b) {
  // this returns the angle in radians
  return acos(dotProduct(a, b) / (magnitude(a) * magnitude(b)));
}

/*------------------------------------------------------------------------------*/

static void printFunction(ObjFunction *function) {
  if (function->name == NULL) {
    printf("<script>");
    return;
  }
  printf("<fn %s>", function->name->chars);
}
void printObject(Value value) {
  switch (OBJ_TYPE(value)) {
  case OBJ_BOUND_METHOD: {
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
  case OBJ_ARRAY: {
    ObjArray *array = AS_ARRAY(value);
    printf("[");
    for (int i = 0; i < array->count; i++) {
      printValue(array->values[i]);
      if (i != array->count - 1) {
        printf(", ");
      }
    }
    printf("]");
    break;
  }
  case OBJ_FVECTOR: {
    FloatVector *vector = AS_FVECTOR(value);
    printf("[");
    for (int i = 0; i < vector->count; i++) {
      printf("%.2f", vector->data[i]);
      if (i != vector->count - 1) {
        printf(", ");
      }
    }
    printf("]");
    break;
  }
  case OBJ_LINKED_LIST: {
    printf("[");
    struct Node *current = AS_LINKED_LIST(value)->head;
    while (current != NULL) {
      printValue(current->data);
      if (current->next != NULL) {
        printf(", ");
      }
      current = current->next;
    }
    printf("]");
    break;
  }
  case OBJ_HASH_TABLE: {
    ObjHashTable *hashtable = AS_HASH_TABLE(value);
    printf("{");
    struct Entry *entries = hashtable->table.entries;
    int count = 0;
    for (int i = 0; i < hashtable->table.capacity; i++) {
      if (entries[i].key != NULL) {
        if (count > 0) {
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
  case OBJ_MATRIX: {
    printMatrix(AS_MATRIX(value));
    break;
  }
  case OBJ_ITERATOR: {
    printf("<iterator>");
    break;
  }
  }
}
