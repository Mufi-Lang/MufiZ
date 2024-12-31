#include "../include/value.h"
#include "../include/memory.h"
#include "../include/object.h"
#include <inttypes.h>
#include <stdio.h>
#include <string.h>

static double fabs(double x) { return x < 0 ? -x : x; }

// Creates a new empty array
void initValueArray(ValueArray *array) {
  array->values = NULL;
  array->capacity = 0;
  array->count = 0;
}

// Appends to the end of a value array
void writeValueArray(ValueArray *array, Value value) {
  // Checks if array is full
  if (array->capacity < array->count + 1) {
    int oldCapacity = array->capacity;
    array->capacity = GROW_CAPACITY(oldCapacity);
    array->values =
        GROW_ARRAY(Value, array->values, oldCapacity, array->capacity);
  }
  // Append to the array
  array->values[array->count] = value;
  array->count++;
}

// Deallocates the value array and creates an empty one
void freeValueArray(ValueArray *array) {
  FREE_ARRAY(Value, array->values, array->capacity);
  initValueArray(array);
}

// Prints a value
void printValue(Value value) {
  switch (value.type) {
  case VAL_BOOL:
    printf(AS_BOOL(value) ? "true" : "false");
    break;
  case VAL_NIL:
    printf("nil");
    break;
  case VAL_DOUBLE: {
    double val = AS_DOUBLE(value);
    if (fabs(val) < 1e-10) {
      val = 0.0;
    }
    printf("%g", val);
  } break;
  case VAL_INT:
    printf("%d", AS_INT(value));
    break;
  case VAL_COMPLEX: {
    Complex c = AS_COMPLEX(value);
    printf("%g + (%g)i", c.r, c.i);
    break;
  }
  case VAL_OBJ:
    printObject(value);
    break;
  }
}

bool valuesEqual(Value a, Value b) {
  if (a.type != b.type)
    return false;
  switch (a.type) {
  case VAL_BOOL:
    return AS_BOOL(a) == AS_BOOL(b);
  case VAL_NIL:
    return true;
  case VAL_INT:
    return AS_INT(a) == AS_INT(b);
  case VAL_DOUBLE:
    return AS_DOUBLE(a) == AS_DOUBLE(b);
  case VAL_OBJ: {
    Obj *obj_a = AS_OBJ(a);
    Obj *obj_b = AS_OBJ(b);
    if (obj_a->type != obj_b->type)
      return false;
    switch (obj_a->type) {
    case OBJ_STRING: {
      ObjString *str_a = AS_STRING(a);
      ObjString *str_b = AS_STRING(b);
      return str_a->length == str_b->length &&
             memcmp(str_a->chars, str_b->chars, str_a->length) == 0;
    }
    case OBJ_ARRAY: {
      ObjArray *arr_a = AS_ARRAY(a);
      ObjArray *arr_b = AS_ARRAY(b);
      if (arr_a->count != arr_b->count)
        return false;
      for (int i = 0; i < arr_a->count; i++) {
        if (!valuesEqual(arr_a->values[i], arr_b->values[i]))
          return false;
      }
      return true;
    }
    case OBJ_LINKED_LIST: {
      ObjLinkedList *list_a = AS_LINKED_LIST(a);
      ObjLinkedList *list_b = AS_LINKED_LIST(b);
      if (list_a->count != list_b->count)
        return false;
      struct Node *node_a = list_a->head;
      struct Node *node_b = list_b->head;
      while (node_a != NULL) {
        if (!valuesEqual(node_a->data, node_b->data))
          return false;
        node_a = node_a->next;
        node_b = node_b->next;
      }
      return true;
    }
    case OBJ_FVECTOR: {
      FloatVector *vec_a = AS_FVECTOR(a);
      FloatVector *vec_b = AS_FVECTOR(b);
      if (vec_a->count != vec_b->count)
        return false;
      for (int i = 0; i < vec_a->count; i++) {
        if (vec_a->data[i] != vec_b->data[i])
          return false;
      }
      return true;
    }
    }
  }
  case VAL_COMPLEX: {
    Complex c_a = AS_COMPLEX(a);
    Complex c_b = AS_COMPLEX(b);
    return c_a.r == c_b.r && c_a.i == c_b.i;
  }
  default:
    return false; // unreachable
  }
  return false;
}

int valueCompare(Value a, Value b) {
  if (a.type != b.type)
    return -1;
  switch (a.type) {
  case VAL_BOOL:
    return AS_BOOL(a) - AS_BOOL(b);
  case VAL_NIL:
    return 0;
  case VAL_INT: {
    int a1 = AS_INT(a);
    int b1 = AS_INT(b);
    if (a1 > b1)
      return 1;
    if (a1 < b1)
      return -1;
    if (a1 == b1)
      return 0;
    break;
  }
  case VAL_DOUBLE: {
    double a1 = AS_DOUBLE(a);
    double b1 = AS_DOUBLE(b);
    if (a1 > b1)
      return 1;
    if (a1 < b1)
      return -1;
    if (a1 == b1)
      return 0;
    break;
  }
  default:
    return -1; // unreachable
  }
  return -1;
}

char *valueToString(Value value) {
  switch (value.type) {
  case VAL_BOOL:
    return AS_BOOL(value) ? "true" : "false";
  case VAL_NIL:
    return "nil";
  case VAL_INT: {
    char *str = ALLOCATE(char, 100);
    sprintf(str, "%d", AS_INT(value));
    return str;
  }
  case VAL_DOUBLE: {
    char *str = ALLOCATE(char, 100);
    sprintf(str, "%g", AS_DOUBLE(value));
    return str;
  }
  case VAL_COMPLEX: {
    char *str = ALLOCATE(char, 100);
    Complex c = AS_COMPLEX(value);
    sprintf(str, "%g + (%g)i", c.r, c.i);
    return str;
  }
  case VAL_OBJ: {
    return "Object";
  }
  default:
    return NULL; // unreachable
  }
  return NULL;
}
