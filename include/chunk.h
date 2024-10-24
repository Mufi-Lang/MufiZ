/*
 * File:   chunk.h
 * Author: Mustafif Khan
 * Brief:  Bytecode chunk for VM
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

//> Chunk of bytecode in mufi
#ifndef mufi_chunk_h
#define mufi_chunk_h

#include "common.h"
#include "value.h"
//> Operation Code
typedef enum
{
    OP_CONSTANT,
    OP_NIL,
    OP_TRUE,
    OP_FALSE,
    OP_POP,
    OP_GET_LOCAL,
    OP_SET_LOCAL,
    OP_GET_GLOBAL,
    OP_DEFINE_GLOBAL,
    OP_SET_GLOBAL,
    OP_GET_UPVALUE,
    OP_SET_UPVALUE,
    OP_GET_PROPERTY,
    OP_SET_PROPERTY,
    OP_GET_SUPER,
    OP_INDEX_GET,
    OP_INDEX_SET,
    OP_EQUAL,
    OP_GREATER,
    OP_LESS,
    OP_ADD,
    OP_SUBTRACT,
    OP_MULTIPLY,
    OP_DIVIDE,
    OP_MODULO,
    OP_EXPONENT,
    OP_NOT,
    OP_NEGATE,
    OP_PRINT,
    OP_JUMP,
    OP_JUMP_IF_FALSE,
    OP_LOOP,
    OP_CALL,
    OP_INVOKE,
    OP_SUPER_INVOKE,
    OP_CLOSURE,
    OP_CLOSE_UPVALUE,
    OP_RETURN,
    OP_CLASS,
    OP_INHERIT,
    OP_METHOD,
    OP_ARRAY,
    OP_FVECTOR,
} OpCode;

//> Bytecode chunk, contains array of operation code
typedef struct
{
    int count;            // Number of allocated entries in use
    int capacity;         // Number of elements allocated
    uint8_t *code;        // Array of Opcode
    int *lines;           // Stores the line number parallel to the opcode
    ValueArray constants; // Constants pool
} Chunk;

//> Chunk constructor
void initChunk(Chunk *chunk);
//> Frees the memory of the  chunk
void freeChunk(Chunk *chunk);
//> Append to the chunk
void writeChunk(Chunk *chunk, uint8_t byte, int line);
//> Add constant to the chunk's constant pool
int addConstant(Chunk *chunk, Value value);
#endif