#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <immintrin.h>

// Define Value type
typedef enum {
    VAL_BOOL,
    VAL_NIL,
    VAL_INT,
    VAL_DOUBLE,
    VAL_OBJ,
    VAL_COMPLEX,
} ValueType;

// Define Complex type
typedef struct {
    double r; 
    double i;
} Complex;

// Define Value type
typedef struct {
    ValueType type;
    union {
        bool boolean;
        double num_double;
        int num_int;
        void* obj; // Assuming Obj is a pointer type
        Complex complex;
    } as;
} Value;

// Define DynamicArray structure
typedef struct {
    Value *values;    // Pointer to the array data
    int size;    // Current size of the array
    int capacity;    // Capacity of the array
} DynamicArray;

// Function to initialize the dynamic array
void initDynamicArray(DynamicArray *arr, int capacity) {
    arr->values = (Value *)malloc(capacity * sizeof(Value));
    if (arr->values == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }
    arr->size = 0;
    arr->capacity = capacity;
}

// Function to free memory used by the dynamic array
void freeDynamicArray(DynamicArray *arr) {
    free(arr->values);
    arr->values = NULL;
    arr->size = arr->capacity = 0;
}

// Function to add two arrays using SIMD (AVX2)
void addArraysAVX2(DynamicArray *a, DynamicArray *b, DynamicArray *result) {

    if (a->size != b->size || a->size != result->size) {
        printf("Arrays must have the same size for addition.\n");
        return;
    }

    // Perform SIMD addition for VAL_DOUBLE values
    for (int i = 0; i < a->size; i += 4) {
        if (a->values[i].type == VAL_DOUBLE && b->values[i].type == VAL_DOUBLE) {
            // Load values from arrays
            __m256d simd_arr1 = _mm256_loadu_pd(&a->values[i].as.num_double);
            __m256d simd_arr2 = _mm256_loadu_pd(&b->values[i].as.num_double);
            __m256d simd_result = _mm256_add_pd(simd_arr1, simd_arr2);
            _mm256_storeu_pd(&result->values[i].as.num_double, simd_result);
        } else {
            // Perform scalar addition for other types
            for (int j = 0; j < 4; ++j) {
                if (a->values[i + j].type == VAL_DOUBLE) {
                    result->values[i + j].as.num_double = a->values[i + j].as.num_double;
                } else {
                    printf("Unsupported value type for SIMD addition.\n");
                    return;
                }
            }
        }
    }
}

int main() {
    // Example usage
    const int size = 8;
    DynamicArray arr1, arr2, result;
    initDynamicArray(&arr1, size);
    initDynamicArray(&arr2, size);
    initDynamicArray(&result, size);

    // Initialize arrays with sample data
    for (int i = 0; i < size; ++i) {
        Value val;
        val.type = VAL_DOUBLE;
        val.as.num_double = i;
        arr1.values[i] = val;

        val.as.num_double = i;
        arr2.values[i] = val;
    }
    arr1.size = arr2.size = result.size = size;

    // Add arrays using SIMD (AVX2)
    addArraysAVX2(&arr1, &arr2, &result);

    // Print result
    printf("Result: ");
    for (int i = 0; i < result.size; ++i) {
        printf("%.2f ", result.values[i].as.num_double);
    }
    printf("\n");

    // Free memory
    freeDynamicArray(&arr1);
    freeDynamicArray(&arr2);
    freeDynamicArray(&result);

    return 0;
}
