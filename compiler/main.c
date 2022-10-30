#include <stdio.h>
#include "common.h"
#include "chunk.h"
#include "debug.h"
#include "vm.h"
#include "pre.h"

int main(int argc, const char* argv[]){
    initVM();

    if(argc == 1){
        repl();
    } else if (argc == 2){
        if (*argv[1] == 'v'){
            VERSION();
	    exit(0);
        }
        runFile(argv[1]);
    } else {
        fprintf(stderr, "Usage: mufi <path>\n");
        exit(64);
    }

    freeVM();
    return 0;
}
