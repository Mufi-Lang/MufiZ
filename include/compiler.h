/* 
 * File:   compiler.h
 * Author: Mustafif Khan
 * Brief:  The bytecode compiler of Mufi
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_compiler_h
#define mufi_compiler_h

#include "chunk.h"
#include "object.h"
#include "vm.h"

ObjFunction* compile(const char* source);
void markCompilerRoots();
#endif