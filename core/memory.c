#include "../include/memory.h"
#include "../include/compiler.h"
#include "../include/vm.h"
#include <stdio.h>
#ifdef DEBUG_LOG_GC
#include "../include/debug.h"
#endif

#define GC_HEAP_GROW_FACTOR 2

GCData gcData = {GC_IDLE, 0, NULL};

void *reallocate(void *pointer, size_t oldSize, size_t newSize) {
  vm.bytesAllocated += newSize - oldSize;
  if (newSize > oldSize) {
#ifdef DEBUG_STRESS_GC
    collectGarbage();
#endif
  }

  if (vm.bytesAllocated > vm.nextGC) {
    collectGarbage();
  }

  if (newSize == 0) {
    free(pointer);
    return NULL;
  }

  void *result = realloc(pointer, newSize);
  if (result == NULL && newSize > 0) {
    fprintf(stderr,
            "Memory allocation failed. Attempted to allocate %zu bytes.\n",
            newSize);
    // Try to recover by running garbage collection
    collectGarbage();

    // Try allocation again
    result = realloc(pointer, newSize);

    if (result == NULL) {
      fprintf(stderr, "Critical error: Memory allocation failed after garbage "
                      "collection attempt\n");
      exit(1);
    }
  }

  return result;
}

void markObject(Obj *object) {
  if (object == NULL)
    return;
  if (object->isMarked)
    return;
#ifdef DEBUG_LOG_GC
  printf("%p mark ", (void *)object);
  printValue(OBJ_VAL(object));
  printf("\n");
#endif
  object->isMarked = true;
  if (vm.grayCapacity < vm.grayCount + 1) {
    vm.grayCapacity = GROW_CAPACITY(vm.grayCapacity);
    vm.grayStack =
        (Obj **)realloc(vm.grayStack, sizeof(Obj *) * vm.grayCapacity);
  }
  vm.grayStack[vm.grayCount++] = object;
  if (vm.grayStack == NULL)
    exit(1);
}

void markValue(Value value) {
  if (IS_OBJ(value))
    markObject(AS_OBJ(value));
}

static void markArray(ValueArray *array) {
  for (int i = 0; i < array->count; i++) {
    markValue(array->values[i]);
  }
}

static void blackenObject(Obj *object) {
#ifdef DEBUG_LOG_GC
  printf("%p blacken ", (void *)object);
  printValue(OBJ_VAL(object));
  printf("\n");
#endif
  switch (object->type) {
  case OBJ_BOUND_METHOD: {
    ObjBoundMethod *bound = (ObjBoundMethod *)object;
    markValue(bound->receiver);
    markObject((Obj *)bound->method);
    break;
  }
  case OBJ_CLASS: {
    ObjClass *klass = (ObjClass *)object;
    markObject((Obj *)klass->name);
    markTable(&klass->methods);
    break;
  }
  case OBJ_CLOSURE: {
    ObjClosure *closure = (ObjClosure *)object;
    markObject((Obj *)closure->function);
    for (int i = 0; i < closure->upvalueCount; i++) {
      markObject((Obj *)closure->upvalues[i]);
    }
    break;
  }
  case OBJ_FUNCTION: {
    ObjFunction *function = (ObjFunction *)object;
    markObject((Obj *)function->name);
    markArray(&function->chunk.constants);
    break;
  }
  case OBJ_INSTANCE: {
    ObjInstance *instance = (ObjInstance *)object;
    markObject((Obj *)instance->klass);
    markTable(&instance->fields);
    break;
  }
  case OBJ_UPVALUE:
    markValue(((ObjUpvalue *)object)->closed);
    break;
  case OBJ_ARRAY: {
    ObjArray *array = (ObjArray *)object;
    for (int i = 0; i < array->count; i++) {
      markValue(array->values[i]);
    }
    break;
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *linkedList = (ObjLinkedList *)object;
    struct Node *current = linkedList->head;
    while (current != NULL) {
      markValue(current->data);
      current = current->next;
    }
    break;
  }
  case OBJ_HASH_TABLE: {
    ObjHashTable *hashTable = (ObjHashTable *)object;
    markTable(&hashTable->table);
    break;
  }
  case OBJ_MATRIX: {
    ObjMatrix *matrix = (ObjMatrix *)object;
    for (int i = 0; i < matrix->len; i++) {
      markValue(matrix->data->values[i]);
    }
    break;
  }
  case OBJ_NATIVE:
  case OBJ_STRING:
  case OBJ_FVECTOR:
    break;
  }
}

static void freeObject(Obj *object) {
#ifdef DEBUG_LOG_GC
  printf("%p free type %d\n", (void *)object, object->type);
#endif
  switch (object->type) {
  case OBJ_BOUND_METHOD: {
    FREE(ObjBoundMethod, object);
    break;
  }
  case OBJ_CLASS: {
    ObjClass *klass = (ObjClass *)object;
    freeTable(&klass->methods);
    FREE(ObjClass, object);
    break;
  }
  case OBJ_CLOSURE: {
    ObjClosure *closure = (ObjClosure *)object;
    FREE_ARRAY(ObjUpvalue *, closure->upvalues, closure->upvalueCount);

    FREE(ObjClosure, object);
    break;
  }
  case OBJ_FUNCTION: {
    ObjFunction *function = (ObjFunction *)object;
    freeChunk(&function->chunk);
    FREE(ObjFunction, object);
    break;
  }
  case OBJ_INSTANCE: {
    ObjInstance *instance = (ObjInstance *)object;
    freeTable(&instance->fields);
    FREE(ObjInstance, object);
    break;
  }
  case OBJ_NATIVE:
    FREE(ObjNative, object);
    break;
  case OBJ_STRING: {
    ObjString *string = (ObjString *)object;
    FREE_ARRAY(char, string->chars, string->length + 1);
    FREE(ObjString, object);
    break;
  }
  case OBJ_UPVALUE: {
    FREE(ObjUpvalue, object);
    break;
  }
  case OBJ_ARRAY: {
    ObjArray *array = (ObjArray *)object;
    freeObjectArray(array);
    break;
  }
  case OBJ_LINKED_LIST: {
    ObjLinkedList *linkedList = (ObjLinkedList *)object;
    freeObjectLinkedList(linkedList);
    break;
  }
  case OBJ_HASH_TABLE: {
    ObjHashTable *hashTable = (ObjHashTable *)object;
    freeObjectHashTable(hashTable);
    break;
  }
  case OBJ_FVECTOR: {
    FloatVector *fvector = (FloatVector *)object;
    freeFloatVector(fvector);
    break;
  }
  // case OBJ_MATRIX:
  // {
  //     ObjMatrix *matrix = (ObjMatrix *)object;
  //     freeObjectArray(matrix->data);
  //     break;
  // }
  default:
    break;
  }
}

void freeObjects() {
  Obj *object = vm.objects;
  while (object != NULL) {
    Obj *next = object->next;
    freeObject(object);
    object = next;
  }
  free(vm.grayStack);
}

// static void markRoots() {
//   for (Value *slot = vm.stack; slot < vm.stackTop; slot++) {
//     markValue(*slot);
//   }
//   for (int i = 0; i < vm.frameCount; i++) {
//     markObject((Obj *)vm.frames[i].closure);
//   }
//   for (ObjUpvalue *upvalue = vm.openUpvalues; upvalue != NULL;
//        upvalue = upvalue->next) {
//     markObject((Obj *)upvalue);
//   }
//   markTable(&vm.globals);
//   markCompilerRoots();
//   markObject((Obj *)vm.initString);
// }

// static void traceReferences() {
//   while (vm.grayCount > 0) {
//     Obj *object = vm.grayStack[--vm.grayCount];
//     blackenObject(object);
//   }
// }

// static void sweep() {
//   Obj *previous = NULL;
//   Obj *object = vm.objects;
//   while (object != NULL) {
//     if (object->isMarked) {
//       object->isMarked = false;
//       previous = object;
//       object = object->next;
//     } else {
//       Obj *unreached = object;
//       object = object->next;
//       if (previous != NULL) {
//         previous->next = object;
//       } else {
//         vm.objects = object;
//       }
//       freeObject(unreached);
//     }
//   }
// }

void incrementalGC() {
  const int INCREMENT_LIMIT =
      500; // Adjust this value to balance GC work and program execution
  int workDone = 0;

  while (workDone < INCREMENT_LIMIT) {
    switch (gcData.state) {
    case GC_IDLE:
      // Start a new GC cycle
      gcData.state = GC_MARK_ROOTS;
      gcData.rootIndex = 0;
      gcData.sweepingObject = NULL;
      break;

    case GC_MARK_ROOTS:
      // Mark roots
      for (; gcData.rootIndex < (size_t)(vm.stackTop - vm.stack) &&
             workDone < INCREMENT_LIMIT;
           gcData.rootIndex++) {
        markValue(vm.stack[gcData.rootIndex]);
        workDone++;
      }

      if (gcData.rootIndex >= (size_t)(vm.stackTop - vm.stack)) {
        // Finished marking stack, mark other roots
        for (int i = 0; i < vm.frameCount; i++) {
          markObject((Obj *)vm.frames[i].closure);
        }
        markTable(&vm.globals);
        markTable(&vm.strings);
        markObject((Obj *)vm.initString);
        for (ObjUpvalue *upvalue = vm.openUpvalues; upvalue != NULL;
             upvalue = upvalue->next) {
          markObject((Obj *)upvalue);
        }

        gcData.state = GC_TRACING;
      }
      break;

    case GC_TRACING:
      // Trace references
      while (vm.grayCount > 0 && workDone < INCREMENT_LIMIT) {
        Obj *object = vm.grayStack[--vm.grayCount];
        blackenObject(object);
        workDone++;
      }
      if (vm.grayCount == 0) {
        gcData.state = GC_SWEEPING;
        gcData.sweepingObject = vm.objects;
      }
      break;

    case GC_SWEEPING:
      // Sweep unreachable objects
      while (gcData.sweepingObject != NULL && workDone < INCREMENT_LIMIT) {
        Obj *next = gcData.sweepingObject->next;
        if (!gcData.sweepingObject->isMarked) {
          freeObject(gcData.sweepingObject);
          vm.objects = next;
        } else {
          gcData.sweepingObject->isMarked = false;
        }
        gcData.sweepingObject = next;
        workDone++;
      }
      if (gcData.sweepingObject == NULL) {
        // Finished sweeping, GC cycle complete
        gcData.state = GC_IDLE;
        // Update GC threshold
        vm.nextGC = vm.bytesAllocated * GC_HEAP_GROW_FACTOR;
      }
      break;
    }

    if (gcData.state == GC_IDLE) {
      break; // GC cycle complete
    }
  }
}

void collectGarbage() {
#ifdef DEBUG_LOG_GC
  printf("-- gc begin\n");
  size_t before = vm.bytesAllocated;
#endif

  while (gcData.state != GC_IDLE) {
    incrementalGC();
  }

#ifdef DEBUG_LOG_GC
  printf("-- gc end\n");
  printf("   collected %zu bytes (from %zu to %zu) next at %zu\n",
         before - vm.bytesAllocated, before, vm.bytesAllocated, vm.nextGC);
#endif
}
