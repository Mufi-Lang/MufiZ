#include <stdio.h>
#include <string.h>

#include "../include/common.h"
#include "../include/scanner.h"


enum TokenType identifierType(){
    switch (scanner.start[0]) {
        case 'a': return checkKeyword(1,2,"nd", TOKEN_AND);
        case 'c': return checkKeyword(1, 4, "lass", TOKEN_CLASS);
        case 'e': return checkKeyword(1, 3, "lse", TOKEN_ELSE);
        case 'f':
            if (scanner.current - scanner.start > 1){
                switch (scanner.start[1]) {
                    case 'a': return checkKeyword(2, 3, "lse", TOKEN_FALSE);
                    case 'o': return checkKeyword(2, 1, "r", TOKEN_FOR);
                    case 'u': return checkKeyword(2, 1, "n", TOKEN_FUN);
                }
            }
            break;
        case 'i': return checkKeyword(1, 1, "f", TOKEN_IF);
        case 'l': return checkKeyword(1, 2, "et", TOKEN_LET);
        case 'n': return checkKeyword(1, 2, "il", TOKEN_NIL);
        case 'p': return checkKeyword(1, 4, "rint", TOKEN_PRINT);
        case 'r': return checkKeyword(1, 5, "eturn", TOKEN_RETURN);
        case 's': if (scanner.current - scanner.start > 1){
                switch (scanner.start[1]) {
                    case 'e': return checkKeyword(2, 2, "lf", TOKEN_SELF);
                    case 'u': return checkKeyword(2, 3, "per", TOKEN_SUPER);
                }
            }
            break;
        case 't': return checkKeyword(1, 3, "rue", TOKEN_TRUE);
        case 'v': return checkKeyword(1, 2, "ar", TOKEN_VAR);
        case 'w': return checkKeyword(1, 4, "hile", TOKEN_WHILE);
    }


    return TOKEN_IDENTIFIER;
}


struct Token identifier(){
    while(isAlpha(peek()) || isDigit(peek())) advance();
    return makeToken(identifierType());
}

struct Token number(){
    while(isDigit(peek())) advance();
    // Looking for double
    if(peek() == '.' && isDigit(peekNext())){
        // consume the "."
        advance();
        while(isDigit(peek())) advance();
        return makeToken(TOKEN_DOUBLE);
    }
    // if not we make it as an integer
    return makeToken(TOKEN_INT);
}

struct Token string(){
    while(peek() != '"' && !isAtEnd()){
        if(peek() == '\n') scanner.line++;
        advance();
    }
    if(isAtEnd()) return errorToken("Unterminated string.");
    // the closing quote
    advance();
    return makeToken(TOKEN_STRING);
}

struct Token scanToken(){
    skipWhitespace();
    scanner.start = scanner.current;
    if(isAtEnd()) return makeToken(TOKEN_EOF);

    char c = advance();
    if(isAlpha(c)) return identifier();
    if(isDigit(c)) return number();

    switch(c){
        case '(': return makeToken(TOKEN_LEFT_PAREN);
        case ')': return makeToken(TOKEN_RIGHT_PAREN);
        case '{': return makeToken(TOKEN_LEFT_BRACE);
        case '}': return makeToken(TOKEN_RIGHT_BRACE);
        case ';': return makeToken(TOKEN_SEMICOLON);
        case ',': return makeToken(TOKEN_COMMA);
        case '.': return makeToken(TOKEN_DOT);
        case '-': return makeToken(TOKEN_MINUS);
        case '+': return makeToken(TOKEN_PLUS);
        case '/': return makeToken(TOKEN_SLASH);
        case '*': return makeToken(TOKEN_STAR);
        case '!':
            return makeToken(match('=')? TOKEN_BANG_EQUAL: TOKEN_BANG);
        case '=':
            return makeToken(match('=')? TOKEN_EQUAL_EQUAL: TOKEN_EQUAL);
        case '<':
            return makeToken(match('=')? TOKEN_LESS_EQUAL: TOKEN_LESS);
        case '>':
            return makeToken(match('=')? TOKEN_GREATER_EQUAL: TOKEN_GREATER);
        case '"': return string();
    }

    return errorToken("Unexpected character.");
}