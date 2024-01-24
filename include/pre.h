#ifndef mufi_pre_h
#define mufi_pre_h

//> Major version of mufi
#define MAJOR 0
//> Minor version of mufi
#define MINOR 2
//> Patch version of mufi
#define PATCH 0
//> Codename of release
#define CODENAME "Zula"
//> Declares the version
#define VERSION() (printf("Version %d.%d.%d (%s Release)\n", MAJOR, MINOR, PATCH, CODENAME))

void repl();
char* readFile(const char* path);
void runFile(const char* path);
#endif