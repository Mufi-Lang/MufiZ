#!/usr/bin/env python3
"""
Generate a grammar file (EBNF) and a JSON manifest from the MufiZ parser implementation.

This is a best-effort generator that extracts:
 - token definitions (from src/scanner_optimized.zig)
 - keywords (from KEYWORD_TABLE in scanner)
 - precedence constants and the Pratt-style rule table (from src/compiler.zig)

The main output is:
 - docs/grammar.ebnf    (human-oriented EBNF grammar)
 - manifests/grammar.json (machine-friendly representation)

Usage:
    python3 tools/generate_grammar.py --ebnf docs/grammar.ebnf --json manifests/grammar.json

Notes:
 - The generated grammar is primarily intended for documentation and tooling.
 - The script synthesizes grammar rules from imperative parser code; please
   review and tweak the generated grammar if you need a strict formal grammar
   for other tooling (ANTLR, Bison, etc.).
"""

from __future__ import annotations

import argparse
import json
import os
import re
from typing import Dict, List, Optional, Tuple

ROOT_DIR = os.path.dirname(os.path.dirname(__file__))
SCANNER_PATH = os.path.join(ROOT_DIR, "src", "scanner_optimized.zig")
COMPILER_PATH = os.path.join(ROOT_DIR, "src", "compiler.zig")

# Small mapping of token names to their literal lexemes for nicer EBNF.
LITERAL_TOKEN_MAP: Dict[str, str] = {
    "TOKEN_LEFT_PAREN": "(",
    "TOKEN_RIGHT_PAREN": ")",
    "TOKEN_LEFT_BRACE": "{",
    "TOKEN_RIGHT_BRACE": "}",
    "TOKEN_COMMA": ",",
    "TOKEN_DOT": ".",
    "TOKEN_MINUS": "-",
    "TOKEN_PLUS": "+",
    "TOKEN_SEMICOLON": ";",
    "TOKEN_SLASH": "/",
    "TOKEN_STAR": "*",
    "TOKEN_PERCENT": "%",
    "TOKEN_BANG": "!",
    "TOKEN_BANG_EQUAL": "!=",
    "TOKEN_EQUAL": "=",
    "TOKEN_EQUAL_EQUAL": "==",
    "TOKEN_GREATER": ">",
    "TOKEN_GREATER_EQUAL": ">=",
    "TOKEN_LESS": "<",
    "TOKEN_LESS_EQUAL": "<=",
    "TOKEN_PLUS_EQUAL": "+=",
    "TOKEN_MINUS_EQUAL": "-=",
    "TOKEN_STAR_EQUAL": "*=",
    "TOKEN_SLASH_EQUAL": "/=",
    "TOKEN_PLUS_PLUS": "++",
    "TOKEN_MINUS_MINUS": "--",
    "TOKEN_HAT": "^",
    "TOKEN_LEFT_SQPAREN": "[",
    "TOKEN_RIGHT_SQPAREN": "]",
    "TOKEN_COLON": ":",
    "TOKEN_ARROW": "=>",
    "TOKEN_HASH": "#",
    "TOKEN_RANGE_EXCLUSIVE": "..",
    "TOKEN_RANGE_INCLUSIVE": "..=",
    "TOKEN_QUESTION": "?",
}


def read_file(path: str) -> str:
    with open(path, "r", encoding="utf-8") as fh:
        return fh.read()


def extract_token_enum(scanner_source: str) -> List[Tuple[str, int]]:
    """
    Extract (TOKEN_NAME, value) pairs from TokenType enum.
    """
    m = re.search(
        r"pub const TokenType = enum\(c_int\) \{(.*?)\};", scanner_source, re.S
    )
    if not m:
        raise RuntimeError("failed to find TokenType enum in scanner file")
    body = m.group(1)
    tokens: List[Tuple[str, int]] = []
    for line in body.splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        mm = re.match(r"(TOKEN_[A-Z0-9_]+)\s*=\s*([0-9]+)\s*,?", line)
        if mm:
            tokens.append((mm.group(1), int(mm.group(2))))
    return tokens


def extract_keyword_table(scanner_source: str) -> Dict[str, str]:
    """
    Extract entries from KEYWORD_TABLE as token->keyword string mapping.
    """
    m = re.search(r"const KEYWORD_TABLE = blk:\s*\{(.*?)\};", scanner_source, re.S)
    result: Dict[str, str] = {}
    if not m:
        return result
    body = m.group(1)
    for mm in re.finditer(
        r'\.\{\s*\.keyword\s*=\s*"([^"]+)"\s*,\s*\.token\s*=\s*\.(TOKEN_[A-Z_]+)', body
    ):
        kw, token = mm.group(1), mm.group(2)
        result[token] = kw
    return result


def extract_precedences(compiler_source: str) -> Dict[str, int]:
    precs: Dict[str, int] = {}
    for mm in re.finditer(
        r"pub const (PREC_[A-Z0-9_]+)\s*:\s*i32\s*=\s*([0-9]+);", compiler_source
    ):
        precs[mm.group(1)] = int(mm.group(2))
    return precs


def find_block(
    source: str, start_pat: str, open_char: str = "{", close_char: str = "}"
) -> Optional[str]:
    """
    Return the (balanced) contents inside the first block found after start_pat.
    """
    i = source.find(start_pat)
    if i == -1:
        return None
    j = source.find(open_char, i)
    if j == -1:
        return None
    depth = 1
    k = j + 1
    while k < len(source) and depth > 0:
        if source[k] == open_char:
            depth += 1
        elif source[k] == close_char:
            depth -= 1
        k += 1
    return source[j + 1 : k - 1]


def extract_getrule_cases(compiler_source: str) -> Dict[str, Dict[str, Optional[str]]]:
    """
    Parse the getRule switch body to extract, for each token:
      - prefix function (if any)
      - infix function (if any)
      - precedence symbol (e.g. PREC_CALL)
    Returns a mapping token_name -> { prefix, infix, precedence }.
    """
    body = find_block(compiler_source, "return switch (type_) {")
    if body is None:
        raise RuntimeError("failed to find getRule switch body")
    cases: Dict[str, Dict[str, Optional[str]]] = {}
    # Each case looks like: .TOKEN_NAME => ParseRule{ .prefix = &grouping, .infix = &call, .precedence = PREC_CALL },
    for mm in re.finditer(
        r"\.(TOKEN_[A-Z0-9_]+)\s*=>\s*ParseRule\s*\{(.*?)\}\s*,", body, re.S
    ):
        token_name = mm.group(1)
        inside = mm.group(2)
        prefix_m = re.search(r"\.prefix\s*=\s*&([A-Za-z0-9_]+)", inside)
        infix_m = re.search(r"\.infix\s*=\s*&([A-Za-z0-9_]+)", inside)
        prec_m = re.search(r"\.precedence\s*=\s*(PREC_[A-Z0-9_]+)", inside)
        cases[token_name] = {
            "prefix": prefix_m.group(1) if prefix_m else None,
            "infix": infix_m.group(1) if infix_m else None,
            "precedence": prec_m.group(1) if prec_m else None,
        }
    return cases


def token_to_lexeme(token_name: str, keywords: Dict[str, str]) -> str:
    if token_name in keywords:
        return '"' + keywords[token_name] + '"'
    if token_name in LITERAL_TOKEN_MAP:
        return '"' + LITERAL_TOKEN_MAP[token_name] + '"'
    # Fallback to token name (without TOKEN_)
    return token_name.replace("TOKEN_", "")


def bison_token_name(token_name: str) -> str:
    return token_name.replace("TOKEN_", "")


def is_single_char_literal(token_name: str) -> Optional[str]:
    lit = LITERAL_TOKEN_MAP.get(token_name)
    if lit and len(lit) == 1:
        return lit
    return None


def generate_ebnf(
    tokens: List[Tuple[str, int]],
    keywords: Dict[str, str],
    precedences: Dict[str, int],
    rules: Dict[str, Dict[str, Optional[str]]],
) -> str:
    """
    Produce a readable EBNF grammar as a string based on parsed info.
    This function synthesizes a classic precedence-based expression grammar
    using the precedence table and infix operator mappings.
    """
    # Build precedence order (ascending numeric)
    prec_order = sorted(precedences.items(), key=lambda kv: kv[1])
    prec_infix: Dict[str, List[str]] = {p: [] for p in precedences}
    for token, info in rules.items():
        if info.get("infix") and info.get("precedence"):
            prec_infix[info["precedence"]].append(token)

    lines: List[str] = []
    lines.append("# Auto-generated MufiZ grammar (EBNF)")
    lines.append("# Do not edit by hand; run tools/generate_grammar.py to regenerate.")
    lines.append("")
    lines.append("program = { declaration } EOF ;")
    lines.append("")
    lines.append(
        "declaration = class_decl | fun_decl | var_decl | const_decl | statement ;"
    )
    lines.append("")
    lines.append(
        'class_decl = "class" IDENTIFIER [ "<" IDENTIFIER ] "{" { method } "}" ;'
    )
    lines.append(
        'fun_decl = "fun" IDENTIFIER "(" [ parameters ] ")" "{" { declaration } "}" ;'
    )
    lines.append('var_decl = "var" IDENTIFIER [ "=" expression ] ";" ;')
    lines.append('const_decl = "const" IDENTIFIER "=" expression ";" ;')
    lines.append("")
    lines.append(
        "statement = print_stmt | for_stmt | foreach_stmt | if_stmt | return_stmt | break_stmt | continue_stmt | switch_stmt | while_stmt | block | expression_stmt ;"
    )
    lines.append('block = "{" { declaration } "}" ;')
    lines.append('expression_stmt = expression ";" ;')
    lines.append('print_stmt = "print" expression ";" ;')
    lines.append("")
    lines.append(
        'foreach_stmt = "foreach" "(" IDENTIFIER "in" expression ")" statement ;'
    )
    lines.append('if_stmt = "if" "(" expression ")" statement [ "else" statement ] ;')
    lines.append('return_stmt = "return" ( ";" | ( expression ";" ) ) ;')
    lines.append('break_stmt = "break" ";" ;')
    lines.append('continue_stmt = "continue" ";" ;')
    lines.append('while_stmt = "while" "(" expression ")" statement ;')
    lines.append("")
    lines.append(
        'switch_stmt = "switch" "(" expression ")" "{" { case_clause } [ default_clause ] "}" ;'
    )
    lines.append('case_clause = "case" expression "=>" ( block | expression ";" ) ;')
    lines.append('default_clause = "_" "=>" ( block | expression ";" ) ;')
    lines.append("")
    lines.append('parameters = IDENTIFIER { "," IDENTIFIER } ;')
    lines.append('argument_list = expression { "," expression } ;')
    lines.append("")

    # Expression precedence chain - synthesized
    lines.append("expression = assignment ;")
    lines.append('assignment = ternary [ "=" assignment ] ;')
    lines.append('ternary = or [ "?" expression ":" expression ] ;')
    lines.append('or = and { "or" and } ;')
    lines.append('and = equality { "and" equality } ;')

    eq_ops = [token_to_lexeme(t, keywords) for t in prec_infix.get("PREC_EQUALITY", [])]
    if eq_ops:
        lines.append(
            f"equality = comparison {{ ( {' | '.join(eq_ops)} ) comparison }} ;"
        )
    else:
        lines.append("equality = comparison ;")

    cmp_ops = [
        token_to_lexeme(t, keywords) for t in prec_infix.get("PREC_COMPARISON", [])
    ]
    if cmp_ops:
        lines.append(f"comparison = term {{ ( {' | '.join(cmp_ops)} ) term }} ;")
    else:
        lines.append("comparison = term ;")

    term_ops = [token_to_lexeme(t, keywords) for t in prec_infix.get("PREC_TERM", [])]
    if term_ops:
        lines.append(f"term = range {{ ( {' | '.join(term_ops)} ) range }} ;")
    else:
        lines.append("term = range ;")

    range_ops = [token_to_lexeme(t, keywords) for t in prec_infix.get("PREC_RANGE", [])]
    if range_ops:
        lines.append(f"range = factor {{ ( {' | '.join(range_ops)} ) factor }} ;")
    else:
        lines.append("range = factor ;")

    factor_ops = [
        token_to_lexeme(t, keywords) for t in prec_infix.get("PREC_FACTOR", [])
    ]
    if factor_ops:
        lines.append(f"factor = exponent {{ ( {' | '.join(factor_ops)} ) exponent }} ;")
    else:
        lines.append("factor = exponent ;")

    exp_ops = [
        token_to_lexeme(t, keywords) for t in prec_infix.get("PREC_EXPONENT", [])
    ]
    if exp_ops:
        lines.append(f"exponent = unary {{ ( {' | '.join(exp_ops)} ) unary }} ;")
    else:
        lines.append("exponent = unary ;")

    lines.append('unary = ( "!" | "-" ) unary | call ;')
    lines.append(
        'call = primary { "(" [ argument_list ] ")" | "." IDENTIFIER | "[" index_expr "]" } ;'
    )
    lines.append('index_expr = [ expression ] ( ":" [ expression ] )? ;')

    prim_parts = [
        "IDENTIFIER",
        "INT",
        "DOUBLE",
        "STRING",
        "MULTILINE_STRING",
        "BACKTICK_STRING",
        "F_STRING",
        "IMAGINARY",
        '"true"',
        '"false"',
        '"nil"',
        '"(" expression ")"',
        "object_literal",
        "float_vector",
        "hash_table",
    ]
    lines.append(f"primary = {' | '.join(prim_parts)} ;")
    lines.append("")
    lines.append(
        'object_literal = "{" ( ( STRING | IDENTIFIER ) ":" expression { "," ( STRING | IDENTIFIER ) ":" expression } )? "}" ;'
    )
    lines.append(
        'hash_table = "#" "{" ( ( STRING | IDENTIFIER ) ":" expression { "," ( STRING | IDENTIFIER ) ":" expression } )? "}" ;'
    )
    lines.append('float_vector = "{" ( expression { "," expression } )? "}" ;')
    lines.append("")
    lines.append("# Tokens (terminals)")
    lines.append("IDENTIFIER = /[A-Za-z_][A-Za-z0-9_]*/ ;")
    lines.append("INT = /[0-9]+/ ;")
    lines.append("DOUBLE = /[0-9]*\\.[0-9]+/ ;")
    lines.append('STRING = /"(\\\\.|[^"\\\\])*"/ ;')
    lines.append('MULTILINE_STRING = /"""(.*?)"""/s ;')
    lines.append("BACKTICK_STRING = /`([^`]*)`/ ;")
    lines.append('F_STRING = /f"(.*?)"/ ;')
    lines.append("IMAGINARY = /[0-9]+(\\.[0-9]+)?i/ ;")
    lines.append("")
    lines.append("# Keywords:")
    for tok, kw in sorted(keywords.items(), key=lambda x: x[1]):
        lines.append(f"# {kw} -> {tok}")

    return "\n".join(lines)


def generate_bison_and_lexer(
    tokens: List[Tuple[str, int]],
    keywords: Dict[str, str],
    precedences: Dict[str, int],
    rules: Dict[str, Dict[str, Optional[str]]],
) -> Tuple[str, str]:
    """
    Generate a Bison grammar (.y) and a Flex lexer (.l) skeleton.

    Returns: (grammar_y_text, lexer_l_text)
    """
    token_names = [t for (t, _) in tokens]

    # Decide which tokens should be declared as %token (keywords, literals, multi-char ops, primitives)
    tokens_to_declare: List[str] = []
    primitives = {
        "TOKEN_IDENTIFIER",
        "TOKEN_INT",
        "TOKEN_DOUBLE",
        "TOKEN_STRING",
        "TOKEN_MULTILINE_STRING",
        "TOKEN_BACKTICK_STRING",
        "TOKEN_F_STRING",
        "TOKEN_IMAGINARY",
    }
    for t in token_names:
        if t in primitives:
            tokens_to_declare.append(t)
            continue
        if t in keywords:
            tokens_to_declare.append(t)
            continue
        lit = LITERAL_TOKEN_MAP.get(t)
        if lit and len(lit) > 1:
            # multi-character operator/literal (=>, .., ..=, etc.)
            tokens_to_declare.append(t)
            continue
        # include some compound tokens heuristically
        if (
            t.endswith("PLUS_PLUS")
            or t.endswith("MINUS_MINUS")
            or t.endswith("PLUS_EQUAL")
            or t.endswith("MINUS_EQUAL")
            or t.endswith("STAR_EQUAL")
            or t.endswith("SLASH_EQUAL")
        ):
            if t not in tokens_to_declare:
                tokens_to_declare.append(t)

    # Build precedence groups from rules
    prec_groups: Dict[str, List[str]] = {}
    for t, info in rules.items():
        if info.get("infix") and info.get("precedence"):
            p = info["precedence"]
            prec_groups.setdefault(p, []).append(t)

    # Default associativity map (sane defaults)
    assoc_map = {
        "PREC_ASSIGNMENT": "%right",
        "PREC_TERNARY": "%right",
        "PREC_OR": "%left",
        "PREC_AND": "%left",
        "PREC_EQUALITY": "%left",
        "PREC_COMPARISON": "%left",
        "PREC_TERM": "%left",
        "PREC_RANGE": "%left",
        "PREC_FACTOR": "%left",
        "PREC_EXPONENT": "%right",
        "PREC_UNARY": "%right",
        "PREC_CALL": "%left",
        "PREC_INDEX": "%left",
    }

    header_lines: List[str] = []
    header_lines.append("/* Auto-generated Bison grammar for MufiZ. */")
    header_lines.append("%{")
    header_lines.append("#include <stdio.h>")
    header_lines.append("#include <stdlib.h>")
    header_lines.append('#include "grammar.tab.h"  /* generated by bison -d */')
    header_lines.append("extern int yylex(void);")
    header_lines.append("extern void yyerror(const char *s);")
    header_lines.append("%}")
    header_lines.append("")

    # Emit %union and typed token declarations (INT/DOUBLE/STRING/IDENTIFIER etc.)
    header_lines.append("%union {")
    header_lines.append("  long int_val;")
    header_lines.append("  double double_val;")
    header_lines.append("  char *str;")
    header_lines.append("}")
    # typed tokens
    if "TOKEN_INT" in tokens_to_declare:
        header_lines.append("%token <int_val> INT")
    if "TOKEN_DOUBLE" in tokens_to_declare:
        header_lines.append("%token <double_val> DOUBLE")
    string_types = [
        t
        for t in (
            "TOKEN_STRING",
            "TOKEN_MULTILINE_STRING",
            "TOKEN_BACKTICK_STRING",
            "TOKEN_F_STRING",
        )
        if t in tokens_to_declare
    ]
    if string_types:
        header_lines.append(
            "%token <str> " + " ".join(bison_token_name(t) for t in string_types)
        )
    if "TOKEN_IMAGINARY" in tokens_to_declare:
        header_lines.append("%token <double_val> IMAGINARY")
    if "TOKEN_IDENTIFIER" in tokens_to_declare:
        header_lines.append("%token <str> IDENTIFIER")
    # remaining tokens (untyped)
    rest_tokens = [
        bison_token_name(t)
        for t in tokens_to_declare
        if t
        not in {
            "TOKEN_INT",
            "TOKEN_DOUBLE",
            "TOKEN_STRING",
            "TOKEN_MULTILINE_STRING",
            "TOKEN_BACKTICK_STRING",
            "TOKEN_F_STRING",
            "TOKEN_IMAGINARY",
            "TOKEN_IDENTIFIER",
        }
    ]
    if rest_tokens:
        header_lines.append("%token " + " ".join(rest_tokens))

    # Precedence declarations (ascending numeric order)
    prec_order = sorted(precedences.items(), key=lambda kv: kv[1])
    for pname, _ in prec_order:
        if pname == "PREC_NONE" or pname == "PREC_PRIMARY":
            continue
        toks = prec_groups.get(pname, [])
        if not toks:
            continue
        rep_items: List[str] = []
        for tt in toks:
            sc = is_single_char_literal(tt)
            if sc:
                rep_items.append("'" + sc + "'")
            else:
                rep_items.append(bison_token_name(tt))
        assoc = assoc_map.get(pname, "%left")
        header_lines.append(f"{assoc} {' '.join(rep_items)}")

    header_lines.append("")
    header_lines.append("%start program")
    header_lines.append("")
    header_lines.append("%%")

    # Grammar rules (skeleton)
    rules_lines: List[str] = []
    rules_lines.append("program: declarations ;")
    rules_lines.append("")
    rules_lines.append("declarations: declarations declaration")
    rules_lines.append("           | /* empty */ ;")
    rules_lines.append("")
    rules_lines.append("declaration: class_decl")
    rules_lines.append("           | fun_decl")
    rules_lines.append("           | var_decl")
    rules_lines.append("           | const_decl")
    rules_lines.append("           | statement ;")
    rules_lines.append("")
    rules_lines.append("class_decl: CLASS IDENTIFIER opt_super '{' method_list '}' ;")
    rules_lines.append("opt_super: /* empty */ | '<' IDENTIFIER ;")
    rules_lines.append("method_list: method_list method | /* empty */ ;")
    rules_lines.append("method: IDENTIFIER function_body ;")
    rules_lines.append("")
    rules_lines.append("fun_decl: FUN IDENTIFIER '(' param_list ')' function_body ;")
    rules_lines.append("param_list: /* empty */ | parameters ;")
    rules_lines.append("parameters: IDENTIFIER | parameters ',' IDENTIFIER ;")
    rules_lines.append("function_body: '{' declarations '}' ;")
    rules_lines.append("var_decl: VAR IDENTIFIER opt_var_init ';' ;")
    rules_lines.append("opt_var_init: /* empty */ | '=' expression ;")
    rules_lines.append("const_decl: CONST IDENTIFIER '=' expression ';' ;")
    rules_lines.append("")
    rules_lines.append("statement: print_stmt")
    rules_lines.append("         | for_stmt")
    rules_lines.append("         | foreach_stmt")
    rules_lines.append("         | if_stmt")
    rules_lines.append("         | return_stmt")
    rules_lines.append("         | break_stmt")
    rules_lines.append("         | continue_stmt")
    rules_lines.append("         | switch_stmt")
    rules_lines.append("         | while_stmt")
    rules_lines.append("         | block")
    rules_lines.append("         | expression ';' ;")
    rules_lines.append("")
    rules_lines.append("block: '{' declarations '}' ;")
    rules_lines.append("print_stmt: PRINT expression ';' ;")
    rules_lines.append("return_stmt: RETURN ';' | RETURN expression ';' ;")
    rules_lines.append("break_stmt: BREAK ';' ;")
    rules_lines.append("continue_stmt: CONTINUE ';' ;")
    rules_lines.append(
        "foreach_stmt: FOREACH '(' IDENTIFIER IN expression ')' statement ;"
    )
    rules_lines.append("if_stmt: IF '(' expression ')' statement")
    rules_lines.append("       | IF '(' expression ')' statement ELSE statement ;")
    rules_lines.append("while_stmt: WHILE '(' expression ')' statement ;")
    rules_lines.append("")
    rules_lines.append("switch_stmt: SWITCH '(' expression ')' '{' switch_cases '}' ;")
    rules_lines.append("switch_cases: switch_cases switch_case | /* empty */ ;")
    rules_lines.append(
        "switch_case: CASE expression ARROW ( block | expression ';' ) ;"
    )
    rules_lines.append("switch_case: '_' ARROW ( block | expression ';' ) ;")
    rules_lines.append("")
    rules_lines.append("expression: assignment ;")
    rules_lines.append("assignment: ternary | ternary '=' assignment ;")
    rules_lines.append("ternary: or_expr | or_expr '?' expression ':' expression ;")
    rules_lines.append("number: INT { $$ = (double) $1.ival; }")
    rules_lines.append("      | DOUBLE { $$ = $1.dval; } ;")
    rules_lines.append("string_literal: STRING { $$ = $1.sval; } ;")
    rules_lines.append("or_expr: or_expr OR and_expr | and_expr ;")
    rules_lines.append("and_expr: and_expr AND equality | equality ;")
    rules_lines.append("equality: equality ( '==' | '!=' ) comparison | comparison ;")
    rules_lines.append(
        "comparison: comparison ( '>' | '>=' | '<' | '<=' ) term | term ;"
    )
    rules_lines.append("term: term ( '+' | '-' | ARROW ) range | range ;")
    rules_lines.append(
        "range: range ( RANGE_EXCLUSIVE | RANGE_INCLUSIVE ) factor | factor ;"
    )
    rules_lines.append("factor: factor ( '*' | '/' | '%' ) exponent | exponent ;")
    rules_lines.append("exponent: exponent '^' unary | unary ;")
    rules_lines.append("unary: '!' unary | '-' unary | call_expr ;")
    rules_lines.append("call_expr: primary call_suffix* ;")
    rules_lines.append(
        "call_suffix: '(' [ argument_list ] ')' | '.' IDENTIFIER | '[' expression ']' ;"
    )
    rules_lines.append(
        "/* Sample semantic actions for literals. Replace with actual AST/value construction logic. */"
    )
    rules_lines.append("primary:")
    rules_lines.append("    IDENTIFIER { /* yylval.str contains identifier name */ }")
    rules_lines.append('  | INT { printf("INT: %ld\\n", $1); }')
    rules_lines.append('  | DOUBLE { printf("DOUBLE: %f\\n", $1); }')
    rules_lines.append('  | STRING { printf("STRING: %s\\n", $1); free($1); }')
    rules_lines.append(
        '  | MULTILINE_STRING { printf("MLSTRING: %s\\n", $1); free($1); }'
    )
    rules_lines.append(
        '  | BACKTICK_STRING { printf("BACKTICK: %s\\n", $1); free($1); }'
    )
    rules_lines.append('  | F_STRING { printf("FSTRING: %s\\n", $1); free($1); }')
    rules_lines.append('  | IMAGINARY { printf("IMAG: %f\\n", $1); }')
    rules_lines.append("  | 'true' | 'false' | 'nil'")
    rules_lines.append("  | '(' expression ')' ")
    rules_lines.append("  | object_literal")
    rules_lines.append("  | float_vector ;")
    rules_lines.append("")
    rules_lines.append(
        "object_literal: '{' ( ( STRING | IDENTIFIER ) ':' expression ( ',' ( STRING | IDENTIFIER ) ':' expression )* )? '}' ;"
    )
    rules_lines.append("float_vector: '{' ( expression ( ',' expression )* )? '}' ;")

    trailer_lines: List[str] = []
    trailer_lines.append("%%")
    trailer_lines.append(
        'void yyerror(const char *s) { fprintf(stderr, "Parse error: %s\\n", s); }'
    )
    trailer_lines.append("int main(void) { return yyparse(); }")

    grammar_y = "\n".join(header_lines + rules_lines + trailer_lines)

    # Build a simple Flex lexer skeleton (best-effort)
    lex_lines: List[str] = []
    lex_lines.append("%{")
    lex_lines.append('#include "grammar.tab.h"')
    lex_lines.append("#include <string.h>")
    lex_lines.append("#include <stdlib.h>")
    lex_lines.append("%}")
    lex_lines.append("%option yylineno")
    lex_lines.append("")
    lex_lines.append("%%")
    lex_lines.append("[ \\t\\r\\n]+\\t\\t;")
    lex_lines.append("//.*\\t\\t;")
    lex_lines.append(
        r"""/#    { int nesting = 1; int c; while (nesting > 0) { c = input(); if (c == 0) break; if (c == '/') { int d = input(); if (d == '#') nesting++; else unput(d); } else if (c == '#') { int d = input(); if (d == '/') nesting--; else unput(d); } else if (c == '\n') ++yylineno; } }"""
    )
    # multi-char operators first
    lex_lines.append("..=" + "\t\treturn RANGE_INCLUSIVE;")
    lex_lines.append(".." + "\t\treturn RANGE_EXCLUSIVE;")
    lex_lines.append("=>" + "\t\treturn ARROW;")
    lex_lines.append("++" + "\t\treturn PLUS_PLUS;")
    lex_lines.append("--" + "\t\treturn MINUS_MINUS;")
    lex_lines.append("+=" + "\t\treturn PLUS_EQUAL;")
    lex_lines.append("-=" + "\t\treturn MINUS_EQUAL;")
    lex_lines.append("*=" + "\t\treturn STAR_EQUAL;")
    lex_lines.append("/=" + "\t\treturn SLASH_EQUAL;")
    lex_lines.append("==" + "\t\treturn EQUAL_EQUAL;")
    lex_lines.append("!=" + "\t\treturn BANG_EQUAL;")
    lex_lines.append(">=" + "\t\treturn GREATER_EQUAL;")
    lex_lines.append("<=" + "\t\treturn LESS_EQUAL;")
    lex_lines.append(
        r"[0-9]+\.[0-9]+\t\t{ yylval.double_val = atof(yytext); return DOUBLE; }"
    )
    lex_lines.append(
        r"[0-9]+i\t\t{ int n = yyleng; char *tmp = malloc(n); strncpy(tmp, yytext, n-1); tmp[n-1] = '\0'; yylval.double_val = atof(tmp); free(tmp); return IMAGINARY; }"
    )
    lex_lines.append(r"[0-9]+\t\t{ yylval.int_val = atol(yytext); return INT; }")
    lex_lines.append(
        r"\"([^\"\\]|\\.)*\"\t\t{ int n = yyleng; char *s = malloc(n-1); strncpy(s, yytext+1, n-2); s[n-2] = '\0'; yylval.str = s; return STRING; }"
    )
    lex_lines.append(
        r"""\"\"\"([\\s\\S]*?)\"\"\"    { /* rudimentary multiline string capture */ int n = yyleng; char *s = (char*)malloc(n-3); memcpy(s, yytext+3, n-6); s[n-6] = 0; yylval.str = s; return MULTILINE_STRING; }"""
    )
    lex_lines.append(
        r"""`([^`]*)`    { int n = yyleng; char *s = (char*)malloc(n-1); memcpy(s, yytext+1, n-2); s[n-2] = 0; yylval.str = s; return BACKTICK_STRING; }"""
    )
    lex_lines.append(
        """f"\t\t{ int c; size_t cap = 256; size_t pos = 0; char *buf = malloc(cap); while ((c = input()) != 0) { if (c == '\\\\') { int d = input(); if (d == 0) break; if (pos + 2 >= cap) { cap *= 2; buf = realloc(buf, cap); } buf[pos++] = '\\\\'; buf[pos++] = d; continue; } if (c == '\"') break; if (pos + 1 >= cap) { cap *= 2; buf = realloc(buf, cap); } buf[pos++] = c; } buf[pos] = 0; yylval.str = buf; return F_STRING; }"""
    )
    lex_lines.append(r"[A-Za-z_][A-Za-z0-9_]*\\t\\t{")
    # keyword checks
    for tok, kw in sorted(keywords.items(), key=lambda x: x[1]):
        bname = bison_token_name(tok)
        lex_lines.append(
            f'                    if (strcmp(yytext, "{kw}") == 0) return {bname};'
        )
    lex_lines.append(
        "                    char *s = strdup(yytext); yylval.str = s; return IDENTIFIER; }"
    )
    # single-char punctuation -> return ASCII code
    for t in token_names:
        sc = is_single_char_literal(t)
        if sc and sc not in ('\\"', "\\'"):
            lex_lines.append(f"\\\"{sc}\\\"\\t\\treturn '{sc}';")
    lex_lines.append(".\\t\\treturn yytext[0];")
    lex_lines.append("%%")
    lex_lines.append("int yywrap(void) { return 1; }")

    lexer_l = "\n".join(lex_lines)
    return grammar_y, lexer_l


def generate_json(
    tokens: List[Tuple[str, int]],
    keywords: Dict[str, str],
    precedences: Dict[str, int],
    rules: Dict[str, Dict[str, Optional[str]]],
) -> Dict:
    token_map = {k: v for (k, v) in tokens}
    token_info = {}
    for name, val in tokens:
        token_info[name] = {
            "value": val,
            "lexeme": keywords.get(name) or LITERAL_TOKEN_MAP.get(name) or None,
        }
    return {
        "tokens": token_info,
        "precedences": precedences,
        "rules": rules,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate EBNF grammar and JSON manifest for MufiZ."
    )
    parser.add_argument(
        "--ebnf",
        default=os.path.join(ROOT_DIR, "docs", "grammar.ebnf"),
        help="Path to output EBNF file",
    )
    parser.add_argument(
        "--json",
        default=os.path.join(ROOT_DIR, "manifests", "grammar.json"),
        help="Path to output JSON manifest",
    )
    parser.add_argument(
        "--bison",
        action="store_true",
        help="Also emit Bison (.y) and Flex (.l) skeletons in manifests/",
    )
    args = parser.parse_args()

    scanner_source = read_file(SCANNER_PATH)
    compiler_source = read_file(COMPILER_PATH)

    tokens = extract_token_enum(scanner_source)
    keywords = extract_keyword_table(scanner_source)
    precedences = extract_precedences(compiler_source)
    rules = extract_getrule_cases(compiler_source)

    ebnf_text = generate_ebnf(tokens, keywords, precedences, rules)
    json_obj = generate_json(tokens, keywords, precedences, rules)

    os.makedirs(os.path.dirname(args.ebnf), exist_ok=True)
    os.makedirs(os.path.dirname(args.json), exist_ok=True)

    with open(args.ebnf, "w", encoding="utf-8") as fh:
        fh.write(ebnf_text)

    with open(args.json, "w", encoding="utf-8") as fh:
        json.dump(json_obj, fh, indent=2)

    print(f"Wrote EBNF to {args.ebnf}")
    print(f"Wrote JSON manifest to {args.json}")

    if args.bison:
        grammar_y, lexer_l = generate_bison_and_lexer(
            tokens, keywords, precedences, rules
        )
        y_path = os.path.join(ROOT_DIR, "manifests", "grammar.y")
        l_path = os.path.join(ROOT_DIR, "manifests", "lexer.l")
        with open(y_path, "w", encoding="utf-8") as f:
            f.write(grammar_y)
        with open(l_path, "w", encoding="utf-8") as f:
            f.write(lexer_l)
        print(f"Wrote Bison grammar to {y_path}")
        print(f"Wrote Flex lexer skeleton to {l_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
