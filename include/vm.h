/* 
 * File:   vm.h
 * Author: Mustafif Khan
 * Brief:  The Virtual Machine Frontend of Mufi
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

//> Frontend of mufi
#ifndef mufi_vm_h
#define mufi_vm_h

#include "chunk.h"
#include "value.h"
#include "object.h"
#include "table.h"
#include "common.h"

#define FRAMES_MAX 64
#define STACK_MAX (FRAMES_MAX * UINT8_COUNT)

typedef struct {
    ObjClosure* closure;
    uint8_t* ip;
    Value* slots;
}CallFrame;

//> The runtime virtual machine
typedef struct {
    CallFrame frames[FRAMES_MAX];
    int frameCount;
    Chunk* chunk; // Contains a dynamic array of chunks
    uint8_t* ip; // Instruction pointer
    Value stack[STACK_MAX]; // The virtual machine's stack
    Value* stackTop; // Top of the stack, always point to where the next item should be pushed
    Table globals; // Hash table of all global variables inside the program
    Table strings; // Hash table of all strings in heap
    ObjString* initString;
    ObjUpvalue* openUpvalues; // open up values inside of closures
    size_t bytesAllocated; // bytes allocated by the vm
    size_t nextGC; // threshold for the garbage collector to be invoked
    Obj* objects; // Head of the object linked list
    int grayCount; // Count of objects marked grey
    int grayCapacity; // Capacity of the grayStack
    Obj** grayStack; // Array of objects
}VM;
//> Error result of virtual machine's interpretation
typedef enum {
    INTERPRET_OK,
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
}InterpretResult;

// Global vm variable
extern VM vm;

//> Initializes the VM
void initVM();
//> Deallocates the VM's resources
void freeVM();
//> Interprets and runs the code
InterpretResult interpret(const char* source);
//> Pushes a value to the stack
void push(Value value);
//> Pops a value off the stack
Value pop();
//> Defines a native function
void defineNative(const char* name, NativeFn function);

#endif
