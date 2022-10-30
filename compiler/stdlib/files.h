#ifndef mufi_stdlib_files_h
#define mufi_stdlib_files_h

#include <stdio.h>
#include <stdlib.h>

void file_write(const char* path, const char* data);
const char* read_file(const char* path);
void file_append(const char* path, const char* data);
void new_dir(const char* path);

#endif