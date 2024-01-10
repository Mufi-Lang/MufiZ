//> Manages memory allocation in mufi 
#ifndef mufi_memory_h 
#define mufi_memory_h 

#include "common.h"
#include "object.h"
//> Allocates a new array on the heap
#define ALLOCATE(type, count) \
    ((type*)reallocate(NULL, 0, sizeof(type) * (count)))
// To grow capacity we check if the capacity is less than 8,
// if so, we make it 8, if not we multiply the old capacity by 2.
//> Grows the capacity of dynamic arrays
#define GROW_CAPACITY(capacity) \
    ((capacity) < 8 ? 8: (capacity) * 2)

//> Reallocates a pointer to 0 or freeing the pointer by shrinking
#define FREE(type, pointer)     reallocate(pointer, sizeof(type), 0)

// Knowing what the new capacity is, we can also grow an array to the same capacity
//> Grows the array with a desired capacity
#define GROW_ARRAY(type, pointer, oldCount, newCount) \
        (type*)reallocate(pointer, sizeof(type) * oldCount, \
        sizeof(type) * (newCount))

//> Frees a dynamic array
#define FREE_ARRAY(type, pointer, oldCount) \
    reallocate(pointer, sizeof(type)*(oldCount), 0) \

//> Used to reallocate memory for arrays
void* reallocate(void* pointer, size_t oldSize, size_t newSize);
//> Marks a heap-allocated object
void markObject(Obj* object);
//> Marks values for the garbage collector
void markValue(Value value);
//> Used for the garbage collector to manage memory
void collectGarbage();
//> Frees objects (heap allocated values)
void freeObjects();
#endif