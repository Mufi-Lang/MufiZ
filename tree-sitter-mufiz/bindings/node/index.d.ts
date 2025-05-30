import { Parser, SyntaxNode } from "tree-sitter";

declare const parser: Parser.Language;
export = parser;

export interface MufizSyntaxNode extends SyntaxNode {
  type:
    | "source_file"
    | "expression_statement"
    | "variable_declaration"
    | "print_statement"
    | "if_statement"
    | "while_statement"
    | "for_statement"
    | "foreach_statement"
    | "function_declaration"
    | "class_declaration"
    | "return_statement"
    | "block_statement"
    | "assignment_expression"
    | "logical_or_expression"
    | "logical_and_expression"
    | "equality_expression"
    | "comparison_expression"
    | "addition_expression"
    | "multiplication_expression"
    | "unary_expression"
    | "call_expression"
    | "member_expression"
    | "index_expression"
    | "primary_expression"
    | "argument_list"
    | "vector_literal"
    | "hash_table_literal"
    | "hash_pair"
    | "linked_list_literal"
    | "parenthesized_expression"
    | "complex_number"
    | "identifier"
    | "number"
    | "string"
    | "escape_sequence"
    | "boolean"
    | "nil"
    | "self"
    | "super"
    | "comment"
    | "class_body"
    | "method_declaration"
    | "parameter_list"
    | "ERROR";
}

export interface NodeTypeInfo {
  [key: string]: {
    type: string;
    named: boolean;
    fields?: { [key: string]: any };
    children?: { [key: string]: any };
  };
}

export const nodeTypeInfo: NodeTypeInfo;