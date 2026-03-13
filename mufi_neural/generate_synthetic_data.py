import json
import os
import random
import sys

# Load Standard Library
STDLIB_PATH = "../mufiz_stdlib.json"
try:
    with open(STDLIB_PATH, "r") as f:
        STDLIB = json.load(f)["stdlib"]
except FileNotFoundError:
    print(f"Error: Could not find {STDLIB_PATH}")
    sys.exit(1)

# Keywords and Tokens
KEYWORDS = [
    "var",
    "const",
    "fun",
    "return",
    "if",
    "else",
    "while",
    "for",
    "foreach",
    "break",
    "continue",
    "print",
    "true",
    "false",
    "nil",
    "class",
]

OPERATORS = ["+", "-", "*", "/", "%", "==", "!=", "<", ">", "<=", ">=", "and", "or"]


# Generators
class CodeGenerator:
    def __init__(self):
        self.variables = []
        self.functions = []
        self.indent_level = 0
        self.depth = 0
        self.max_depth = 5

    def indent(self):
        return "  " * self.indent_level

    def generate_program(self, num_statements=10):
        code = []
        for _ in range(num_statements):
            stmt = self.generate_statement()
            if stmt:
                code.append(stmt)
        return "\n".join(code)

    def generate_statement(self):
        if self.depth > self.max_depth:
            return self.generate_expression_stmt()

        options = [
            self.generate_var_decl,
            self.generate_if_stmt,
            self.generate_while_stmt,
            self.generate_print_stmt,
            self.generate_expression_stmt,
        ]

        # Give higher weight to simpler statements to avoid deep nesting explosion
        weights = [0.3, 0.15, 0.1, 0.15, 0.3]

        choice = random.choices(options, weights=weights, k=1)[0]
        return choice()

    def generate_block(self):
        self.indent_level += 1
        self.depth += 1
        num_stmts = random.randint(1, 4)
        stmts = []
        for _ in range(num_stmts):
            stmts.append(self.indent() + self.generate_statement())
        self.indent_level -= 1
        self.depth -= 1
        return "{\n" + "\n".join(stmts) + "\n" + self.indent() + "}"

    def generate_var_decl(self):
        var_name = f"v_{random.randint(0, 1000)}"
        expr = self.generate_expression()
        self.variables.append(var_name)
        return f"var {var_name} = {expr};"

    def generate_if_stmt(self):
        cond = self.generate_expression()
        block = self.generate_block()
        stmt = f"if ({cond}) {block}"
        if random.random() < 0.3:
            else_block = self.generate_block()
            stmt += f" else {else_block}"
        return stmt

    def generate_while_stmt(self):
        cond = self.generate_expression()
        block = self.generate_block()
        return f"while ({cond}) {block}"

    def generate_print_stmt(self):
        expr = self.generate_expression()
        return f"print {expr};"

    def generate_expression_stmt(self):
        expr = self.generate_expression()
        return f"{expr};"

    def generate_expression(self, depth=0):
        if depth > 3:
            return self.generate_atom()

        options = ["binary", "call", "atom"]
        choice = random.choice(options)

        if choice == "binary":
            op = random.choice(OPERATORS)
            lhs = self.generate_expression(depth + 1)
            rhs = self.generate_expression(depth + 1)
            return f"{lhs} {op} {rhs}"
        elif choice == "call":
            return self.generate_call()
        else:
            return self.generate_atom()

    def generate_call(self):
        # Pick a random stdlib function
        category = random.choice(list(STDLIB.keys()))
        func_name = random.choice(STDLIB[category])

        # Retry if func_name is a keyword
        while func_name in KEYWORDS:
            category = random.choice(list(STDLIB.keys()))
            func_name = random.choice(STDLIB[category])

        # Simple argument generation (0 to 3 args)
        num_args = random.randint(0, 3)
        args = [self.generate_expression(depth=3) for _ in range(num_args)]
        return f"{func_name}({', '.join(args)})"

    def generate_atom(self):
        options = ["number", "string", "bool", "variable"]
        choice = random.choice(options)

        if choice == "number":
            return str(random.randint(0, 100))
        elif choice == "string":
            return f'"{random.choice(["foo", "bar", "baz", "hello", "world"])}"'
        elif choice == "bool":
            return random.choice(["true", "false"])
        elif choice == "variable":
            if self.variables:
                return random.choice(self.variables)
            else:
                return "0"  # Fallback
        return "nil"


if __name__ == "__main__":
    gen = CodeGenerator()
    print(gen.generate_program(20))
