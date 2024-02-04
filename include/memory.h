/* 
 * File:   memory.h
 * Author: Mustafif Khan
 * Brief:  Manages memory allocation/garbage collection 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */


//> Manages memory allocation in mufi 
#ifndef mufi_memory_h 
#define mufi_memory_h 

#include "common.h"
#include "object.h"

// extern void markArray(array: *ValueArray);
// extern void markObject(object: *Obj);
// extern void markValue(value: Value);
// extern void collectGarbage();
// extern void freeObjects();
// extern void blackenObject(object: *Obj);
// extern void freeObject(object: *Obj);
// extern void markRoots();
// extern void traceReferences();
// extern void sweep();
// extern *void reallocate(void* pointer, size_t oldSize, size_t newSize);
// extern int GROW_CAPACITY(capacity: int);
// extern void* FREE(void* type, void* pointer);
// extern void* FREE_ARRAY(void* type, void* pointer, int oldCount);

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