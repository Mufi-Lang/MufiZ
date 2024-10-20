/*
 * File:   object.h
 * Author: Mustafif Khan
 * Brief:  Object Values in Mufi
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_object_h
#define mufi_object_h

#include "common.h"
#include "chunk.h"
#include "value.h"
#include "table.h"
#include <stdbool.h>

#ifdef __AVX2__
#include <immintrin.h>
#include <avx2intrin.h>
#endif

#ifdef __ARM_NEON
#include <arm_neon.h>
#endif

#define OBJ_TYPE(value) (AS_OBJ(value)->type)

#define IS_BOUND_METHOD(value) isObjType(value, OBJ_BOUND_METHOD)
#define IS_CLASS(value) isObjType(value, OBJ_CLASS)
#define IS_CLOSURE(value) isObjType(value, OBJ_CLOSURE)
#define IS_FUNCTION(value) isObjType(value, OBJ_FUNCTION)
#define IS_INSTANCE(value) isObjType(value, OBJ_INSTANCE)
#define IS_NATIVE(value) isObjType(value, OBJ_NATIVE)
#define IS_STRING(value) isObjType(value, OBJ_STRING)
#define IS_ARRAY(value) isObjType(value, OBJ_ARRAY)
#define IS_LINKED_LIST(value) isObjType(value, OBJ_LINKED_LIST)
#define IS_HASH_TABLE(value) isObjType(value, OBJ_HASH_TABLE)
#define IS_MATRIX(value) isObjType(value, OBJ_MATRIX)
#define IS_FVECTOR(value) isObjType(value, OBJ_FVECTOR)
#define IS_ITERATOR(value) isObjType(value, OBJ_ITERATOR)

#define NOT_ARRAY_TYPES(args, n) notObjTypes(args, OBJ_ARRAY, n) && notObjTypes(args, OBJ_FVECTOR, n)
#define NOT_LIST_TYPES(args, n) notObjTypes(args, OBJ_LINKED_LIST, n) && NOT_ARRAY_TYPES(args, n)
#define NOT_COLLECTION_TYPES(args, n) notObjTypes(args, OBJ_HASH_TABLE, n) && notObjTypes(args, OBJ_MATRIX, n) && NOT_LIST_TYPES(args, n)

#define AS_BOUND_METHOD(value) ((ObjBoundMethod *)AS_OBJ(value))
#define AS_CLASS(value) ((ObjClass *)AS_OBJ(value))
#define AS_CLOSURE(value) ((ObjClosure *)AS_OBJ(value))
#define AS_FUNCTION(value) ((ObjFunction *)AS_OBJ(value))
#define AS_INSTANCE(value) ((ObjInstance *)AS_OBJ(value))
#define AS_NATIVE(value) \
    (((ObjNative *)AS_OBJ(value))->function)
#define AS_STRING(value) ((ObjString *)AS_OBJ(value))
#define AS_CSTRING(value) (((ObjString *)AS_OBJ(value))->chars)
#define AS_ARRAY(value) ((ObjArray *)AS_OBJ(value))
#define AS_LINKED_LIST(value) ((ObjLinkedList *)AS_OBJ(value))
#define AS_HASH_TABLE(value) ((ObjHashTable *)AS_OBJ(value))
#define AS_MATRIX(value) ((ObjMatrix *)AS_OBJ(value))
#define AS_FVECTOR(value) ((FloatVector *)AS_OBJ(value))
#define AS_ITERATOR(value) ((ObjIterator *)AS_OBJ(value))

//> Object Type
//> An object type is a type of an object in Mufi
typedef enum
{
    OBJ_CLOSURE,
    OBJ_FUNCTION,
    OBJ_INSTANCE,
    OBJ_NATIVE,
    OBJ_STRING,
    OBJ_UPVALUE,
    OBJ_BOUND_METHOD,
    OBJ_CLASS,
    OBJ_ARRAY,
    OBJ_LINKED_LIST,
    OBJ_HASH_TABLE,
    OBJ_MATRIX,
    OBJ_FVECTOR,
    OBJ_ITERATOR,
} ObjType;

//> Object Structure
//> An object is a base structure for all objects in Mufi
struct Obj
{
    ObjType type;
    bool isMarked;
    struct Obj *next;
};

//> Node Object
//> A node is a single element in a linked list
struct Node
{
    Value data;
    struct Node *prev;
    struct Node *next;
};

//> Linked List Object
//> A doubly linked list is a collection of nodes
//> that are connected to each other
typedef struct
{
    Obj obj;
    struct Node *head;
    struct Node *tail;
    int count;
} ObjLinkedList;

//> Hash Table Object
//> A hash table is a collection of key-value pairs
typedef struct
{
    Obj obj;
    struct Table table;
} ObjHashTable;

//> Array Object
//> An array is a dynamic array or static array of values
//> We achieve dynamic or static using a `_static` flag
typedef struct
{
    Obj obj;
    int capacity;
    int count;
    bool _static;
    Value *values;
} ObjArray;

//> Matrix Object
//> A matrix is a multi-dimensional array of numbers
//> This type is similar to ObjArray but is used for matrix operations
typedef struct
{
    Obj obj;
    int rows;
    int cols;
    int len;
    ObjArray *data;
} ObjMatrix;

//> Float Vector Object
//> A float vector is a static array of floating point numbers
//> This type is similar to ObjArray but utilizes SIMD for faster operations
typedef struct
{
    Obj obj;
    int size;
    int count;
    double *data;
    bool sorted;
} FloatVector;

//> Function Object
//> A function is a block of code that can be called
typedef struct
{
    Obj obj;
    int arity;
    int upvalueCount;
    Chunk chunk;
    ObjString *name;
} ObjFunction;

typedef Value (*NativeFn)(int argCount, Value *args);

//> Native Function Object
//> A native function is a function that is implemented in C
typedef struct
{
    Obj obj;
    NativeFn function;
} ObjNative;

//> String Object
//> A string is a sequence of characters
struct ObjString
{
    Obj obj;
    int length;
    char *chars;
    uint64_t hash;
};

//> Upvalue Object
//> An upvalue is a variable that is captured by a closure
typedef struct ObjUpvalue
{
    Obj obj;
    Value *location;
    Value closed;
    struct ObjUpvalue *next;
} ObjUpvalue;

//> Closure Object
//> A closure is a function with its own environment
typedef struct
{
    Obj obj;
    ObjFunction *function;
    ObjUpvalue **upvalues;
    int upvalueCount;
} ObjClosure;

//> Class Object
//> A class is a user-defined type that can have methods and fields
typedef struct
{
    Obj obj;
    ObjString *name;
    struct Table methods;
} ObjClass;

//> Instance Object
//> An instance is an object that is an instance of a class
typedef struct
{
    Obj obj;
    ObjClass *klass;
    struct Table fields;
} ObjInstance;

//> Bound Method Object
//> A bound method is a method that is bound to an instance of a class
typedef struct
{
    Obj obj;
    Value receiver;
    ObjClosure *method;
} ObjBoundMethod;

typedef struct{
    FloatVector *vec;
    int pos;
}FloatVecIter;

typedef struct
{
    ObjArray *arr;
    int pos;
}ArrayIter;

typedef enum{
    FLOAT_VEC_ITER,
    ARRAY_ITER
}IterType;

typedef union{
    FloatVecIter* fvec;
    ArrayIter* arr;
}IterUnion;

//> Iterator Object
typedef struct{
    Obj obj;
    IterType type;
    IterUnion iter;
}ObjIterator;

/*-------------------------- Object Functions --------------------------------*/
ObjBoundMethod *newBoundMethod(Value receiver, ObjClosure *method);
ObjClass *newClass(ObjString *name);
ObjClosure *newClosure(ObjFunction *function);
ObjFunction *newFunction();
ObjInstance *newInstance(ObjClass *klass);
ObjNative *newNative(NativeFn function);
ObjString *allocateString(char *chars, int length, uint64_t hash);
uint64_t hashString(const char *key, int length);
ObjString *takeString(char *chars, int length);
ObjString *copyString(const char *chars, int length);
ObjUpvalue *newUpvalue(Value *slot);
/*----------------------------------------------------------------------------*/

/* ------------------------- Iterator Functions ----------------------------- */
FloatVecIter *newFloatVecIter(FloatVector *vec);
ArrayIter *newArrayIter(ObjArray *arr);

ObjIterator *newIterator(IterType type, IterUnion iter);
Value iteratorNext(ObjIterator *iter);
bool iteratorHasNext(ObjIterator *iter);
Value iteratorPeek(ObjIterator *iter, int pos);
void iteratorReset(ObjIterator *iter);
void iteratorSkip(ObjIterator *iter, int n);
void freeObjectIterator(ObjIterator *iter);
/*----------------------------------------------------------------------------*/

/*-------------------------- Array Functions --------------------------------*/
//> Merges two arrays into a new array
ObjArray *mergeArrays(ObjArray *a, ObjArray *b);
//> Clones an array into a new array
ObjArray *cloneArray(ObjArray *array);
//> Clears the array
void clearArray(ObjArray *array);
//> Pushes a value to the end of the array
//> If the array is static, it will not push the value
//> If the array is dynamic, it will resize the array if needed
//> Time Complexity: O(1)
void pushArray(ObjArray *array, Value value);
//> Inserts a value at a given index
//> Time Complexity: O(n)
void insertArray(ObjArray *array, int index, Value value);
//> Removes a value at a given index from the array
//> Time Complexity: O(n)
Value removeArray(ObjArray *array, int index);
//> Gets a value from the array at a given index
//> Time Complexity: O(1)
Value getArray(ObjArray *array, int index);
//> Removes a value at the end of the array
//> Time Complexity: O(1)
Value popArray(ObjArray *array);
//> Sorts the array using quick sort
//> Time Complexity:
//> Best Case: O(n log n)
//> Average Case: O(n log n)
//> Worst Case: O(n^2)
void sortArray(ObjArray *array);
//> Searches for a value in the array using binary search
//> Time Complexity:
//> Best Case: O(1)
//> Average Case: O(log n)
//> Worst Case: O(log n)
int searchArray(ObjArray *array, Value value);
//> Reverses the array
//> Time Complexity: O(n)
void reverseArray(ObjArray *array);
//> Checks if two arrays are equal
bool equalArray(ObjArray *a, ObjArray *b);
//> Frees the array
void freeObjectArray(ObjArray *array);
//> Slices the array from start to end
ObjArray *sliceArray(ObjArray *array, int start, int end);
//> Splices the array from start to end
ObjArray *spliceArray(ObjArray *array, int start, int end);
//> Adds two arrays together
//> Time Complexity: O(n)
ObjArray *addArray(ObjArray *a, ObjArray *b);
//> Subtracts two arrays
//> Time Complexity: O(n)
ObjArray *subArray(ObjArray *a, ObjArray *b);
//> Multiplies two arrays
//> Time Complexity: O(n)
ObjArray *mulArray(ObjArray *a, ObjArray *b);
//> Divides two arrays
//> Time Complexity: O(n)
ObjArray *divArray(ObjArray *a, ObjArray *b);
//> Sums the array
//> Time Complexity: O(n)
Value sumArray(ObjArray *array);
//> Finds the minimum value in the array
//> Time Complexity: O(n)
Value minArray(ObjArray *array);
//> Finds the maximum value in the array
//> Time Complexity: O(n)
Value maxArray(ObjArray *array);
//> Finds the mean of the array
//> Time Complexity: O(n)
Value meanArray(ObjArray *array);
//> Finds the variance of the array
//> Time Complexity: O(n)
Value varianceArray(ObjArray *array);
//> Finds the standard deviation of the array
//> Time Complexity: O(n)
Value stdDevArray(ObjArray *array);
//> Returns the length of the array
int lenArray(ObjArray *array);
//> Prints the array
void printArray(ObjArray *array);
//> Creates a new empty array
ObjArray *newArray();
//> Creates a new array with a given capacity and static flag
ObjArray *newArrayWithCap(int capacity, bool _static);
/*----------------------------------------------------------------------------*/

/*-------------------------- Linked List Functions ---------------------------*/
//> Creates a new empty linked list
ObjLinkedList *newLinkedList();
//> Clones a linked list into a new linked list
ObjLinkedList *cloneLinkedList(ObjLinkedList *list);
//> Clears the linked list
void clearLinkedList(ObjLinkedList *list);
//> Pushes a value to the front of the linked list
//> Time Complexity: O(1)
void pushFront(ObjLinkedList *list, Value value);
//> Pushes a value to the back of the linked list
//> Time Complexity: O(1)
void pushBack(ObjLinkedList *list, Value value);
//> Pops a value from the front of the linked list
//> Time Complexity: O(1)
Value popFront(ObjLinkedList *list);
//> Pops a value from the back of the linked list
//> Time Complexity: O(1)
Value popBack(ObjLinkedList *list);
//> Checks if two linked lists are equal
bool equalLinkedList(ObjLinkedList *a, ObjLinkedList *b);
//> Frees the linked list
void freeObjectLinkedList(ObjLinkedList *list);
//> Sorts the linked list using merge sort
//> Time Complexity:
//> Best Case: O(n log n)
//> Average Case: O(n log n)
//> Worst Case: O(n log n)
void mergeSort(ObjLinkedList *list);
//> Searches for a value in the linked list
//> Time Complexity:
//> Best Case: O(1)
//> Average Case: O(n)
//> Worst Case: O(n)
int searchLinkedList(ObjLinkedList *list, Value value);
//> Reverses the linked list
//> Time Complexity: O(n)
void reverseLinkedList(ObjLinkedList *list);
//> Merges two linked lists into a new linked list
ObjLinkedList *mergeLinkedList(ObjLinkedList *a, ObjLinkedList *b);
//> Slices the linked list from start to end
ObjLinkedList *sliceLinkedList(ObjLinkedList *list, int start, int end);
//> Splices the linked list from start to end
ObjLinkedList *spliceLinkedList(ObjLinkedList *list, int start, int end);
/*----------------------------------------------------------------------------*/

/*-------------------------- Hash Table Functions ----------------------------*/
//> Creates a new empty hash table
ObjHashTable *newHashTable();
//> Copies all hash entries from one table to the other
ObjHashTable *cloneHashTable(ObjHashTable *table);
//> Clears the hash table
void clearHashTable(ObjHashTable *table);
//> Puts a key-value pair in the hash table
bool putHashTable(ObjHashTable *table, ObjString *key, Value value);
//> Gets a value from the hash table
Value getHashTable(ObjHashTable *table, ObjString *key);
//> Removes a key-value pair from the hash table
bool removeHashTable(ObjHashTable *table, ObjString *key);
//> Frees the hash table
void freeObjectHashTable(ObjHashTable *table);
//> TODO: Merges two hash tables into a new hash table
ObjHashTable *mergeHashTable(ObjHashTable *a, ObjHashTable *b);
//> TODO: Returns the keys of the hash table
ObjArray *keysHashTable(ObjHashTable *table);
//> TODO: Returns the values of the hash table
ObjArray *valuesHashTable(ObjHashTable *table);
/*----------------------------------------------------------------------------*/

/*-------------------------- Matrix Functions --------------------------------*/
//> Creates a zero matrix with given rows and columns
ObjMatrix *newMatrix(int rows, int cols);
//> Prints the matrix
void printMatrix(ObjMatrix *matrix);
//> Sets a row in the matrix with an array and a given row index
void setRow(ObjMatrix *matrix, int row, ObjArray *values);
//> Sets a column in the matrix with an array and a given column index
void setCol(ObjMatrix *matrix, int col, ObjArray *values);
//> Sets a value in the matrix with a given row and column index
void setMatrix(ObjMatrix *matrix, int row, int col, Value value);
//> Gets a value in the matrix with a given row and column index
Value getMatrix(ObjMatrix *matrix, int row, int col);
//> Adds two matrices together
ObjMatrix *addMatrix(ObjMatrix *a, ObjMatrix *b);
//> Subtracts two matrices
ObjMatrix *subMatrix(ObjMatrix *a, ObjMatrix *b);
//> Multiplies two matrices
ObjMatrix *mulMatrix(ObjMatrix *a, ObjMatrix *b);
//> Divides two matrices
ObjMatrix *divMatrix(ObjMatrix *a, ObjMatrix *b);
//> Transposes the matrix
ObjMatrix *transposeMatrix(ObjMatrix *matrix);
//> Scales the matrix with a given scalar
ObjMatrix *scaleMatrix(ObjMatrix *matrix, Value scalar);
//> Swaps two rows in the matrix
void swapRows(ObjMatrix *matrix, int row1, int row2);
//> Finds the reduced row echelon form of the matrix
void rref(ObjMatrix *matrix);
//> Finds the rank of the matrix
int rank(ObjMatrix *matrix);
//> Finds the identity matrix of the given size
ObjMatrix *identityMatrix(int n);
//> Finds the LU decomposition of the matrix
ObjMatrix *lu(ObjMatrix *matrix);
//> Finds the determinant of the matrix
double determinant(ObjMatrix *matrix);
//> TODO: Inverse of the matrix
ObjMatrix *inverseMatrix(ObjMatrix *matrix);
//> TODO: Checks if two matrices are equal
bool equalMatrix(ObjMatrix *a, ObjMatrix *b);
//> Solves the matrix with a given vector (Broken)
ObjArray *solveMatrix(ObjMatrix *matrix, ObjArray *vector);
/*----------------------------------------------------------------------------*/

/*-------------------------- Float Vector Functions --------------------------*/
//> Creates a new empty float vector with a given size
FloatVector *newFloatVector(int size);
//> Copies the float vector into a new float vector
FloatVector *cloneFloatVector(FloatVector *vector);
//> Clears the float vector
void clearFloatVector(FloatVector *vector);
//> Frees the float vector
void freeFloatVector(FloatVector *vector);
//> Creates a new float vector from an array
FloatVector *fromArray(ObjArray *array);
//> Pushes a value to the end of the float vector
//> Time Complexity: O(1)
void pushFloatVector(FloatVector *vector, double value);
//> Inserts a value at a given index
//> Time Complexity: O(n)
void insertFloatVector(FloatVector *vector, int index, double value);
//> Gets a value from the float vector at a given index
//> Time Complexity: O(1)
double getFloatVector(FloatVector *vector, int index);
//> Removes a value at the end of the float vector
//> Time Complexity: O(1)
double popFloatVector(FloatVector *vector);
//> Removes a value at a given index from the float vector
//> Time Complexity: O(n)
double removeFloatVector(FloatVector *vector, int index);
//> Prints the float vector
void printFloatVector(FloatVector *vector);
//> Merges two float vectors into a new float vector
FloatVector *mergeFloatVector(FloatVector *a, FloatVector *b);
//> Slices the float vector from start to end
FloatVector *sliceFloatVector(FloatVector *vector, int start, int end);
//> Splices the float vector from start to end
FloatVector *spliceFloatVector(FloatVector *vector, int start, int end);
//> Sums the float vector
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
double sumFloatVector(FloatVector *vector);
//> Finds the mean of the float vector
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
double meanFloatVector(FloatVector *vector);
//> Finds the variance of the float vector
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
double varianceFloatVector(FloatVector *vector);
//> Finds the standard deviation of the float vector
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
double stdDevFloatVector(FloatVector *vector);
//> Finds the maximum value in the float vector
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
double maxFloatVector(FloatVector *vector);
//> Finds the minimum value in the float vector
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
double minFloatVector(FloatVector *vector);
//> Adds two float vectors together with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *addFloatVector(FloatVector *a, FloatVector *b);
//> Subtracts two float vectors with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *subFloatVector(FloatVector *a, FloatVector *b);
//> Multiplies two float vectors with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *mulFloatVector(FloatVector *a, FloatVector *b);
//> Divides two float vectors with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *divFloatVector(FloatVector *a, FloatVector *b);
//> Checks if two float vectors are equal
bool equalFloatVector(FloatVector *a, FloatVector *b);
//> Scales the float vector with a given scalar with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *scaleFloatVector(FloatVector *vector, double scalar);
//> Adds the float vector with a given value with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *singleAddFloatVector(FloatVector *a, double b);
//> Subtracts the float vector with a given value with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *singleSubFloatVector(FloatVector *a, double b);
//> Multiplies the float vector with a given value with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *singleMulFloatVector(FloatVector *a, double b);
//> Divides the float vector with a given value with SIMD if available
//> Time Complexity: O(n) without SIMD
//> Time Complexity: O(n/4) with SIMD
FloatVector *singleDivFloatVector(FloatVector *a, double b);
//> Sorts the float vector using quick sort
//> Time Complexity:
//> Best Case: O(n log n)
//> Average Case: O(n log n)
//> Worst Case: O(n^2)
void sortFloatVector(FloatVector *vector);
//> Reverses the float vector
//> Time Complexity: O(n)
void reverseFloatVector(FloatVector *vector);
//> Searches for a value in the float vector using binary search
//> Time Complexity:
//> Best Case: O(1)
//> Average Case: O(log n)
//> Worst Case: O(log n)
int searchFloatVector(FloatVector *vector, double value);
//> linearly spaced float vector
FloatVector *linspace(double start, double end, int n);
double interp1(FloatVector *x, FloatVector *y, double x0);
/*-------------------------- Float Vec3 Functions --------------------------*/
//> Calculates the dot product of two float vectors
double dotProduct(FloatVector *a, FloatVector *b);
//> Calculates the cross product of two float vectors
FloatVector *crossProduct(FloatVector *a, FloatVector *b);
//> Calculates the magnitude of the float vector
double magnitude(FloatVector *vector);
//> Normalizes the float vector
FloatVector *normalize(FloatVector *vector);
//> Calculates the angle between two float vectors
FloatVector *projection(FloatVector *a, FloatVector *b);
//> Calculates the rejection of two float vectors
FloatVector *rejection(FloatVector *a, FloatVector *b);
//> Calculates the reflection of two float vectors
FloatVector *reflection(FloatVector *a, FloatVector *b);
//> Calculates the refraction of two float vectors
FloatVector *refraction(FloatVector *a, FloatVector *b, double n1, double n2);
//> Calculates the angle between two float vectors
double angle(FloatVector *a, FloatVector *b);
/*----------------------------------------------------------------------------*/
//> Prints the object value
void printObject(Value value);

static inline bool isObjType(Value value, ObjType type)
{
    return IS_OBJ(value) && AS_OBJ(value)->type == type;
}

static inline bool notObjTypes(Value *value, ObjType type, int n)
{
    for (int i = 0; i < n; i++)
    {
        if (isObjType(value[i], type))
        {
            return false;
        }
    }
    return true;
}

#endif
