/*
 * File:   scanner.h
 * Author: Mustafif Khan
 * Brief:  Scanner bindings of libmufiz_scanner
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */

#ifndef mufi_scanner_h
#define mufi_scanner_h
enum TokenType
{
    // Single character tokens
    TOKEN_LEFT_PAREN,
    TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE,
    TOKEN_RIGHT_BRACE,
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_MINUS,
    TOKEN_PLUS,
    TOKEN_SEMICOLON,
    TOKEN_SLASH,
    TOKEN_STAR,
    TOKEN_PERCENT,
    // One or more character tokens
    TOKEN_BANG,
    TOKEN_BANG_EQUAL,
    TOKEN_EQUAL,
    TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER,
    TOKEN_GREATER_EQUAL,
    TOKEN_LESS,
    TOKEN_LESS_EQUAL,
    // Literals
    TOKEN_IDENTIFIER,
    TOKEN_STRING,
    TOKEN_DOUBLE,
    TOKEN_INT,
    // Keywords
    TOKEN_AND,
    TOKEN_CLASS,
    TOKEN_ELSE,
    TOKEN_FALSE,
    TOKEN_FOR,
    TOKEN_FUN,
    TOKEN_IF,
    TOKEN_LET,
    TOKEN_NIL,
    TOKEN_OR,
    TOKEN_PRINT,
    TOKEN_RETURN,
    TOKEN_SELF,
    TOKEN_SUPER,
    TOKEN_TRUE,
    TOKEN_VAR,
    TOKEN_WHILE,
    // Misc
    TOKEN_ERROR,
    TOKEN_EOF,
    // Assignment operators
    TOKEN_PLUS_EQUAL,
    TOKEN_MINUS_EQUAL,
    TOKEN_STAR_EQUAL,
    TOKEN_SLASH_EQUAL,
    TOKEN_PLUS_PLUS,
    TOKEN_MINUS_MINUS,
    TOKEN_HAT, // Exponent
    TOKEN_LEFT_SQPAREN, 
    TOKEN_RIGHT_SQPAREN,
};

struct Token
{
    enum TokenType type;
    const char *start;
    int length;
    int line;
};

struct Scanner
{
    const char *start;
    const char *current;
    int line;
};

extern void initScanner(const char *source);
extern struct Token scanToken();
extern bool isAtEnd();
extern bool isAlpha(char c);
extern bool isDigit(char c);
extern bool isDigit(char c);
extern char __scanner__advance();
extern char peek();
extern char peekNext();
extern bool __scanner__match(char expected);
extern struct Token makeToken(enum TokenType type_);
extern struct Token errorToken(const char *message);
extern void skipWhitespace();
extern enum TokenType checkKeyword(int start, int length, const char *rest, enum TokenType type_);
extern enum TokenType identifierType();
extern struct Token identifier();
extern struct Token __scanner__number();
extern struct Token __scanner__string();
#endif