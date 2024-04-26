/* 
 * File:   value.h
 * Author: Mustafif Khan
 * Brief:  Mufi Data Type Values 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_value_h
#define mufi_value_h

#include "common.h"
#include <string.h>

typedef struct Obj Obj;
typedef struct ObjString ObjString;

typedef enum{
    VAL_BOOL,
    VAL_NIL,
    VAL_INT,
    VAL_DOUBLE,
    VAL_OBJ,
    VAL_COMPLEX, 
}ValueType;

typedef struct{
    double r; 
    double i;
} Complex;

typedef struct{
    ValueType type;
    union {
        bool boolean;
        double num_double;
        int num_int;
        Obj* obj;
        Complex complex; // will be purely handled with Zig 
    } as;
}Value;

#define IS_BOOL(value) ((value).type == VAL_BOOL)
#define IS_NIL(value)  ((value).type == VAL_NIL)
#define IS_INT(value)   ((value).type == VAL_INT)
#define IS_DOUBLE(value)  ((value).type == VAL_DOUBLE)
#define IS_OBJ(value) ((value).type == VAL_OBJ)
#define IS_COMPLEX(value) ((value).type == VAL_COMPLEX)

#define AS_OBJ(value)  ((value).as.obj)
#define AS_BOOL(value) ((value).as.boolean)
#define AS_INT(value) ((value).as.num_int)
#define AS_DOUBLE(value)  ((value).as.num_double)
#define AS_COMPLEX(value)   ((value).as.complex)

#define BOOL_VAL(value) ((Value){VAL_BOOL, {.boolean = value}})
#define NIL_VAL         ((Value){VAL_NIL, {.num_int = 0}})
#define INT_VAL(value) ((Value){VAL_INT, {.num_int = value}})
#define DOUBLE_VAL(value) ((Value){VAL_DOUBLE, {.num_double = value}})
#define OBJ_VAL(object)  ((Value){VAL_OBJ, {.obj = (Obj*)object}})
#define COMPLEX_VAL(c) ((Value){VAL_COMPLEX, {.complex = c}})

typedef struct {
    int capacity;
    int count;
    Value* values;
}ValueArray;

//> Evaluates if two values are equal to each other
bool valuesEqual(Value a, Value b);
int valueCompare(Value a, Value b);
//> Creates a new empty value array
void initValueArray(ValueArray* array);
//> Appends to the end of a value array
void writeValueArray(ValueArray* array, Value value);
//> Frees the memory of a value array
void freeValueArray(ValueArray* array);
//> Prints a value
void printValue(Value value);
char* valueToString(Value value);

#endif
