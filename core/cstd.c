#include "../include/cstd.h"
#include <math.h>
#include <stdio.h>

Value assert_nf(int argCount, Value *args) {
  if (argCount != 2) {
    runtimeError("assert() takes 1 argument.");
    return NIL_VAL;
  }
  if (valuesEqual(args[0], args[1])) {
    return NIL_VAL;
  } else {
    runtimeError("Assertion failed %s != %s", valueToString(args[0]),
                 valueToString(args[1]));
    return NIL_VAL;
  }
}

Value simd_stat_nf(int argCount, Value *args) {
  if (argCount != 0) {
    runtimeError("simd_stat() takes 0 arguments.");
  }

#ifdef __AVX2__
  printf("x86_64 SIMD AVX2 Enabled\n");
#elif defined(__ARM_NEON)
  printf("ARM NEON SIMD Enabled\n");
#else
  printf("SIMD Not Supported\n");
#endif

  return NIL_VAL;
}

Value iter_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("iter() takes 1 argument.");
    return NIL_VAL;
  }
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("Argument must be an array type.");
    return NIL_VAL;
  }
  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    ArrayIter *aiter = newArrayIter(a);
    ObjIterator *iter = newIterator(ARRAY_ITER, (IterUnion){.arr = aiter});
    return OBJ_VAL(iter);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    FloatVecIter *fiter = newFloatVecIter(f);
    ObjIterator *iter = newIterator(FLOAT_VEC_ITER, (IterUnion){.fvec = fiter});
    return OBJ_VAL(iter);
  }
  default:
    runtimeError("Invalid argument type.");
    return NIL_VAL;
  }
}

Value next_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("next() takes 1 argument.");
    return NIL_VAL;
  }
  if (!IS_ITERATOR(args[0])) {
    runtimeError("Argument must be an iterator.");
    return NIL_VAL;
  }
  ObjIterator *iter = AS_ITERATOR(args[0]);
  return iteratorNext(iter);
}

Value hasNext_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("has_next() takes 1 argument.");
    return NIL_VAL;
  }
  if (!IS_ITERATOR(args[0])) {
    runtimeError("Argument must be an iterator.");
    return NIL_VAL;
  }
  ObjIterator *iter = AS_ITERATOR(args[0]);
  return BOOL_VAL(iteratorHasNext(iter));
}

Value peek_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("peek() takes 2 argument.");
    return NIL_VAL;
  }
  if (!IS_ITERATOR(args[0])) {
    runtimeError("Argument must be an iterator.");
    return NIL_VAL;
  }

  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be a number.");
    return NIL_VAL;
  }

  ObjIterator *iter = AS_ITERATOR(args[0]);
  int pos = AS_NUM_INT(args[1]);
  return iteratorPeek(iter, pos);
}

Value reset_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("reset() takes 1 argument.");
    return NIL_VAL;
  }
  if (!IS_ITERATOR(args[0])) {
    runtimeError("Argument must be an iterator.");
    return NIL_VAL;
  }
  ObjIterator *iter = AS_ITERATOR(args[0]);
  iteratorReset(iter);
  return NIL_VAL;
}

Value skip_nf(int argCount, Value *args) {
  if (argCount != 2) {
    runtimeError("skip() takes 2 arguments.");
    return NIL_VAL;
  }
  if (!IS_ITERATOR(args[0])) {
    runtimeError("First argument must be an iterator.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be a number.");
    return NIL_VAL;
  }
  ObjIterator *iter = AS_ITERATOR(args[0]);
  int n = AS_NUM_INT(args[1]);
  iteratorSkip(iter, n);
  return NIL_VAL;
}

Value array_nf(int argCount, Value *args) {
  if (argCount == 0) {
    ObjArray *a = newArray();
    return OBJ_VAL(a);
  } else if (argCount == 1 && IS_FVECTOR(args[0])) {
    FloatVector *f = AS_FVECTOR(args[0]);
    ObjArray *a = newArrayWithCap(f->size, true);
    for (int i = 0; i < f->count; i++) {
      pushArray(a, DOUBLE_VAL(f->data[i]));
    }
    return OBJ_VAL(a);
  } else if (argCount >= 1) {
    if (!IS_PRIM_NUM(args[0])) {
      runtimeError("First argument must be a number.");
      return NIL_VAL;
    }

    if (argCount == 2 && !IS_BOOL(args[1])) {
      runtimeError("Second argument must be a bool");
      return NIL_VAL;
    }

    ObjArray *a = newArrayWithCap(AS_NUM_INT(args[0]), AS_BOOL(args[1]));
    return OBJ_VAL(a);
  } else {
    runtimeError("array() takes 0 or 1 argument.");
    return NIL_VAL;
  }
}

Value linkedlist_nf(int argCount, Value *args) {
  if (argCount != 0) {
    runtimeError("linked_list() takes no arguments.");
    return NIL_VAL;
  }

  ObjLinkedList *l = newLinkedList();
  return OBJ_VAL(l);
}

Value hashtable_nf(int argCount, Value *args) {
  if (argCount != 0) {
    runtimeError("hash_table() takes no arguments.");
    return NIL_VAL;
  }

  ObjHashTable *h = newHashTable();
  return OBJ_VAL(h);
}

Value put_nf(int argCount, Value *args) {
  if (argCount != 3) {
    runtimeError("put() takes 3 arguments.");
    return NIL_VAL;
  }

  if (!IS_HASH_TABLE(args[0])) {
    runtimeError("First argument must be a hash table.");
    return NIL_VAL;
  }
  if (!IS_STRING(args[1])) {
    runtimeError("Second argument must be a string.");
    return NIL_VAL;
  }
  ObjHashTable *h = AS_HASH_TABLE(args[0]);
  ObjString *key = AS_STRING(args[1]);
  return BOOL_VAL(putHashTable(h, key, args[2]));
}

Value get_nf(int argCount, Value *args) {
  if (argCount != 2) {
    runtimeError("get() takes 2 arguments.");
    return NIL_VAL;
  }

  if (!IS_HASH_TABLE(args[0])) {
    runtimeError("First argument must be a hash table.");
    return NIL_VAL;
  }
  if (!IS_STRING(args[1])) {
    runtimeError("Second argument must be a string.");
    return NIL_VAL;
  }
  ObjHashTable *h = AS_HASH_TABLE(args[0]);
  ObjString *key = AS_STRING(args[1]);
  return getHashTable(h, key);
}

Value remove_nf(int argCount, Value *args) {
  if (argCount != 2) {
    runtimeError("remove() takes 2 arguments.");
    return NIL_VAL;
  }

  if (!IS_HASH_TABLE(args[0]) && NOT_ARRAY_TYPES(args, 1)) {
    runtimeError(
        "First argument must be a hash table, array, or float vector.");
    return NIL_VAL;
  }
  if (!IS_STRING(args[1]) && !IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be a string or number.");
    return NIL_VAL;
  }
  switch (AS_OBJ(args[0])->type) {
  case OBJ_HASH_TABLE: {
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    ObjString *key = AS_STRING(args[1]);
    return BOOL_VAL(removeHashTable(h, key));
  }
  case OBJ_ARRAY: {
    return removeArray(AS_ARRAY(args[0]), AS_NUM_INT(args[1]));
  }
  case OBJ_FVECTOR: {
    return DOUBLE_VAL(
        removeFloatVector(AS_FVECTOR(args[0]), AS_NUM_INT(args[1])));
  }
  default: {
    // Handle invalid argument type
    break;
  }
  }
}

Value push_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be a list type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    for (int i = 1; i < argCount; i++) {
      pushArray(a, args[i]);
    }
    return NIL_VAL;
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    for (int i = 1; i < argCount; i++) {
      if (!IS_PRIM_NUM(args[i])) {
        runtimeError("All elements of the vector must be numbers.");
        return NIL_VAL;
      }
      pushFloatVector(f, AS_NUM_DOUBLE(args[i]));
    }
    return NIL_VAL;
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    for (int i = 1; i < argCount; i++) {
      pushBack(l, args[i]);
    }
    return NIL_VAL;
  }
  default:
    runtimeError("Invalid argument type.");
    return NIL_VAL;
  }
}

Value push_front_nf(int argCount, Value *args) {
  if (!IS_LINKED_LIST(args[0])) {
    runtimeError("First argument must be a linked list.");
    return NIL_VAL;
  }
  ObjLinkedList *l = AS_LINKED_LIST(args[0]);
  for (int i = 1; i < argCount; i++) {
    pushFront(l, args[i]);
  }
  return NIL_VAL;
}

Value pop_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("pop() takes 1 argument.");
    return NIL_VAL;
  }

  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be a list type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return popArray(a);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return DOUBLE_VAL(popFloatVector(f));
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    return popBack(l);
  }
  default: // unreachable
    break;
  }
}

Value pop_front_nf(int argCount, Value *args) {
  if (!IS_LINKED_LIST(args[0])) {
    runtimeError("First argument must be a linked list.");
    return NIL_VAL;
  }
  ObjLinkedList *l = AS_LINKED_LIST(args[0]);
  return popFront(l);
}

Value nth_nf(int argCount, Value *args) {
  if (NOT_COLLECTION_TYPES(args, 1) && IS_HASH_TABLE(args[0])) {
    runtimeError(
        "First argument must be an array, matrix, linked list or Vector.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be a number.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_MATRIX: {
    if (argCount == 3 && IS_PRIM_NUM(args[2])) {
      ObjMatrix *m = AS_MATRIX(args[0]);
      int row = AS_NUM_INT(args[1]);
      int col = AS_NUM_INT(args[2]);
      return getMatrix(m, row, col);
    }
    break;
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    int index = AS_NUM_INT(args[1]);
    double value = getFloatVector(f, index);
    return DOUBLE_VAL(value);
  }
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    int index = AS_NUM_INT(args[1]);
    if (index >= 0 && index < a->count) {
      return a->values[index];
    }
    break;
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    int index = AS_NUM_INT(args[1]);
    if (index >= 0 && index < l->count) {
      struct Node *node = l->head;
      for (int i = 0; i < index; i++) {
        node = node->next;
      }
      return node->data;
    }
    break;
  }
  default: {
    runtimeError("Invalid argument types or index out of bounds.");
    return NIL_VAL;
  }
  }
}

Value is_empty_nf(int argCount, Value *args) {
  if (NOT_COLLECTION_TYPES(args, 1)) {
    runtimeError("First argument must be a collection type.");
    return NIL_VAL;
  }
  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return BOOL_VAL(a->count == 0);
  }
  case OBJ_HASH_TABLE: {
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    return BOOL_VAL(h->table.count == 0);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return BOOL_VAL(f->count == 0);
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    return BOOL_VAL(l->count == 0);
  }
  default: {
    runtimeError("Unsupported type for is_empty().");
    return NIL_VAL;
  }
  }
}

Value sort_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be a list type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    sortArray(a);
    return NIL_VAL;
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    sortFloatVector(f);
    return NIL_VAL;
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    mergeSort(l);
    return NIL_VAL;
  }
  default: // unreachable
    break;
  }
}

Value equal_list_nf(int argCount, Value *args) {
  if (!IS_ARRAY(args[0]) && !IS_LINKED_LIST(args[0])) {
    runtimeError("First argument must be an array, linked list or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    if (!IS_ARRAY(args[1])) {
      runtimeError("Second argument must be an array.");
      return NIL_VAL;
    }
    ObjArray *a = AS_ARRAY(args[0]);
    ObjArray *b = AS_ARRAY(args[1]);
    return BOOL_VAL(equalArray(a, b));
  }
  case OBJ_FVECTOR: {
    if (!IS_FVECTOR(args[1])) {
      runtimeError("Second argument must be a vector.");
      return NIL_VAL;
    }
    FloatVector *a = AS_FVECTOR(args[0]);
    FloatVector *b = AS_FVECTOR(args[1]);
    return BOOL_VAL(equalFloatVector(a, b));
  }
  case OBJ_LINKED_LIST: {
    if (!IS_LINKED_LIST(args[1])) {
      runtimeError("Second argument must be a linked list.");
      return NIL_VAL;
    }
    ObjLinkedList *a = AS_LINKED_LIST(args[0]);
    ObjLinkedList *b = AS_LINKED_LIST(args[1]);
    return BOOL_VAL(equalLinkedList(a, b));
  }
  default: {
    runtimeError("Invalid argument type.");
    return NIL_VAL;
  }
  }
}

Value contains_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1) && !IS_HASH_TABLE(args[0])) {
    runtimeError("First argument must be an array, linked list or hash table.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    for (int i = 0; i < a->count; i++) {
      if (valuesEqual(a->values[i], args[1])) {
        return BOOL_VAL(true);
      }
    }
    return BOOL_VAL(false);
  }

  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    for (int i = 0; i < f->count; i++) {
      if (f->data[i] == AS_NUM_DOUBLE(args[1])) {
        return BOOL_VAL(true);
      }
    }
    return BOOL_VAL(false);
  }

  case OBJ_HASH_TABLE: {
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    if (!valuesEqual(getHashTable(h, AS_STRING(args[1])), NIL_VAL)) {
      return BOOL_VAL(true);
    } else {
      return BOOL_VAL(false);
    }
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    struct Node *current = l->head;
    while (current != NULL) {
      if (valuesEqual(current->data, args[1])) {
        return BOOL_VAL(true);
      }
      current = current->next;
    }
    return BOOL_VAL(false);
  }
  default: {
    runtimeError("Invalid argument type.");
    return NIL_VAL;
  }
  }
}

Value insert_nf(int argCount, Value *args) {
  if (argCount != 3) {
    runtimeError("insert() takes 3 arguments.");
    return NIL_VAL;
  }
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be a number.");
    return NIL_VAL;
  }
  switch (AS_OBJ(args[0])->type) {
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    int index = AS_NUM_INT(args[1]);
    if (!IS_PRIM_NUM(args[2])) {
      runtimeError("Third argument must be a number.");
      return NIL_VAL;
    }
    insertFloatVector(f, index, AS_NUM_DOUBLE(args[2]));
    return NIL_VAL;
  }
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    int index = AS_NUM_INT(args[1]);
    insertArray(a, index, args[2]);
    return NIL_VAL;
  }
  default:
    // Handle error or default case here
    break;
  }
}

Value len_nf(int argCount, Value *args) {
  if (NOT_COLLECTION_TYPES(args, 1)) {
    runtimeError("First argument must be a collection type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return INT_VAL(a->count);
  }

  case OBJ_MATRIX: {
    ObjMatrix *m = AS_MATRIX(args[0]);
    return INT_VAL(m->rows * m->cols);
  }

  case OBJ_HASH_TABLE: {
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    return INT_VAL(h->table.count);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return INT_VAL(f->count);
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    return INT_VAL(l->count);
  }
  default:
    break;
  }
}
Value range_nf(int argCount, Value *args) {
  if (!IS_PRIM_NUM(args[0]) && !IS_PRIM_NUM(args[1])) {
    runtimeError("Both arguments must be numbers.");
    return NIL_VAL;
  }
  int start = AS_NUM_INT(args[0]);
  int end = AS_NUM_INT(args[1]);
  ObjArray *a = newArrayWithCap(end - start, true);
  for (int i = start; i < end; i++) {
    pushArray(a, INT_VAL(i));
  }
  return OBJ_VAL(a);
}

Value slice_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be an array, linked list or vector.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[0]) && !IS_PRIM_NUM(args[1])) {
    runtimeError("Second and third arguments must be numbers.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    int start = AS_NUM_INT(args[1]);
    int end = AS_NUM_INT(args[2]);
    ObjArray *s = sliceArray(a, start, end);
    return OBJ_VAL(s);
  }

  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    int start = AS_NUM_INT(args[1]);
    int end = AS_NUM_INT(args[2]);
    FloatVector *s = sliceFloatVector(f, start, end);
    return OBJ_VAL(s);
  }

  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    int start = AS_NUM_INT(args[1]);
    int end = AS_NUM_INT(args[2]);
    ObjLinkedList *s = sliceLinkedList(l, start, end);
    return OBJ_VAL(s);
  }
  default:
    break;
  }
}

Value splice_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be an array, linked list or vector.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1]) || !IS_PRIM_NUM(args[2])) {
    runtimeError("Second and third arguments must be numbers.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    int start = AS_NUM_INT(args[1]);
    int end = AS_NUM_INT(args[2]);
    ObjArray *s = spliceArray(a, start, end);
    return OBJ_VAL(s);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    int start = AS_NUM_INT(args[1]);
    int end = AS_NUM_INT(args[2]);
    FloatVector *s = spliceFloatVector(f, start, end);
    return OBJ_VAL(s);
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    int start = AS_NUM_INT(args[1]);
    int end = AS_NUM_INT(args[2]);
    ObjLinkedList *s = spliceLinkedList(l, start, end);
    return OBJ_VAL(s);
  }

  default: // unreachable
    break;
  }
}

Value reverse_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be a list type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    reverseArray(a);
    return NIL_VAL;
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    reverseFloatVector(f);
    return NIL_VAL;
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    reverseLinkedList(l);
    return NIL_VAL;
  }
  default:
    break;
  }
}

Value search_nf(int argCount, Value *args) {
  if (NOT_LIST_TYPES(args, 1)) {
    runtimeError("First argument must be a list type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    int result = searchArray(a, args[1]);
    if (result == -1)
      return NIL_VAL;
    return INT_VAL(result);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    int result = searchFloatVector(f, AS_NUM_DOUBLE(args[1]));
    if (result == -1)
      return NIL_VAL;
    return INT_VAL(result);
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    int result = searchLinkedList(l, args[1]);
    if (result == -1)
      return NIL_VAL;
    return INT_VAL(result);
  }
  default:
    break;
  }
}

Value matrix_nf(int argCount, Value *args) {
  if (!IS_PRIM_NUM(args[0]) || !IS_PRIM_NUM(args[1])) {
    runtimeError("Both arguments must be numbers.");
    return NIL_VAL;
  }
  int rows = AS_NUM_INT(args[0]);
  int cols = AS_NUM_INT(args[1]);
  ObjMatrix *m = newMatrix(rows, cols);
  return OBJ_VAL(m);
}

Value set_row_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be an numbers.");
    return NIL_VAL;
  }
  if (!IS_ARRAY(args[2])) {
    runtimeError("Third argument must be an array.");
    return NIL_VAL;
  }

  ObjMatrix *matrix = AS_MATRIX(args[0]);
  int row = AS_NUM_INT(args[1]);
  ObjArray *array = AS_ARRAY(args[2]);

  setRow(matrix, row, array);
  return NIL_VAL;
}

Value set_col_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be an numbers.");
    return NIL_VAL;
  }
  if (!IS_ARRAY(args[2])) {
    runtimeError("Third argument must be an array.");
    return NIL_VAL;
  }

  ObjMatrix *matrix = AS_MATRIX(args[0]);
  int col = AS_NUM_INT(args[1]);
  ObjArray *array = AS_ARRAY(args[2]);

  setCol(matrix, col, array);
  return NIL_VAL;
}

Value set_nf(int argCount, Value *args) {
  if (argCount != 4) {
    runtimeError("set() takes 4 arguments.");
    return NIL_VAL;
  }

  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[1])) {
    runtimeError("Second argument must be an numbers.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[2])) {
    runtimeError("Third argument must be an numbers.");
    return NIL_VAL;
  }

  ObjMatrix *matrix = AS_MATRIX(args[0]);
  int row = AS_NUM_INT(args[1]);
  int col = AS_NUM_INT(args[2]);

  setMatrix(matrix, row, col, args[3]);
  return NIL_VAL;
}

Value kolasa_nf(int argCount, Value *args) {
  if (argCount != 0) {
    runtimeError("kolasa() takes no arguments.");
    return NIL_VAL;
  }
  ObjMatrix *m = newMatrix(3, 3);
  for (int i = 0; i < m->len; i++) {
    m->data->values[i] = DOUBLE_VAL((double)(i + 1));
  }
  return OBJ_VAL(m);
}

Value rref_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  ObjMatrix *m = AS_MATRIX(args[0]);
  rref(m);
  return NIL_VAL;
}

Value rank_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  ObjMatrix *m = AS_MATRIX(args[0]);
  return INT_VAL(rank(m));
}

Value transpose_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  ObjMatrix *m = AS_MATRIX(args[0]);
  ObjMatrix *t = transposeMatrix(m);
  return OBJ_VAL(t);
}

Value determinant_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  ObjMatrix *m = AS_MATRIX(args[0]);
  return DOUBLE_VAL(determinant(m));
}

Value fvector_nf(int argCount, Value *args) {
  if (argCount != 1) {
    runtimeError("fvec() takes 1 argument.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[0]) && !IS_ARRAY(args[0])) {
    runtimeError("First argument must be an numbers or an array.");
    return NIL_VAL;
  }

  if (IS_ARRAY(args[0])) {
    ObjArray *a = AS_ARRAY(args[0]);
    FloatVector *f = newFloatVector(a->capacity);
    for (int i = 0; i < a->count; i++) {
      if (!IS_PRIM_NUM(a->values[i])) {
        runtimeError("All elements of the vector must be numbers.");
        return NIL_VAL;
      }
      pushFloatVector(f, AS_NUM_DOUBLE(a->values[i]));
    }
    return OBJ_VAL(f);
  } else {
    int n = AS_NUM_INT(args[0]);
    FloatVector *f = newFloatVector(n);
    return OBJ_VAL(f);
  }
}

Value merge_nf(int argCount, Value *args) {
  if (argCount != 2) {
    runtimeError("merge() takes 2 arguments.");
    return NIL_VAL;
  }
  if (NOT_LIST_TYPES(args, 2)) {
    runtimeError("Both arguments must be the same list type.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    ObjArray *b = AS_ARRAY(args[1]);
    ObjArray *c = mergeArrays(a, b);
    return OBJ_VAL(c);
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *a = AS_LINKED_LIST(args[0]);
    ObjLinkedList *b = AS_LINKED_LIST(args[1]);
    ObjLinkedList *c = mergeLinkedList(a, b);
    return OBJ_VAL(c);
  }
  case OBJ_FVECTOR: {
    FloatVector *a = AS_FVECTOR(args[0]);
    FloatVector *b = AS_FVECTOR(args[1]);
    FloatVector *c = mergeFloatVector(a, b);
    return OBJ_VAL(c);
  }
  default:
    return NIL_VAL;
  }
}

Value clone_nf(int argCount, Value *args) {
  if (NOT_COLLECTION_TYPES(args, 1)) {
    runtimeError("First argument must be an array, linked list or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    ObjArray *c = cloneArray(a);
    return OBJ_VAL(c);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    FloatVector *c = cloneFloatVector(f);
    return OBJ_VAL(c);
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *l = AS_LINKED_LIST(args[0]);
    ObjLinkedList *c = cloneLinkedList(l);
    return OBJ_VAL(c);
  }
  case OBJ_HASH_TABLE: {
    ObjHashTable *h = AS_HASH_TABLE(args[0]);
    ObjHashTable *c = cloneHashTable(h);
    return OBJ_VAL(c);
  }
  default:
    runtimeError("Unsupported type for clone().");
    return NIL_VAL;
  }
}

Value clear_nf(int argCount, Value *args) {
  if (NOT_COLLECTION_TYPES(args, 1)) {
    runtimeError(
        "First argument must be an array, linked list, hash table or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY:
    clearArray(AS_ARRAY(args[0]));
    break;
  case OBJ_FVECTOR:
    clearFloatVector(AS_FVECTOR(args[0]));
    break;
  case OBJ_LINKED_LIST:
    clearLinkedList(AS_LINKED_LIST(args[0]));
    break;
  case OBJ_HASH_TABLE:
    clearHashTable(AS_HASH_TABLE(args[0]));
    break;
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }

  return NIL_VAL;
}

Value sum_nf(int argCount, Value *args) {
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return sumArray(a);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return DOUBLE_VAL(sumFloatVector(f));
  }
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }
}

Value mean_nf(int argCount, Value *args) {
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY:
    return meanArray(AS_ARRAY(args[0]));
  case OBJ_FVECTOR:
    return DOUBLE_VAL(meanFloatVector(AS_FVECTOR(args[0])));
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }
}

Value std_nf(int argCount, Value *args) {
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY:
    return stdDevArray(AS_ARRAY(args[0]));
  case OBJ_FVECTOR:
    return DOUBLE_VAL(stdDevFloatVector(AS_FVECTOR(args[0])));
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }
}

Value var_nf(int argCount, Value *args) {
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }
  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return varianceArray(a);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return DOUBLE_VAL(varianceFloatVector(f));
  }
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }
}

Value maxl_nf(int argCount, Value *args) {
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return maxArray(a);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return DOUBLE_VAL(maxFloatVector(f));
  }
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }
}

Value minl_nf(int argCount, Value *args) {
  if (NOT_ARRAY_TYPES(args, 1)) {
    runtimeError("First argument must be an array or vector.");
    return NIL_VAL;
  }

  switch (AS_OBJ(args[0])->type) {
  case OBJ_ARRAY: {
    ObjArray *a = AS_ARRAY(args[0]);
    return minArray(a);
  }
  case OBJ_FVECTOR: {
    FloatVector *f = AS_FVECTOR(args[0]);
    return DOUBLE_VAL(minFloatVector(f));
  }
  default:
    runtimeError("Unsupported type for clear().");
    return NIL_VAL;
  }
}

Value dot_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1])) {
    runtimeError("Both arguments must be vectors.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  double result = dotProduct(a, b);
  return DOUBLE_VAL(result);
}

Value cross_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1])) {
    runtimeError("Both arguments must be vectors.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  FloatVector *result = crossProduct(a, b);
  return OBJ_VAL(result);
}

Value norm_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0])) {
    runtimeError("First argument must be a vector.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *result = normalize(a);
  return OBJ_VAL(result);
}

Value proj_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1])) {
    runtimeError("Both arguments must be vectors.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  FloatVector *result = projection(a, b);
  return OBJ_VAL(result);
}

Value reflect_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1])) {
    runtimeError("Both arguments must be vectors.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  FloatVector *result = reflection(a, b);
  return OBJ_VAL(result);
}

Value reject_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1])) {
    runtimeError("Both arguments must be vectors.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  FloatVector *result = rejection(a, b);
  return OBJ_VAL(result);
}

Value refract_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1]) && !IS_PRIM_NUM(args[2]) &&
      !IS_PRIM_NUM(args[3])) {
    runtimeError("First and second arguments must be vectors and the third and "
                 "fourth arguments must be numbers.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  double n1 = AS_NUM_DOUBLE(args[2]);
  double n2 = AS_NUM_DOUBLE(args[3]);
  FloatVector *result = refraction(a, b, n1, n2);
  return OBJ_VAL(result);
}

Value angle_nf(int argCount, Value *args) {
  if (!IS_FVECTOR(args[0]) || !IS_FVECTOR(args[1])) {
    runtimeError("Both arguments must be vectors.");
    return NIL_VAL;
  }
  FloatVector *a = AS_FVECTOR(args[0]);
  FloatVector *b = AS_FVECTOR(args[1]);
  double result = angle(a, b);
  return DOUBLE_VAL(result);
}

Value workspace_nf(int argCount, Value *args) {
  if (argCount != 0) {
    runtimeError("workspace() takes no arguments.");
    return NIL_VAL;
  }
  struct Entry *e = entries_(&vm.globals);
  printf("Workspace:\n");
  for (int i = 0; i < vm.globals.capacity; i++) {
    if (e[i].key != NULL && !IS_NATIVE(e[i].value)) {
      printf("%s: ", e[i].key->chars);
      if (IS_MATRIX(e[i].value)) {
        printf("\n");
      }
      printValue(e[i].value);
      printf("\n");
    }
  }
  return NIL_VAL;
}

Value lu_nf(int argCount, Value *args) {
  if (!IS_MATRIX(args[0])) {
    runtimeError("First argument must be a matrix.");
    return NIL_VAL;
  }
  ObjMatrix *m = AS_MATRIX(args[0]);
  ObjMatrix *result = lu(m);
  return OBJ_VAL(result);
}

Value linspace_nf(int argCount, Value *args) {
  if (argCount != 3) {
    runtimeError("linspace() takes 3 arguments.");
    return NIL_VAL;
  }
  if (!IS_PRIM_NUM(args[0]) && !IS_PRIM_NUM(args[1]) && !IS_PRIM_NUM(args[2])) {
    runtimeError("First and second arguments must be numbers and the third "
                 "argument must be an numbers.");
    return NIL_VAL;
  }
  double start = AS_NUM_DOUBLE(args[0]);
  double end = AS_NUM_DOUBLE(args[1]);
  int n = AS_NUM_INT(args[2]);
  FloatVector *a = linspace(start, end, n);
  return OBJ_VAL(a);
}

Value interp1_nf(int argCount, Value *args) {
  if (argCount != 3) {
    runtimeError("interp1() takes 3 arguments.");
    return NIL_VAL;
  }
  if (!IS_FVECTOR(args[0]) && !IS_FVECTOR(args[1]) && !IS_PRIM_NUM(args[2])) {
    runtimeError("First and second arguments must be vectors and the third "
                 "argument must be a number.");
    return NIL_VAL;
  }

  FloatVector *x = AS_FVECTOR(args[0]);
  FloatVector *y = AS_FVECTOR(args[1]);
  double x0 = AS_NUM_DOUBLE(args[2]);
  double result = interp1(x, y, x0);
  return DOUBLE_VAL(result);
}

// Value solve_nf(int argCount, Value *args)
// {
//     if (argCount != 2)
//     {
//         runtimeError("solve() takes 2 arguments.");
//         return NIL_VAL;
//     }
//     if (!IS_MATRIX(args[0]) || !IS_ARRAY(args[1]))
//     {
//         runtimeError("First argument must be a matrix and the second argument
//         must be an array."); return NIL_VAL;
//     }
//     ObjMatrix *a = AS_MATRIX(args[0]);
//     ObjMatrix *b = AS_ARRAY(args[1]);
//     ObjMatrix *result = solveMatrix(a, b);
//     return OBJ_VAL(result);
// }
