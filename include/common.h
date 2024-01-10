//> All common imports and preprocessor macros defined here 
#ifndef mufi_common_h 
#define mufi_common_h 

#include <stdbool.h>
#include <stddef.h>
#include<stdint.h>
#include <stdlib.h>

#define DEBUG_PRINT_CODE
#define DEBUG_TRACE_EXECUTION
#define DEBUG_STRESS_GC
#define DEBUG_LOG_GC

#define UINT8_COUNT (UINT8_MAX + 1)

#endif

// In production, we want these debugging to be off
#undef DEBUG_TRACE_EXECUTION
#undef DEBUG_PRINT_CODE
#undef DEBUG_STRESS_GC
#undef DEBUG_LOG_GC
