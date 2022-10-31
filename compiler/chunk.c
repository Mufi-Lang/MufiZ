#include <stdlib.h>

#include "chunk.h"
#include "memory.h"
#include "vm.h"
// Creates a new empty chunk
void initChunk(Chunk* chunk){
    // When initializing, everything starts at 0
    chunk->count = 0; 
    chunk->capacity = 0;
    chunk->code = NULL; // No opcode yet
    chunk->lines = NULL; // No lines yet
    initValueArray(&chunk->constants); // Initialize value array
}

// Deallocates the memory of the chunk, and make it empty
void freeChunk(Chunk* chunk){
    FREE_ARRAY(uint8_t, chunk->code, chunk->capacity); // Frees the opcode dynamic array
    FREE_ARRAY(int, chunk->lines, chunk->capacity); // Frees the lines dynamic array
    freeValueArray(&chunk->constants); // Frees all the constants
    initChunk(chunk); // Creates a new empty chunk
}

// Appends to the end of the chunk
void writeChunk(Chunk* chunk, uint8_t byte, int line ){
    // Checks if the capacity is full
    if (chunk->capacity < chunk->count + 1){
        int oldCapacity = chunk->capacity; // Copy old capacity 
        chunk->capacity = GROW_CAPACITY(oldCapacity); //  Grow capacity by a factor with the old capacity
        // Grow the array of opcode and copy elements from the 
        // old capacity to the new one 
        chunk->code = GROW_ARRAY(uint8_t, chunk->code, oldCapacity, chunk->capacity);
        chunk->lines = GROW_ARRAY(int, chunk->lines, oldCapacity, chunk->capacity);
    }
    chunk->code[chunk->count] = byte; // Add byte to the count since it will be +1 from the last entry position
    chunk->lines[chunk->count] = line; // Adds line to the end of the array
    chunk->count++; // Increment the count of the chunk 
}

// Adds a constant to the chunk's constant pool
int addConstant(Chunk* chunk, Value value){
    push(value);
    writeValueArray(&chunk->constants, value);
    pop();
    return chunk->constants.count - 1; // returns position of constant
}