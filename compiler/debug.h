#ifndef mufi_debug_h
#define mufi_debug_h

#include "chunk.h"

//> Disassembles a chunk, and prints its instructions
void disassembleChunk(Chunk* chunk, const char* name);
//> Disassembles an instruction with a given offset
int disassembleInstruction(Chunk* chunk, int offset);

#endif //MUFIC_DEBUG_H
