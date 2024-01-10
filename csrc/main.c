#include <stdio.h>
#include "../include/common.h"
#include "../include/chunk.h"
#include "../include/debug.h"
#include "../include/vm.h"
#include "../include/pre.h"

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
