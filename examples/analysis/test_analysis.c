// Example program demonstrating MufiZ Analysis API
// This shows how to use the LSP support functions for static analysis

#include "../../zig-out/include/mufiz.h"
#include <stdio.h>
#include <stdlib.h>

void test_basic_analysis(void) {
    printf("\n=== Test 1: Basic Analysis ===\n");
    
    // Create an analysis context
    void* ctx = mufiz_create_analysis_context();
    if (!ctx) {
        fprintf(stderr, "Failed to create analysis context\n");
        return;
    }
    
    // Parse some simple valid code
    const char* source = "var x = 10;\nvar y = 20;\nvar z = x + y;";
    if (mufiz_update_source(ctx, "test.mufi", source)) {
        printf("✓ Successfully parsed source\n");
    } else {
        printf("✗ Failed to parse source\n");
    }
    
    // Check for diagnostics
    int32_t diag_count = mufiz_get_diagnostic_count(ctx);
    printf("Diagnostics found: %d\n", diag_count);
    
    // Clean up
    mufiz_destroy_analysis_context(ctx);
}

void test_syntax_errors(void) {
    printf("\n=== Test 2: Syntax Error Detection ===\n");
    
    void* ctx = mufiz_create_analysis_context();
    if (!ctx) {
        fprintf(stderr, "Failed to create analysis context\n");
        return;
    }
    
    // Parse code with syntax errors
    const char* source = "var x = 10;\nvar y = x +;";  // Missing operand
    if (!mufiz_update_source(ctx, "error.mufi", source)) {
        printf("Parse returned failure (expected)\n");
    }
    
    // Get diagnostics
    int32_t diag_count = mufiz_get_diagnostic_count(ctx);
    printf("Found %d diagnostic(s):\n", diag_count);
    
    for (int32_t i = 0; i < diag_count; i++) {
        const MufizDiagnostic* diag = mufiz_get_diagnostic(ctx, i);
        if (diag) {
            const char* severity_str = 
                (diag->severity == MUFIZ_DIAGNOSTIC_ERROR) ? "ERROR" : "WARNING";
            printf("  [Line %d, Col %d] %s: %s\n",
                diag->range.start.line,
                diag->range.start.column,
                severity_str,
                diag->message);
        }
    }
    
    mufiz_destroy_analysis_context(ctx);
}

void test_completions(void) {
    printf("\n=== Test 3: Autocompletion ===\n");
    
    void* ctx = mufiz_create_analysis_context();
    if (!ctx) {
        fprintf(stderr, "Failed to create analysis context\n");
        return;
    }
    
    // Parse code with some symbols
    const char* source = 
        "var x = 10;\n"
        "var myVariable = 20;\n"
        "fn myFunction(a, b) {\n"
        "    return a + b;\n"
        "}\n";
    
    if (!mufiz_update_source(ctx, "complete.mufi", source)) {
        printf("Failed to parse source\n");
        mufiz_destroy_analysis_context(ctx);
        return;
    }
    
    // Get completions at a position
    int32_t completion_count = mufiz_compute_completions(ctx, 4, 10);
    printf("Found %d completion item(s):\n", completion_count);
    
    for (int32_t i = 0; i < completion_count; i++) {
        const MufizCompletionItem* item = mufiz_get_completion_item(ctx, i);
        if (item) {
            const char* kind_str;
            switch (item->kind) {
                case 1: kind_str = "Variable"; break;
                case 2: kind_str = "Function"; break;
                case 3: kind_str = "Struct"; break;
                default: kind_str = "Unknown"; break;
            }
            printf("  - %s (%s) [%s]\n", item->name, item->type_name, kind_str);
        }
    }
    
    mufiz_destroy_analysis_context(ctx);
}

void test_hover_info(void) {
    printf("\n=== Test 4: Hover Information ===\n");
    
    void* ctx = mufiz_create_analysis_context();
    if (!ctx) {
        fprintf(stderr, "Failed to create analysis context\n");
        return;
    }
    
    // Parse code
    const char* source = 
        "var myValue = 42;\n"
        "fn calculate(x, y) {\n"
        "    return x * y;\n"
        "}\n";
    
    if (!mufiz_update_source(ctx, "hover.mufi", source)) {
        printf("Failed to parse source\n");
        mufiz_destroy_analysis_context(ctx);
        return;
    }
    
    // Get hover info at position (line 0, column 5 - should be on "myValue")
    const MufizCompletionItem* hover = mufiz_get_hover_info(ctx, 0, 5);
    if (hover) {
        printf("Hover info at line 0, col 5:\n");
        printf("  Name: %s\n", hover->name);
        printf("  Type: %s\n", hover->type_name);
        if (hover->doc_string && hover->doc_string[0] != '\0') {
            printf("  Doc: %s\n", hover->doc_string);
        }
    } else {
        printf("No hover info found at position\n");
    }
    
    // Try hovering over function name (line 1, column 4)
    hover = mufiz_get_hover_info(ctx, 1, 4);
    if (hover) {
        printf("\nHover info at line 1, col 4:\n");
        printf("  Name: %s\n", hover->name);
        printf("  Type: %s\n", hover->type_name);
    } else {
        printf("\nNo hover info found at line 1, col 4\n");
    }
    
    mufiz_destroy_analysis_context(ctx);
}

void test_multiple_contexts(void) {
    printf("\n=== Test 5: Multiple Analysis Contexts ===\n");
    
    // Create two separate contexts
    void* ctx1 = mufiz_create_analysis_context();
    void* ctx2 = mufiz_create_analysis_context();
    
    if (!ctx1 || !ctx2) {
        fprintf(stderr, "Failed to create analysis contexts\n");
        if (ctx1) mufiz_destroy_analysis_context(ctx1);
        if (ctx2) mufiz_destroy_analysis_context(ctx2);
        return;
    }
    
    // Parse different code in each context
    mufiz_update_source(ctx1, "file1.mufi", "var x = 1;");
    mufiz_update_source(ctx2, "file2.mufi", "var y = 2;");
    
    int32_t diag1 = mufiz_get_diagnostic_count(ctx1);
    int32_t diag2 = mufiz_get_diagnostic_count(ctx2);
    
    printf("Context 1 diagnostics: %d\n", diag1);
    printf("Context 2 diagnostics: %d\n", diag2);
    
    // Clean up both contexts
    mufiz_destroy_analysis_context(ctx1);
    mufiz_destroy_analysis_context(ctx2);
    
    printf("✓ Multiple contexts handled successfully\n");
}

void test_null_safety(void) {
    printf("\n=== Test 6: NULL Safety ===\n");
    
    // Test functions with NULL context
    int32_t count = mufiz_get_diagnostic_count(NULL);
    printf("Diagnostic count with NULL context: %d (should be 0)\n", count);
    
    const MufizDiagnostic* diag = mufiz_get_diagnostic(NULL, 0);
    printf("Get diagnostic with NULL context: %s\n", diag ? "non-NULL" : "NULL (expected)");
    
    count = mufiz_compute_completions(NULL, 0, 0);
    printf("Completion count with NULL context: %d (should be 0)\n", count);
    
    const MufizCompletionItem* item = mufiz_get_completion_item(NULL, 0);
    printf("Get completion with NULL context: %s\n", item ? "non-NULL" : "NULL (expected)");
    
    const MufizCompletionItem* hover = mufiz_get_hover_info(NULL, 0, 0);
    printf("Get hover with NULL context: %s\n", hover ? "non-NULL" : "NULL (expected)");
    
    // Destroying NULL context should be safe
    mufiz_destroy_analysis_context(NULL);
    printf("✓ NULL context destroy is safe\n");
}

int main(void) {
    printf("MufiZ Analysis API Test Suite\n");
    printf("==============================\n");
    
    // Run all tests
    test_basic_analysis();
    test_syntax_errors();
    test_completions();
    test_hover_info();
    test_multiple_contexts();
    test_null_safety();
    
    printf("\n==============================\n");
    printf("All tests completed!\n");
    
    return 0;
}