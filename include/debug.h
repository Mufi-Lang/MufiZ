/* 
 * File:   debug.h
 * Author: Mustafif Khan
 * Brief: Provides debugging by disassembling chunks 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_debug_h
#define mufi_debug_h

#include "chunk.h"

//> Disassembles a chunk, and prints its instructions
void disassembleChunk(Chunk* chunk, const char* name);
//> Disassembles an instruction with a given offset
int disassembleInstruction(Chunk* chunk, int offset);

#endif //MUFIC_DEBUG_H
