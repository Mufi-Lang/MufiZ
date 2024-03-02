#include <stdio.h>
#include <stdlib.h>
#include <immintrin.h> // For SIMD intrinsics (requires appropriate hardware and compiler support)

void addArraysAVX2(float *arr1, float *arr2, float *result, size_t size) {
    #if defined(__AVX2__)
        for (size_t i = 0; i < size; i += 8) {
            __m256 simd_arr1 = _mm256_loadu_ps(&arr1[i]); // Load 8 floats from arr1
            __m256 simd_arr2 = _mm256_loadu_ps(&arr2[i]); // Load 8 floats from arr2
            __m256 simd_result = _mm256_add_ps(simd_arr1, simd_arr2); // SIMD addition
            _mm256_storeu_ps(&result[i], simd_result); // Store result back to memory
        }
    #else
        printf("AVX2 is not supported on this CPU.\n");
    #endif
}

int main() {
    // Example usage
    float arr1[15] = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0};
    float arr2[15] = {1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0, 2.0, 1.0};
    float result[15];

    addArraysAVX2(arr1, arr2, result, 15);

    printf("Result: ");
    for (size_t i = 0; i < 15; ++i) {
        printf("%.2f ", result[i]);
    }
    printf("\n");

    return 0;
}
