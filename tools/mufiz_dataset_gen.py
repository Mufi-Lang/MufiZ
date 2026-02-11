#!/usr/bin/env python3
import argparse
import json
import multiprocessing
import os
import random
import subprocess
import time
from pathlib import Path


class MufiGenerator:
    """Generate valid MuFi code following the PEG grammar."""

    def __init__(self, depth_limit=4):
        self.depth_limit = depth_limit
        self.indent_level = 0
        self.variables = []  # List of (name, is_const) tuples
        self.functions = []
        self.classes = []  # List of (class_name, methods) tuples
        self.in_loop = False

        # Reserved keywords
        self.keywords = {
            "and",
            "as",
            "break",
            "case",
            "class",
            "const",
            "continue",
            "each",
            "else",
            "end",
            "false",
            "for",
            "foreach",
            "from",
            "fun",
            "if",
            "import",
            "in",
            "item",
            "let",
            "nil",
            "or",
            "print",
            "return",
            "self",
            "super",
            "switch",
            "true",
            "var",
            "while",
        }

        # Load standard library functions from JSON
        self.stdlib_functions = self._load_stdlib_functions()

    def _load_stdlib_functions(self):
        """Load stdlib functions from the generated JSON file."""
        script_dir = Path(__file__).parent
        json_path = script_dir / "stdlib_functions.json"

        if json_path.exists():
            try:
                with open(json_path, "r") as f:
                    data = json.load(f)
                    return data.get("functions", {})
            except Exception as e:
                print(f"Warning: Could not load stdlib functions from JSON: {e}")
                return self._fallback_stdlib_functions()
        else:
            print("Warning: stdlib_functions.json not found, using fallback list")
            return self._fallback_stdlib_functions()

    def _fallback_stdlib_functions(self):
        """Fallback list of common stdlib functions if JSON not available."""
        return {
            "sin": 1,
            "cos": 1,
            "tan": 1,
            "abs": 1,
            "sqrt": 1,
            "ln": 1,
            "log2": 1,
            "log10": 1,
            "exp": 1,
            "pi": 0,
            "len": 1,
            "push": 2,
            "pop": 1,
            "get": 2,
            "set": 3,
            "contains": 2,
            "clear": 1,
            "is_empty": 1,
            "type": 1,
            "to_string": 1,
            "clock": 0,
        }

    def indent(self):
        return "    " * self.indent_level

    def generate_identifier(self):
        """Generate a valid identifier that's not a keyword."""
        base = random.choice(
            [
                "x",
                "y",
                "z",
                "data",
                "val",
                "result",
                "count",
                "temp",
                "item",
                "num",
                "idx",
            ]
        )
        suffix = random.randint(1, 100)
        ident = f"{base}{suffix}"
        # Ensure it's not a keyword
        while ident in self.keywords:
            suffix = random.randint(1, 100)
            ident = f"{base}{suffix}"
        return ident

    def generate_number(self):
        """Generate number: integer, float, or imaginary."""
        choice = random.random()
        if choice < 0.6:
            # Integer
            return str(random.randint(0, 100))
        elif choice < 0.9:
            # Float
            return f"{random.randint(0, 50)}.{random.randint(0, 99)}"
        else:
            # Imaginary
            return f"{random.randint(1, 20)}i"

    def generate_string(self):
        """Generate a string literal."""
        words = ["hello", "world", "mufi", "data", "test", "value", "result", "code"]
        content = " ".join(random.sample(words, random.randint(1, 2)))
        return f'"{content}"'

    def generate_boolean(self):
        """Generate boolean literal."""
        return random.choice(["true", "false"])

    def generate_vector_literal(self, depth):
        """Generate vector literal using curly braces: {1, 2, 3}"""
        if depth > self.depth_limit:
            return "{}"

        count = random.randint(0, 4)
        if count == 0:
            return "{}"

        elements = []
        for _ in range(count):
            elements.append(self.generate_simple_value(depth + 1))

        return "{" + ", ".join(elements) + "}"

    def generate_matrix_literal(self, depth):
        """Generate matrix literal: [[1, 2], [3, 4]]"""
        if depth > self.depth_limit:
            return "[[]]"

        rows = random.randint(1, 3)
        cols = random.randint(1, 3)
        matrix_rows = []

        for _ in range(rows):
            elements = [self.generate_number() for _ in range(cols)]
            matrix_rows.append("[" + ", ".join(elements) + "]")

        return "[" + ", ".join(matrix_rows) + "]"

    def generate_hash_literal(self, depth):
        """Generate hash table literal: #{key1: val1, key2: val2}"""
        if depth > self.depth_limit:
            return "#{}"

        count = random.randint(0, 3)
        if count == 0:
            return "#{}"

        entries = []
        for i in range(count):
            key = f'"{self.generate_identifier()}"'
            val = self.generate_simple_value(depth + 1)
            entries.append(f"{key}: {val}")

        return "#{" + ", ".join(entries) + "}"

    def generate_pair_literal(self, depth):
        """Generate pair literal using => operator: key => value"""
        if depth > self.depth_limit:
            return f'"{self.generate_identifier()}" => nil'

        # Generate key and value
        key = self.generate_simple_value(depth + 1)
        value = self.generate_simple_value(depth + 1)

        return f"{key} => {value}"

    def generate_simple_value(self, depth):
        """Generate a simple, safe value (no complex expressions)."""
        choices = [
            lambda: self.generate_number(),
            lambda: self.generate_string(),
            lambda: self.generate_boolean(),
            lambda: "nil",
        ]

        if self.variables and random.random() < 0.3:
            return random.choice([name for name, _ in self.variables])

        return random.choice(choices)()

    def generate_stdlib_call(self, depth):
        """Generate a standard library function call."""
        if depth > self.depth_limit:
            return self.generate_simple_value(depth)

        # Select a random stdlib function
        func_name, param_count = random.choice(list(self.stdlib_functions.items()))

        # Generate appropriate arguments based on the function
        args = []
        for _ in range(param_count):
            if func_name in [
                "sin",
                "cos",
                "tan",
                "sqrt",
                "ln",
                "log2",
                "log10",
                "exp",
                "abs",
                "floor",
                "ceil",
                "asin",
                "acos",
                "atan",
                "phase",
            ]:
                # Math functions need numbers
                args.append(self.generate_number())
            elif func_name in ["complex", "linspace"]:
                # Functions that need multiple numbers
                args.append(self.generate_number())
            elif func_name in [
                "len",
                "pop",
                "clear",
                "is_empty",
                "pop_front",
                "pairs",
                "range_to_array",
            ]:
                # Collection inspection functions
                if self.variables and random.random() < 0.5:
                    args.append(random.choice([name for name, _ in self.variables]))
                else:
                    args.append(self.generate_vector_literal(depth + 1))
            elif func_name in ["get", "nth", "insert"]:
                # Functions needing collection and index
                if len(args) == 0:
                    args.append(self.generate_vector_literal(depth + 1))
                else:
                    args.append(str(random.randint(0, 5)))
            elif func_name in ["push", "push_front", "set"]:
                # Functions that modify collections
                if len(args) == 0:
                    args.append(self.generate_vector_literal(depth + 1))
                else:
                    args.append(self.generate_simple_value(depth + 1))
            elif func_name in ["contains", "find", "equals", "compare"]:
                # Functions with two arguments
                args.append(
                    self.generate_string()
                    if "string" in func_name
                    or func_name in ["find", "equals", "compare"]
                    else self.generate_simple_value(depth + 1)
                )
            elif func_name in ["put"]:
                # Hash table put function
                args.append(self.generate_string())  # key
                args.append(self.generate_simple_value(depth + 1))  # value
            elif func_name in [
                "type",
                "is_number",
                "is_string",
                "is_bool",
                "is_nil",
                "to_string",
                "to_number",
                "to_int",
            ]:
                # Type checking/conversion functions
                args.append(self.generate_simple_value(depth + 1))
            elif func_name in ["input"]:
                args.append(self.generate_string())  # prompt
            elif func_name in ["read_file"]:
                args.append('"test.txt"')
            elif func_name in ["write_file"]:
                args.append('"output.txt"')
                args.append(self.generate_string())
            elif func_name in ["sleep"]:
                args.append(str(random.randint(1, 3)))
            elif func_name in ["fvec", "range"]:
                args.append(str(random.randint(1, 10)))
            else:
                # Default: generate simple values
                for _ in range(param_count):
                    args.append(self.generate_simple_value(depth + 1))

        return f"{func_name}({', '.join(args)})"

    def generate_primary(self, depth):
        """Generate primary expression."""
        if depth > self.depth_limit:
            return self.generate_simple_value(depth)

        choices = [
            lambda: self.generate_number(),
            lambda: self.generate_string(),
            lambda: self.generate_boolean(),
            lambda: "nil",
        ]

        # Add variables if available
        if self.variables and random.random() < 0.4:
            var_name = random.choice([name for name, _ in self.variables])
            choices.append(lambda: var_name)

        # Occasionally add collections
        if depth < self.depth_limit - 1 and random.random() < 0.2:
            choices.append(lambda: self.generate_vector_literal(depth + 1))
            if random.random() < 0.3:
                choices.append(lambda: self.generate_hash_literal(depth + 1))

        # Add stdlib function calls
        if depth < self.depth_limit - 1 and random.random() < 0.3:
            choices.append(lambda: self.generate_stdlib_call(depth + 1))

        # Add pair literals (15% chance)
        if depth < self.depth_limit - 1 and random.random() < 0.15:
            choices.append(lambda: self.generate_pair_literal(depth + 1))

        # Parenthesized expression
        if depth < self.depth_limit - 1 and random.random() < 0.2:
            choices.append(lambda: f"({self.generate_expression(depth + 1)})")

        return random.choice(choices)()

    def generate_expression(self, depth=0):
        """Generate expression with proper operator precedence."""
        if depth > self.depth_limit:
            return self.generate_primary(depth)

        choice = random.random()

        if choice < 0.6:
            # Primary expression (prefer simple values)
            return self.generate_primary(depth)
        elif choice < 0.8:
            # Binary operation - use only numbers for arithmetic
            left = self.generate_number()
            op = random.choice(["+", "-", "*", "/"])
            right = self.generate_number()
            return f"{left} {op} {right}"
        elif choice < 0.9:
            # Comparison
            left = self.generate_number()
            op = random.choice(["==", "!=", ">", "<", ">=", "<="])
            right = self.generate_number()
            return f"{left} {op} {right}"
        else:
            # Unary operation - only on numbers
            op = random.choice(["!", "-"])
            if op == "!":
                return f"!{self.generate_boolean()}"
            else:
                return f"-{self.generate_number()}"

    def generate_print_stmt(self, depth):
        """Generate print statement."""
        # Sometimes print stdlib function results
        if random.random() < 0.3:
            expr = self.generate_stdlib_call(depth + 1)
        else:
            expr = self.generate_simple_value(depth + 1)
        return f"{self.indent()}print({expr});\n"

    def generate_var_decl(self, depth):
        """Generate variable declaration."""
        is_const = random.choice([True, False])
        keyword = "const" if is_const else "var"
        name = self.generate_identifier()

        # Sometimes assign result of stdlib function
        if random.random() < 0.25:
            value = self.generate_stdlib_call(depth + 1)
        else:
            value = self.generate_simple_value(depth + 1)

        self.variables.append((name, is_const))
        return f"{self.indent()}{keyword} {name} = {value};\n"

    def generate_assignment(self, depth):
        """Generate assignment to existing variable."""
        if not self.variables:
            return self.generate_var_decl(depth)

        # Only assign to non-const variables
        mutable_vars = [name for name, is_const in self.variables if not is_const]
        if not mutable_vars:
            return self.generate_var_decl(depth)

        var = random.choice(mutable_vars)
        value = self.generate_simple_value(depth + 1)
        return f"{self.indent()}{var} = {value};\n"

    def generate_if_stmt(self, depth):
        """Generate if statement."""
        if depth > self.depth_limit - 1:
            return self.generate_print_stmt(depth)

        # Use a boolean or comparison for condition
        if random.random() < 0.5:
            condition = self.generate_boolean()
        else:
            condition = f"{self.generate_number()} {random.choice(['>', '<', '==', '!='])} {self.generate_number()}"

        stmt = f"{self.indent()}if ({condition}) {{\n"

        self.indent_level += 1
        # Save current variables
        saved_vars = self.variables.copy()

        # Generate 1-2 statements in the if block
        for _ in range(random.randint(1, 2)):
            stmt += self.generate_statement(depth + 1)

        # Restore variables (don't leak scope)
        self.variables = saved_vars
        self.indent_level -= 1

        stmt += f"{self.indent()}}}"

        # Sometimes add else
        if random.random() < 0.3:
            stmt += " else {\n"
            self.indent_level += 1
            stmt += self.generate_statement(depth + 1)
            self.variables = saved_vars
            self.indent_level -= 1
            stmt += f"{self.indent()}}}"

        stmt += "\n"
        return stmt

    def generate_while_stmt(self, depth):
        """Generate while statement."""
        if depth > self.depth_limit - 2:
            return self.generate_print_stmt(depth)

        # Use a simple condition to avoid infinite loops
        counter = self.generate_identifier()
        limit = random.randint(2, 5)

        stmt = f"{self.indent()}var {counter} = 0;\n"
        self.variables.append((counter, False))

        stmt += f"{self.indent()}while ({counter} < {limit}) {{\n"

        self.indent_level += 1
        old_in_loop = self.in_loop
        self.in_loop = True
        saved_vars = self.variables.copy()

        # Body
        stmt += self.generate_statement(depth + 1)
        stmt += f"{self.indent()}{counter} = {counter} + 1;\n"

        self.in_loop = old_in_loop
        self.variables = saved_vars
        self.indent_level -= 1
        stmt += f"{self.indent()}}}\n"

        return stmt

    def generate_for_stmt(self, depth):
        """Generate for loop."""
        if depth > self.depth_limit - 2:
            return self.generate_print_stmt(depth)

        loop_var = self.generate_identifier()
        start = random.randint(0, 5)
        end = start + random.randint(3, 7)

        stmt = f"{self.indent()}for (var {loop_var} = {start}; {loop_var} < {end}; {loop_var} = {loop_var} + 1) {{\n"

        self.indent_level += 1
        old_in_loop = self.in_loop
        self.in_loop = True
        saved_vars = self.variables.copy()
        self.variables.append((loop_var, False))

        stmt += self.generate_statement(depth + 1)

        self.in_loop = old_in_loop
        self.variables = saved_vars
        self.indent_level -= 1
        stmt += f"{self.indent()}}}\n"

        return stmt

    def generate_foreach_stmt(self, depth):
        """Generate foreach loop."""
        if depth > self.depth_limit - 2:
            return self.generate_print_stmt(depth)

        iter_var = self.generate_identifier()

        # Sometimes use pairs() to iterate over hash tables (30% chance)
        if random.random() < 0.3:
            # Create a hash table and use pairs() to iterate
            hash_table = self.generate_hash_literal(depth + 1)
            collection = f"pairs({hash_table})"
        else:
            collection = self.generate_vector_literal(depth + 1)

        stmt = f"{self.indent()}foreach ({iter_var} in {collection}) {{\n"

        self.indent_level += 1
        old_in_loop = self.in_loop
        self.in_loop = True
        saved_vars = self.variables.copy()
        self.variables.append((iter_var, False))

        stmt += self.generate_statement(depth + 1)

        self.in_loop = old_in_loop
        self.variables = saved_vars
        self.indent_level -= 1
        stmt += f"{self.indent()}}}\n"

        return stmt

    def generate_statement(self, depth=0):
        """Generate a statement."""
        if depth > self.depth_limit:
            return self.generate_print_stmt(depth)

        choice = random.random()

        if choice < 0.22:
            return self.generate_print_stmt(depth)
        elif choice < 0.42:
            return self.generate_var_decl(depth)
        elif choice < 0.52 and self.variables:
            return self.generate_assignment(depth)
        elif choice < 0.57:
            # Standalone stdlib function call (for side effects)
            return f"{self.indent()}{self.generate_stdlib_call(depth)};\n"
        elif choice < 0.62:
            # Generate pairs-related code
            return self.generate_pairs_statement(depth)
        elif choice < 0.72:
            return self.generate_if_stmt(depth)
        elif choice < 0.82:
            return self.generate_for_stmt(depth)
        elif choice < 0.92:
            return self.generate_foreach_stmt(depth)
        else:
            return self.generate_while_stmt(depth)

    def generate_pairs_statement(self, depth):
        """Generate statements that use pairs() or work with pair objects."""
        if depth > self.depth_limit:
            return self.generate_print_stmt(depth)

        choice = random.random()

        if choice < 0.2:
            # Create a pair literal using =>
            pair_var = self.generate_identifier()
            pair_literal = self.generate_pair_literal(depth + 1)
            stmt = f"{self.indent()}var {pair_var} = {pair_literal};\n"
            self.variables.append((pair_var, False))

            # Access pair elements
            stmt += f"{self.indent()}print({pair_var}[0]);\n"
            stmt += f"{self.indent()}print({pair_var}[1]);\n"

            return stmt
        elif choice < 0.35:
            # Create nested pairs
            pair_var = self.generate_identifier()
            key1 = self.generate_simple_value(depth + 1)
            key2 = self.generate_simple_value(depth + 1)
            val = self.generate_simple_value(depth + 1)
            stmt = f"{self.indent()}var {pair_var} = {key1} => ({key2} => {val});\n"
            self.variables.append((pair_var, False))

            # Access nested elements
            stmt += f"{self.indent()}print({pair_var}[1][0]);\n"
            stmt += f"{self.indent()}print({pair_var}[1][1]);\n"

            return stmt
        elif choice < 0.5:
            # Create list of pairs
            list_var = self.generate_identifier()
            stmt = f"{self.indent()}var {list_var} = linked_list();\n"
            self.variables.append((list_var, False))

            # Add multiple pairs to the list
            for _ in range(random.randint(2, 4)):
                pair_literal = self.generate_pair_literal(depth + 1)
                stmt += f"{self.indent()}push({list_var}, {pair_literal});\n"

            # Access a pair from the list
            stmt += f"{self.indent()}var first_pair = nth({list_var}, 0);\n"
            stmt += f"{self.indent()}print(first_pair[0]);\n"

            return stmt
        elif choice < 0.65:
            # Create a hash table and convert to pairs
            hash_table_var = self.generate_identifier()
            stmt = f"{self.indent()}var {hash_table_var} = {self.generate_hash_literal(depth + 1)};\n"
            self.variables.append((hash_table_var, False))

            # Call pairs() on it
            pairs_var = self.generate_identifier()
            stmt += f"{self.indent()}var {pairs_var} = pairs({hash_table_var});\n"
            self.variables.append((pairs_var, False))

            return stmt
        else:
            # Iterate over pairs using foreach
            hash_table = self.generate_hash_literal(depth + 1)
            iter_var = self.generate_identifier()

            stmt = f"{self.indent()}foreach ({iter_var} in pairs({hash_table})) {{\n"

            self.indent_level += 1
            saved_vars = self.variables.copy()
            self.variables.append((iter_var, False))

            # Print the pair or access its elements
            if random.random() < 0.5:
                stmt += f"{self.indent()}print({iter_var});\n"
            else:
                stmt += f"{self.indent()}print({iter_var}[0]);\n"
                stmt += f"{self.indent()}print({iter_var}[1]);\n"

            self.variables = saved_vars
            self.indent_level -= 1
            stmt += f"{self.indent()}}}\n"

            return stmt

    def generate_function(self):
        """Generate a function definition."""
        fname = self.generate_identifier()

        # Generate 0-3 parameters
        param_count = random.randint(0, 3)
        params = [self.generate_identifier() for _ in range(param_count)]

        old_vars = self.variables.copy()
        self.variables = [(p, False) for p in params]

        stmt = f"fun {fname}("
        stmt += ", ".join(params)
        stmt += ") {\n"

        self.indent_level += 1

        # Generate function body
        for _ in range(random.randint(1, 3)):
            stmt += self.generate_statement(depth=1)

        # Sometimes add a return
        if random.random() < 0.5:
            stmt += f"{self.indent()}return {self.generate_simple_value(1)};\n"

        self.indent_level -= 1
        stmt += "}\n\n"

        self.variables = old_vars
        self.functions.append((fname, param_count))

        return stmt

    def generate_function_call(self):
        """Generate a function call statement."""
        if not self.functions:
            return ""

        fname, param_count = random.choice(self.functions)

        # Generate arguments
        args = [self.generate_simple_value(1) for _ in range(param_count)]

        return f"{self.indent()}{fname}({', '.join(args)});\n"

    def generate_class(self):
        """Generate a class definition with methods."""
        class_name = self.generate_identifier().capitalize()

        # Ensure class name doesn't conflict with keywords
        while class_name.lower() in self.keywords:
            class_name = self.generate_identifier().capitalize()

        stmt = f"class {class_name} {{\n"
        self.indent_level += 1

        old_vars = self.variables.copy()
        methods = []

        # Generate 1-3 methods
        method_count = random.randint(1, 3)
        for _ in range(method_count):
            method_name = self.generate_identifier()
            param_count = random.randint(0, 2)
            params = [self.generate_identifier() for _ in range(param_count)]

            self.variables = [(p, False) for p in params]

            stmt += f"{self.indent()}{method_name}("
            stmt += ", ".join(params)
            stmt += ") {\n"

            self.indent_level += 1

            # Generate method body (1-2 statements)
            for _ in range(random.randint(1, 2)):
                stmt += self.generate_statement(depth=1)

            # Sometimes add a return
            if random.random() < 0.4:
                stmt += f"{self.indent()}return {self.generate_simple_value(1)};\n"

            self.indent_level -= 1
            stmt += f"{self.indent()}}}\n\n"

            methods.append((method_name, param_count))

        self.indent_level -= 1
        stmt += "}\n\n"

        self.variables = old_vars
        self.classes.append((class_name, methods))

        return stmt

    def generate_program(self):
        """Generate a complete MuFi program."""
        self.variables = []
        self.functions = []
        self.classes = []
        self.indent_level = 0
        lines = []

        # Add a header comment
        lines.append("// Auto-generated MuFi program\n\n")

        # Sometimes generate a class (20% chance)
        if random.random() < 0.2:
            lines.append(self.generate_class())

        # Generate 1-3 function definitions
        for _ in range(random.randint(1, 3)):
            lines.append(self.generate_function())

        # Sometimes add a pairs demonstration at the start (20% chance)
        if random.random() < 0.2:
            lines.append(self.generate_pairs_statement(0))

        # Generate main program statements (with higher chance of pair statements)
        for _ in range(random.randint(5, 10)):
            # 10% chance of generating a pair statement directly
            if random.random() < 0.1:
                lines.append(self.generate_pairs_statement(0))
            else:
                lines.append(self.generate_statement(depth=0))

        # Call some functions we defined
        for _ in range(min(len(self.functions), 2)):
            call = self.generate_function_call()
            if call:
                lines.append(call)

        # Final print to mark completion
        lines.append('\nprint("Program completed");\n')

        return "".join(lines)


def validate_script(mufiz_bin, source_code, debug=False):
    """Validate a MuFi script by running it."""
    temp_file = f"temp_{multiprocessing.current_process().pid}_{time.time_ns()}.mufi"
    try:
        with open(temp_file, "w") as f:
            f.write(source_code)

        with open(os.devnull, "r") as devnull:
            result = subprocess.run(
                [mufiz_bin, "-r", temp_file],
                stdin=devnull,
                capture_output=True,
                text=True,
                timeout=3,
            )

        if result.returncode != 0 and debug:
            print(f"\n{'=' * 60}")
            print(f"Validation failed!")
            print(f"{'=' * 60}")
            print(f"Source code:\n{source_code}")
            print(f"{'=' * 60}")
            print(f"Error output:\n{result.stderr}")
            print(f"{'=' * 60}\n")

        return result.returncode == 0
    except subprocess.TimeoutExpired:
        if debug:
            print(f"Timeout validating script")
        return False
    except Exception as e:
        if debug:
            print(f"Validation exception: {e}")
        return False
    finally:
        if os.path.exists(temp_file):
            os.remove(temp_file)


def worker(args):
    """Worker function for parallel generation."""
    target_count, mufiz_bin, output_dir, start_idx, debug = args
    generator = MufiGenerator()
    valid_count = 0
    idx = start_idx
    attempts = 0
    max_attempts = target_count * 10  # Prevent infinite loops

    pid = multiprocessing.current_process().pid
    print(f"Worker {pid} starting to generate {target_count} valid files...")

    while valid_count < target_count and attempts < max_attempts:
        attempts += 1
        code = generator.generate_program()

        if validate_script(mufiz_bin, code, debug):
            file_path = os.path.join(output_dir, f"prog_{idx}.mufi")
            with open(file_path, "w") as f:
                f.write(code)
            valid_count += 1
            idx += 1

            if valid_count % 10 == 0:
                print(f"Worker {pid} progress: {valid_count}/{target_count}")
        elif debug and attempts % 50 == 0:
            print(f"Worker {pid}: {attempts} attempts, {valid_count} valid")

    if valid_count < target_count:
        print(
            f"Worker {pid} warning: only generated {valid_count}/{target_count} after {attempts} attempts"
        )

    return valid_count


def run_git(repo_dir, cmd):
    """Run a git command in the repository."""
    subprocess.run(["git"] + cmd, cwd=repo_dir, capture_output=True)


def main():
    parser = argparse.ArgumentParser(description="MuFi Dataset Generator")
    parser.add_argument(
        "--count", type=int, default=100000, help="Total files to generate"
    )
    parser.add_argument(
        "--output", type=str, default="mufiz-dataset", help="Output directory"
    )
    parser.add_argument(
        "--mufiz", type=str, default="./zig-out/bin/mufiz", help="Path to mufiz binary"
    )
    parser.add_argument(
        "--batch", type=int, default=1000, help="Batch size for commits"
    )
    parser.add_argument(
        "--cores",
        type=int,
        default=multiprocessing.cpu_count(),
        help="CPU cores to use",
    )
    parser.add_argument(
        "--debug", action="store_true", help="Print debug info for failures"
    )
    args = parser.parse_args()

    # Verify mufiz binary exists
    if not os.path.exists(args.mufiz):
        print(f"Error: MuFi binary not found at {args.mufiz}")
        print("Please build MuFi first or specify correct path with --mufiz")
        return 1

    output_path = Path(args.output)
    output_path.mkdir(parents=True, exist_ok=True)

    # Initialize Git
    if not (output_path / ".git").exists():
        print(f"Initializing Git repository in {args.output}...")
        run_git(args.output, ["init"])
        with open(output_path / "README.md", "w") as f:
            f.write("# MuFi-Lang Synthetic Dataset\n\n")
            f.write(
                "This dataset contains valid MuFi programs generated for neural network training.\n"
            )
            f.write(f"Target: {args.count:,} programs\n")
        run_git(args.output, ["add", "README.md"])
        run_git(args.output, ["commit", "-m", "Initial commit"])

    total_generated = 0
    batch_size = args.batch
    num_batches = (args.count + batch_size - 1) // batch_size

    print(
        f"\nGenerating {args.count:,} files using {args.cores} cores in batches of {batch_size}..."
    )
    print(f"Output directory: {args.output}")
    print(f"MuFi binary: {args.mufiz}\n")

    pool = multiprocessing.Pool(args.cores)
    start_time = time.time()

    try:
        for b in range(num_batches):
            batch_start = time.time()
            current_batch_target = min(batch_size, args.count - total_generated)
            per_worker = current_batch_target // args.cores
            remainder = current_batch_target % args.cores

            worker_args = []
            curr_idx = total_generated
            for i in range(args.cores):
                count = per_worker + (1 if i < remainder else 0)
                if count > 0:
                    worker_args.append(
                        (count, args.mufiz, args.output, curr_idx, args.debug)
                    )
                    curr_idx += count

            results = pool.map(worker, worker_args)
            batch_generated = sum(results)
            total_generated += batch_generated

            # Commit batch
            run_git(args.output, ["add", "."])
            run_git(
                args.output,
                ["commit", "-m", f"Add batch {b + 1}: files up to {total_generated}"],
            )

            batch_time = time.time() - batch_start
            elapsed = time.time() - start_time
            rate = total_generated / elapsed if elapsed > 0 else 0
            eta = (args.count - total_generated) / rate if rate > 0 else 0

            print(f"\nBatch {b + 1}/{num_batches} completed in {batch_time:.1f}s")
            print(
                f"Progress: {total_generated:,}/{args.count:,} ({(total_generated / args.count) * 100:.1f}%)"
            )
            print(f"Rate: {rate:.1f} files/sec | ETA: {eta / 60:.1f} minutes\n")

    finally:
        pool.close()
        pool.join()

    total_time = time.time() - start_time
    print(f"\n{'=' * 60}")
    print(f"Generation complete!")
    print(f"{'=' * 60}")
    print(f"Total files: {total_generated:,}")
    print(f"Total time: {total_time / 60:.1f} minutes")
    print(f"Average rate: {total_generated / total_time:.1f} files/sec")
    print(f"Dataset location: {args.output}")
    print(f"{'=' * 60}\n")

    return 0


if __name__ == "__main__":
    exit(main())
