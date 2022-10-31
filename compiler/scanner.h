#ifndef mufi_scanner_h
#define mufi_scanner_h

typedef enum {
    // Single character tokens
    TOKEN_LEFT_PAREN, TOKEN_RIGHT_PAREN, TOKEN_LEFT_BRACE, TOKEN_RIGHT_BRACE,
    TOKEN_COMMA, TOKEN_DOT, TOKEN_MINUS, TOKEN_PLUS, TOKEN_SEMICOLON, TOKEN_SLASH, TOKEN_STAR,
    // One or more character tokens
    TOKEN_BANG, TOKEN_BANG_EQUAL, TOKEN_EQUAL, TOKEN_EQUAL_EQUAL,
    TOKEN_GREATER, TOKEN_GREATER_EQUAL, TOKEN_LESS, TOKEN_LESS_EQUAL,
    // Literals
    TOKEN_IDENTIFIER, TOKEN_STRING, TOKEN_DOUBLE, TOKEN_INT,
    // Keywords
    TOKEN_AND, TOKEN_CLASS, TOKEN_ELSE, TOKEN_FALSE, TOKEN_FOR,
    TOKEN_FUN, TOKEN_IF, TOKEN_LET, TOKEN_NIL, TOKEN_OR, TOKEN_PRINT,
    TOKEN_RETURN, TOKEN_SELF, TOKEN_SUPER, TOKEN_TRUE, TOKEN_VAR, TOKEN_WHILE,
    //Misc
    TOKEN_ERROR, TOKEN_EOF
}TokenType;


typedef struct {
    TokenType type; // Type of the token
    const char* start; // Start of the token
    int length; // Length of the lexeme
    int line; // Line it occurs in
}Token;


void initScanner(const char* source);
Token scanToken();

#endif