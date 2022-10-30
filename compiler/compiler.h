#ifndef mufi_compiler_h
#define mufi_compiler_h

#include "chunk.h"
#include "object.h"
#include "vm.h"

ObjFunction* compile(const char* source);
void markCompilerRoots();
#endif