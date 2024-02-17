/* 
 * File:   pre.h
 * Author: Mustafif Khan
 * Brief:  Prelude of Mufi 
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_pre_h
#define mufi_pre_h

//> Major version of mufi
#define MAJOR 0
//> Minor version of mufi
#define MINOR 4
//> Patch version of mufi
#define PATCH 0
//> Codename of release
#define CODENAME "Voxl"
//> Declares the version
#define VERSION() (printf("Version %d.%d.%d (%s Release)\n", MAJOR, MINOR, PATCH, CODENAME))

void repl();
char* readFile(const char* path);
void runFile(const char* path);
#endif