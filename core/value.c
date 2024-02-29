#include <stdio.h>
#include <string.h>
#include <inttypes.h>
#include "../include/object.h"
#include "../include/value.h"
#include "../include/memory.h"

static double fabs(double x)
{
    return x < 0 ? -x : x;
}

// Creates a new empty array
void initValueArray(ValueArray *array)
{
    array->values = NULL;
    array->capacity = 0;
    array->count = 0;
}

// Appends to the end of a value array
void writeValueArray(ValueArray *array, Value value)
{
    // Checks if array is full
    if (array->capacity < array->count + 1)
    {
        int oldCapacity = array->capacity;
        array->capacity = GROW_CAPACITY(oldCapacity);
        array->values = GROW_ARRAY(Value, array->values, oldCapacity, array->capacity);
    }
    // Append to the array
    array->values[array->count] = value;
    array->count++;
}

// Deallocates the value array and creates an empty one
void freeValueArray(ValueArray *array)
{
    FREE_ARRAY(Value, array->values, array->capacity);
    initValueArray(array);
}

// Prints a value
void printValue(Value value)
{
    switch (value.type)
    {
    case VAL_BOOL:
        printf(AS_BOOL(value) ? "true" : "false");
        break;
    case VAL_NIL:
        printf("nil");
        break;
    case VAL_DOUBLE:
    {
        double val = AS_DOUBLE(value);
        if (fabs(val) < 1e-10)
        {
            val = 0.0;
        }
        printf("%g", val);
    }
    break;
    case VAL_INT:
        printf("%d", AS_INT(value));
        break;
    case VAL_COMPLEX:
    {
        Complex c = AS_COMPLEX(value);
        printf("%g + (%g)i", c.r, c.i);
        break;
    }
    case VAL_OBJ:
        printObject(value);
        break;
    }
}

bool valuesEqual(Value a, Value b)
{
    if (a.type != b.type)
        return false;
    switch (a.type)
    {
    case VAL_BOOL:
        return AS_BOOL(a) == AS_BOOL(b);
    case VAL_NIL:
        return true;
    case VAL_INT:
        return AS_INT(a) == AS_INT(b);
    case VAL_DOUBLE:
        return AS_DOUBLE(a) == AS_DOUBLE(b);
    case VAL_OBJ:
    {
        return AS_OBJ(a) == AS_OBJ(b);
    }
    case VAL_COMPLEX:
    {
        Complex c_a = AS_COMPLEX(a);
        Complex c_b = AS_COMPLEX(b);
        return c_a.r == c_b.r && c_a.i == c_b.i;
    }
    default:
        return false; // unreachable
    }
    return false;
}

int valueCompare(Value a, Value b)
{
    if (a.type != b.type)
        return -1;
    switch (a.type)
    {
    case VAL_BOOL:
        return AS_BOOL(a) - AS_BOOL(b);
    case VAL_NIL:
        return 0;
    case VAL_INT:
    {
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
    case VAL_DOUBLE:
    {
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