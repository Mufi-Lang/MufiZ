#include <stdio.h>
#include <string.h>
#include "../include/pre.h"
#include "../include/common.h"
#include "../include/chunk.h"
#include "../include/debug.h"
#include "../include/vm.h"
//> Mufi read-eval-print-loop function

void repl(){
    char line [1024];
    VERSION();
    for(;;){
        printf("(mufi) >> ");
        if (!fgets(line, sizeof(line), stdin)){
            printf("\n");
            break;
        }
        interpret(line);
    }
}

//> From path reads files characters and returns it
char* readFile(const char* path){
    FILE* file = fopen(path, "rb");
    if (file == NULL){
        fprintf(stderr, "Could not open file \"%s\".\n", path);
        exit(74);
    }
    fseek(file, 0L, SEEK_END);
    size_t fileSize = ftell(file);
    rewind(file);

    char* buffer = (char*)malloc(fileSize+1);
    if (buffer == NULL){
        fprintf(stderr, "Not enough memory to read \"%s\".\n", path);
    }
    size_t bytesRead = fread(buffer, sizeof(char), fileSize, file);
    if (bytesRead < fileSize){
        fprintf(stderr, "Could not read file \"%s\".\n", path);
        exit(74);
    }
    buffer[bytesRead] = '\0';
    fclose(file);
    return buffer;
}


//> Runs the source code of a file
void runFile(const char* path){
    char* source = readFile(path);
    InterpretResult result = interpret(source);
    free(source);

    if(result ==  INTERPRET_COMPILE_ERROR) exit(65);
    if(result == INTERPRET_RUNTIME_ERROR) exit(70);
}