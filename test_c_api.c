// Simple test program for MufiZ C API
#include <stdio.h>
#include <stdlib.h>
#include "include/mufiz.h"

int main(void) {
    printf("Testing MufiZ C API...\n");
    
    // Test 1: Initialize the library
    printf("Test 1: Initializing library...\n");
    int32_t result = mufiz_init(false, false, false);
    if (result != MUFIZ_OK) {
        fprintf(stderr, "Failed to initialize MufiZ: %d\n", result);
        return 1;
    }
    printf("  ✓ Library initialized successfully\n");
    
    // Test 2: Run a simple script
    printf("\nTest 2: Running simple script...\n");
    const char* script = "var x = 42; print(x);";
    uint8_t exit_code = mufiz_interpret(script);
    printf("  Script exit code: %d\n", exit_code);
    if (exit_code == 0) {
        printf("  ✓ Script executed successfully\n");
    } else {
        printf("  ✗ Script failed with code %d\n", exit_code);
    }
    
    // Test 3: Test string duplication
    printf("\nTest 3: Testing string utilities...\n");
    const char* original = "Hello from C!";
    char* duplicated = mufiz_strdup(original);
    if (duplicated == NULL) {
        fprintf(stderr, "Failed to duplicate string\n");
        mufiz_deinit();
        return 1;
    }
    printf("  Original: %s\n", original);
    printf("  Duplicated: %s\n", duplicated);
    printf("  ✓ String duplication works\n");
    mufiz_free_cstring(duplicated);
    
    // Test 4: Check for memory leaks
    printf("\nTest 4: Checking for memory leaks...\n");
    bool has_leaks = mufiz_has_memory_leaks();
    if (has_leaks) {
        printf("  ⚠ Memory leaks detected\n");
        mufiz_print_memory_stats();
    } else {
        printf("  ✓ No memory leaks detected\n");
    }
    
    // Test 5: Deinitialize
    printf("\nTest 5: Deinitializing library...\n");
    mufiz_deinit();
    printf("  ✓ Library deinitialized\n");
    
    // Test 6: Test double initialization error
    printf("\nTest 6: Testing double initialization error...\n");
    result = mufiz_init(false, false, false);
    if (result != MUFIZ_OK) {
        fprintf(stderr, "First init failed: %d\n", result);
        return 1;
    }
    result = mufiz_init(false, false, false);
    if (result == MUFIZ_ERR_ALREADY_INITIALIZED) {
        printf("  ✓ Correctly detected double initialization\n");
    } else {
        printf("  ✗ Failed to detect double initialization (got %d)\n", result);
    }
    mufiz_deinit();
    
    printf("\n=== All tests passed! ===\n");
    return 0;
}