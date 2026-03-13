"""
Type-aware synthetic MufiZ program generator.

Improvements over v1:
  - Diverse realistic variable/function names (not v1/v2/fn1)
  - Balanced comparison operators (all six equally likely)
  - Full safe-stdlib coverage: math, type-conv, type-pred, collections, time, IO
  - Keywords covered: break, continue, nil, not, else-if chains
  - Vector / collection patterns
  - Multiple program templates (functional, loop-heavy, collection-heavy, mixed)
"""
import random

# ---------------------------------------------------------------------------
# Type system
# ---------------------------------------------------------------------------

class Type:
    VOID   = "Void"
    INT    = "Int"
    FLOAT  = "Double"
    BOOL   = "Bool"
    STRING = "String"
    ANY    = "Any"
    NUMBER = "Number"   # Union Int | Float
    VEC    = "Vec"      # float vector literal {…}


def is_compatible(target, actual):
    if target == Type.ANY:
        return True
    if target == Type.NUMBER and actual in (Type.INT, Type.FLOAT):
        return True
    # NUMBER return is usable wherever INT or FLOAT is expected
    if actual == Type.NUMBER and target in (Type.INT, Type.FLOAT):
        return True
    return target == actual


# ---------------------------------------------------------------------------
# Name pools  (diverse, realistic)
# ---------------------------------------------------------------------------

INT_VAR_NAMES = [
    "count", "total", "index", "size", "limit", "offset", "step",
    "n", "k", "i", "j", "x", "y", "z", "score", "rank", "level",
    "age", "width", "height", "depth", "capacity", "max_val", "min_val",
    "sum", "product", "diff", "remainder", "start", "end", "pos", "len_val",
]
FLOAT_VAR_NAMES = [
    "avg", "ratio", "rate", "percent", "weight", "dist", "angle",
    "magnitude", "temperature", "pressure", "voltage", "freq",
    "radius", "area", "volume", "density", "velocity", "accel",
    "result_f", "pi_approx", "factor", "threshold",
]
BOOL_VAR_NAMES = [
    "flag", "done", "found", "valid", "ok", "active", "enabled",
    "visible", "ready", "success", "is_even", "is_positive", "running",
    "has_item", "checked", "confirmed",
]
STRING_VAR_NAMES = [
    "name", "msg", "text", "label", "tag", "prefix", "suffix", "word",
    "line", "title", "desc", "key", "output", "path", "query", "token",
    "category", "status", "language", "city", "greeting",
]
FUNC_NAMES = [
    "add", "subtract", "multiply", "divide", "calculate", "compute",
    "check", "find", "process", "update", "transform", "convert",
    "validate", "compare", "apply", "execute", "run", "build",
    "get_value", "set_value", "is_valid", "to_string", "from_int",
    "clamp", "normalize", "interpolate", "map_range", "accumulate",
]
STRING_LITERALS = [
    "hello", "world", "mufi", "code", "test", "value", "result",
    "ok", "done", "data", "name", "foo", "bar", "baz", "qux",
    "error", "success", "info", "warning", "debug",
    "start", "end", "item", "node", "leaf", "root", "key",
]

# ---------------------------------------------------------------------------
# Stdlib signatures (safe to call: no filesystem writes, no stdin, no network)
# ---------------------------------------------------------------------------

STDLIB_SIGS = {
    # Math
    "sin":    {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "cos":    {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "tan":    {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "asin":   {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "acos":   {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "atan":   {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "sqrt":   {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "abs":    {"args": [Type.NUMBER], "ret": Type.NUMBER},
    "pow":    {"args": [Type.NUMBER, Type.NUMBER], "ret": Type.FLOAT},
    "min":    {"args": [Type.NUMBER, Type.NUMBER], "ret": Type.NUMBER},
    "max":    {"args": [Type.NUMBER, Type.NUMBER], "ret": Type.NUMBER},
    "floor":  {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "ceil":   {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "round":  {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "exp":    {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "ln":     {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "log2":   {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "log10":  {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "rand":   {"args": [], "ret": Type.FLOAT},
    "pi":     {"args": [], "ret": Type.FLOAT},
    # Type conversions
    "str":    {"args": [Type.ANY],    "ret": Type.STRING},
    "int":    {"args": [Type.NUMBER], "ret": Type.INT},
    "double": {"args": [Type.NUMBER], "ret": Type.FLOAT},
    "bool":   {"args": [Type.ANY],    "ret": Type.BOOL},
    # Type predicates
    "is_int":    {"args": [Type.ANY], "ret": Type.BOOL},
    "is_string": {"args": [Type.ANY], "ret": Type.BOOL},
    "is_bool":   {"args": [Type.ANY], "ret": Type.BOOL},
    "is_nil":    {"args": [Type.ANY], "ret": Type.BOOL},
    "is_double": {"args": [Type.ANY], "ret": Type.BOOL},
    "type_of":   {"args": [Type.ANY], "ret": Type.STRING},
    # Collections (operating on vectors)
    "len":     {"args": [Type.ANY],  "ret": Type.INT},
    "sum":     {"args": [Type.ANY],  "ret": Type.FLOAT},
    "mean":    {"args": [Type.ANY],  "ret": Type.FLOAT},
    "minl":    {"args": [Type.ANY],  "ret": Type.FLOAT},
    "maxl":    {"args": [Type.ANY],  "ret": Type.FLOAT},
    # IO (println only — void, safe)
    "println": {"args": [Type.ANY],  "ret": Type.VOID},
    # Time (read-only)
    "now":     {"args": [], "ret": Type.INT},
    "now_ms":  {"args": [], "ret": Type.INT},
    "now_ns":  {"args": [], "ret": Type.INT},
}

# Comparison operators — ALL SIX, equally weighted
COMPARISONS = ["<", ">", "<=", ">=", "==", "!="]

ARITH_OPS = {
    Type.INT:   ["+", "-", "*"],
    Type.FLOAT: ["+", "-", "*", "/"],
}

# ---------------------------------------------------------------------------
# Scope
# ---------------------------------------------------------------------------

class Scope:
    def __init__(self, parent=None):
        self.variables: dict[str, str] = {}
        self.parent: "Scope | None" = parent

    def add(self, name: str, type_: str):
        self.variables[name] = type_

    def get_vars_by_type(self, target_type: str) -> list[str]:
        candidates = [
            n for n, t in self.variables.items()
            if is_compatible(target_type, t)
        ]
        if self.parent:
            candidates.extend(self.parent.get_vars_by_type(target_type))
        return candidates

    def all_vars(self) -> list[tuple[str, str]]:
        result = list(self.variables.items())
        if self.parent:
            result.extend(self.parent.all_vars())
        return result


# ---------------------------------------------------------------------------
# Generator
# ---------------------------------------------------------------------------

class TypeAwareGenerator:
    MAX_NESTING   = 3
    MAX_EXPR_DEPTH = 3

    def __init__(self):
        self._reset()

    def _reset(self):
        self.scope         = Scope()
        self.indent_level  = 0
        self._used_int_names:    list[str] = []
        self._used_float_names:  list[str] = []
        self._used_bool_names:   list[str] = []
        self._used_string_names: list[str] = []
        self._used_func_names:   list[str] = []
        self._pool_idx: dict[str, int] = {
            "int": 0, "float": 0, "bool": 0, "string": 0, "func": 0
        }
        # Shuffle pools so each program has different name ordering
        random.shuffle(INT_VAR_NAMES)
        random.shuffle(FLOAT_VAR_NAMES)
        random.shuffle(BOOL_VAR_NAMES)
        random.shuffle(STRING_VAR_NAMES)
        random.shuffle(FUNC_NAMES)

    def _new_name(self, kind: str, pool: list[str]) -> str:
        idx = self._pool_idx[kind]
        if idx < len(pool):
            name = pool[idx]
            self._pool_idx[kind] = idx + 1
        else:
            # Overflow: append numeric suffix
            name = pool[idx % len(pool)] + str(idx - len(pool) + 2)
            self._pool_idx[kind] = idx + 1
        return name

    def new_int_name(self)    -> str: return self._new_name("int",    INT_VAR_NAMES)
    def new_float_name(self)  -> str: return self._new_name("float",  FLOAT_VAR_NAMES)
    def new_bool_name(self)   -> str: return self._new_name("bool",   BOOL_VAR_NAMES)
    def new_string_name(self) -> str: return self._new_name("string", STRING_VAR_NAMES)
    def new_func_name(self)   -> str: return self._new_name("func",   FUNC_NAMES)

    def new_var_name(self, type_: str) -> str:
        if type_ == Type.INT:    return self.new_int_name()
        if type_ == Type.FLOAT:  return self.new_float_name()
        if type_ == Type.BOOL:   return self.new_bool_name()
        if type_ == Type.STRING: return self.new_string_name()
        return self.new_int_name()

    # ------------------------------------------------------------------
    # Indent / scope helpers
    # ------------------------------------------------------------------

    def indent(self) -> str:
        return "  " * self.indent_level

    def push_scope(self):
        self.scope = Scope(self.scope)
        self.indent_level += 1

    def pop_scope(self):
        self.scope = self.scope.parent
        self.indent_level -= 1

    # ------------------------------------------------------------------
    # Program
    # ------------------------------------------------------------------

    def generate_program(self, num_statements: int = 12) -> str:
        self._reset()

        # Pick a program style to ensure keyword/stdlib diversity
        style = random.choice(["mixed", "functional", "loop_heavy", "collection", "conditional"])
        parts: list[str] = []

        if style == "functional":
            parts += self._program_functional()
        elif style == "loop_heavy":
            parts += self._program_loop_heavy()
        elif style == "collection":
            parts += self._program_collection()
        elif style == "conditional":
            parts += self._program_conditional()
        else:
            # Generic mixed program
            if num_statements >= 4 and random.random() < 0.5:
                parts.append(self.generate_func_def())
                parts.append("")
            for _ in range(num_statements):
                parts.append(self.generate_statement(nesting=0))

        return "\n".join(parts)

    def _program_functional(self) -> list[str]:
        """Two helper functions + main logic using them."""
        parts = []
        parts.append(self.generate_func_def())
        parts.append("")
        if random.random() < 0.6:
            parts.append(self.generate_func_def())
            parts.append("")
        for _ in range(random.randint(5, 10)):
            parts.append(self.generate_statement(nesting=0))
        return parts

    def _program_loop_heavy(self) -> list[str]:
        """Loops with break/continue and varied operators."""
        parts = []
        # Declare a few vars first
        for _ in range(random.randint(2, 4)):
            parts.append(self.generate_var_decl())
        # While loop with possible break
        parts.append(self.generate_while_stmt(nesting=0, allow_break=True))
        # Foreach with possible continue
        parts.append(self.generate_foreach_stmt(nesting=0, allow_continue=True))
        # A few more statements
        for _ in range(random.randint(2, 5)):
            parts.append(self.generate_statement(nesting=0))
        return parts

    def _program_collection(self) -> list[str]:
        """Focuses on vectors, len, sum, mean, foreach."""
        parts = []
        # Declare a vector
        vec_name = self.new_float_name()
        size = random.randint(3, 6)
        elems = ", ".join(f"{random.uniform(0.0, 100.0):.1f}" for _ in range(size))
        parts.append(f"var {vec_name} = {{{elems}}};")
        self.scope.add(vec_name, Type.VEC)

        # Use collection functions on it
        len_name = self.new_int_name()
        parts.append(f"var {len_name} = len({vec_name});")
        self.scope.add(len_name, Type.INT)

        sum_name = self.new_float_name()
        parts.append(f"var {sum_name} = sum({vec_name});")
        self.scope.add(sum_name, Type.FLOAT)

        avg_name = self.new_float_name()
        parts.append(f"var {avg_name} = mean({vec_name});")
        self.scope.add(avg_name, Type.FLOAT)

        parts.append(f"println({sum_name});")
        parts.append(f"println({avg_name});")

        # Foreach over the vector
        parts.append(self.generate_foreach_stmt(nesting=0, allow_continue=True,
                                                 vec_name=vec_name))
        # A few extra statements
        for _ in range(random.randint(2, 5)):
            parts.append(self.generate_statement(nesting=0))
        return parts

    def _program_conditional(self) -> list[str]:
        """Lots of if/else-if/else chains, nil checks, not."""
        parts = []
        for _ in range(random.randint(2, 4)):
            parts.append(self.generate_var_decl())
        # nil assignment + is_nil check
        nil_name = self.new_var_name(Type.ANY if False else Type.INT)
        parts.append(f"var {nil_name} = nil;")
        self.scope.add(nil_name, Type.INT)
        parts.append(
            f"if (is_nil({nil_name})) {{\n"
            f"  println(\"is nil\");\n"
            f"}} else {{\n"
            f"  println({nil_name});\n"
            f"}}"
        )
        # not keyword in condition
        bool_name = self.new_bool_name()
        parts.append(f"var {bool_name} = {random.choice(['true','false'])};")
        self.scope.add(bool_name, Type.BOOL)
        parts.append(
            f"if (not {bool_name}) {{\n"
            f"  {bool_name} = true;\n"
            f"}}"
        )
        # Regular conditional chains
        for _ in range(random.randint(3, 6)):
            parts.append(self.generate_if_stmt(nesting=0))
        return parts

    # ------------------------------------------------------------------
    # Statements
    # ------------------------------------------------------------------

    def generate_statement(self, nesting: int = 0) -> str:
        options = [
            (self.generate_var_decl,       0.30),
            (self.generate_print_stmt,     0.18),
            (self.generate_assign_stmt,    0.12),
            (self.generate_void_call_stmt, 0.08),
            (self.generate_nil_stmt,       0.04),
        ]
        if nesting < self.MAX_NESTING:
            options += [
                (lambda: self.generate_if_stmt(nesting + 1),      0.18),
                (lambda: self.generate_while_stmt(nesting + 1),   0.06),
                (lambda: self.generate_foreach_stmt(nesting + 1), 0.04),
            ]
        fns, weights = zip(*options)
        total = sum(weights)
        weights = [w / total for w in weights]
        return random.choices(list(fns), weights=list(weights), k=1)[0]()

    def generate_var_decl(self) -> str:
        target_type = random.choice([Type.INT, Type.FLOAT, Type.BOOL, Type.STRING])
        expr = self.generate_expression(target_type)
        name = self.new_var_name(target_type)
        self.scope.add(name, target_type)
        return f"var {name} = {expr};"

    def generate_assign_stmt(self) -> str:
        all_vars = [(n, t) for n, t in self.scope.all_vars()
                    if t in (Type.INT, Type.FLOAT, Type.BOOL, Type.STRING)]
        if not all_vars:
            return self.generate_var_decl()
        name, var_type = random.choice(all_vars)
        expr = self.generate_expression(var_type)
        return f"{name} = {expr};"

    def generate_nil_stmt(self) -> str:
        """Declare a nil var then check it with is_nil."""
        name = self.new_var_name(Type.INT)
        self.scope.add(name, Type.INT)
        return (
            f"var {name} = nil;\n"
            + self.indent()
            + f"if (is_nil({name})) {{ println(\"nil\"); }}"
        )

    def generate_if_stmt(self, nesting: int) -> str:
        # Occasionally use `not` in condition
        if random.random() < 0.15:
            inner_cond = self.generate_expression(Type.BOOL)
            cond = f"not {inner_cond}"
        else:
            cond = self.generate_expression(Type.BOOL)
        block = self.generate_block(nesting)
        stmt = f"if ({cond}) {block}"
        roll = random.random()
        if roll < 0.25:
            stmt += f" else {self.generate_block(nesting)}"
        elif roll < 0.38:
            cond2 = self.generate_expression(Type.BOOL)
            stmt += f" else if ({cond2}) {self.generate_block(nesting)}"
        return stmt

    def generate_while_stmt(self, nesting: int, allow_break: bool = False) -> str:
        counter = self.new_int_name()
        limit   = random.randint(1, 10)
        self.scope.add(counter, Type.INT)

        # Balance operators: use > half the time (count DOWN or compare var > 0)
        if random.random() < 0.5:
            init_val  = 0
            cmp_op    = "<"
            cmp_right = limit
            increment = f"{counter} = {counter} + 1;"
        else:
            init_val  = limit
            cmp_op    = ">"
            cmp_right = 0
            increment = f"{counter} = {counter} - 1;"

        body_stmts: list[str] = []
        self.push_scope()

        # Possible break near start
        if allow_break and random.random() < 0.2:
            break_cond = self.generate_expression(Type.BOOL)
            body_stmts.append(self.indent() + f"if ({break_cond}) {{ break; }}")

        inner_count = random.randint(1, 3)
        for _ in range(inner_count):
            body_stmts.append(self.indent() + self.generate_statement(nesting=nesting))

        body_stmts.append(self.indent() + increment)
        self.pop_scope()

        inner   = "\n".join(body_stmts)
        closing = self.indent() + "}"
        block_str = "{\n" + inner + "\n" + closing

        decl = f"var {counter} = {init_val};"
        loop = f"while ({counter} {cmp_op} {cmp_right}) {block_str}"
        return decl + "\n" + self.indent() + loop

    def generate_foreach_stmt(self, nesting: int, allow_continue: bool = False,
                               vec_name: str | None = None) -> str:
        item_var = self.new_float_name()
        if vec_name is None:
            size   = random.randint(2, 6)
            elems  = ", ".join(f"{random.uniform(0.0, 100.0):.1f}" for _ in range(size))
            source = "{" + elems + "}"
        else:
            source = vec_name

        self.push_scope()
        self.scope.add(item_var, Type.FLOAT)

        stmts: list[str] = []
        if allow_continue and random.random() < 0.2:
            skip_cond = self.generate_expression(Type.BOOL)
            stmts.append(self.indent() + f"if ({skip_cond}) {{ continue; }}")

        count = random.randint(1, 3)
        for _ in range(count):
            stmts.append(self.indent() + self.generate_statement(nesting=nesting))
        self.pop_scope()

        inner   = "\n".join(stmts)
        closing = self.indent() + "}"
        block_str = "{\n" + inner + "\n" + closing
        return f"foreach ({item_var} in {source}) {block_str}"

    def generate_print_stmt(self) -> str:
        # Mix print and println
        kw = random.choice(["print", "println"])
        target_type = random.choice([Type.INT, Type.FLOAT, Type.STRING, Type.BOOL])
        expr = self.generate_expression(target_type)
        if kw == "println":
            return f"println({expr});"
        return f"print {expr};"

    def generate_void_call_stmt(self) -> str:
        void_funcs = [n for n, s in STDLIB_SIGS.items() if s["ret"] == Type.VOID]
        func = random.choice(void_funcs)
        return self.generate_func_call(func) + ";"

    def generate_func_def(self) -> str:
        name       = self.new_func_name()
        num_params = random.randint(0, 3)
        param_types = [random.choice([Type.INT, Type.FLOAT, Type.BOOL, Type.STRING])
                       for _ in range(num_params)]
        param_names = [self.new_var_name(t) for t in param_types]
        ret_type    = random.choice([Type.INT, Type.FLOAT, Type.STRING, Type.BOOL])

        self.push_scope()
        for pname, ptype in zip(param_names, param_types):
            self.scope.add(pname, ptype)

        body: list[str] = []
        for _ in range(random.randint(1, 4)):
            body.append(self.indent() + self.generate_statement(nesting=1))
        body.append(self.indent() + f"return {self.generate_expression(ret_type)};")
        self.pop_scope()

        inner   = "\n".join(body)
        closing = self.indent() + "}"
        params_str = ", ".join(param_names)
        return f"fun {name}({params_str}) {{\n{inner}\n{closing}"

    # ------------------------------------------------------------------
    # Blocks
    # ------------------------------------------------------------------

    def generate_block(self, nesting: int) -> str:
        self.push_scope()
        stmts: list[str] = []
        for _ in range(random.randint(1, 4)):
            stmts.append(self.indent() + self.generate_statement(nesting=nesting))
        self.pop_scope()
        inner   = "\n".join(stmts)
        closing = self.indent() + "}"
        return "{\n" + inner + "\n" + closing

    # ------------------------------------------------------------------
    # Expressions
    # ------------------------------------------------------------------

    def generate_expression(self, target_type: str, depth: int = 0) -> str:
        if depth >= self.MAX_EXPR_DEPTH:
            return self.generate_atom(target_type)
        weights = [0.50, 0.33, 0.17]
        choice  = random.choices(["atom", "op", "call"], weights=weights, k=1)[0]
        if choice == "op":
            return self.generate_operation(target_type, depth + 1)
        if choice == "call":
            return self.generate_func_call_expr(target_type, depth + 1)
        return self.generate_atom(target_type)

    def generate_atom(self, target_type: str) -> str:
        vars_ = self.scope.get_vars_by_type(target_type)
        if vars_ and random.random() < 0.5:
            return random.choice(vars_)
        if target_type == Type.INT:
            return str(random.randint(0, 100))
        if target_type == Type.FLOAT:
            return f"{random.uniform(0.1, 100.0):.1f}"
        if target_type == Type.BOOL:
            return random.choice(["true", "false"])
        if target_type == Type.STRING:
            return f'"{random.choice(STRING_LITERALS)}"'
        return "nil"

    def generate_operation(self, target_type: str, depth: int) -> str:
        if target_type == Type.BOOL:
            r = random.random()
            if r < 0.15:
                # not expr
                inner = self.generate_expression(Type.BOOL, depth)
                return f"(not {inner})"
            if r < 0.40:
                op  = random.choice(["and", "or"])
                lhs = self.generate_expression(Type.BOOL, depth)
                rhs = self.generate_expression(Type.BOOL, depth)
                return f"({lhs} {op} {rhs})"
            # comparison — all six equally likely
            op      = random.choice(COMPARISONS)
            subtype = random.choice([Type.INT, Type.FLOAT])
            lhs     = self.generate_expression(subtype, depth)
            rhs     = self.generate_expression(subtype, depth)
            return f"({lhs} {op} {rhs})"

        if target_type in (Type.INT, Type.FLOAT):
            op  = random.choice(ARITH_OPS[target_type])
            lhs = self.generate_expression(target_type, depth)
            rhs = self.generate_expression(target_type, depth)
            if op == "/":
                rhs = f"{random.uniform(1.0, 20.0):.1f}" if target_type == Type.FLOAT \
                      else str(random.randint(1, 20))
            return f"({lhs} {op} {rhs})"

        if target_type == Type.STRING:
            lhs = self.generate_expression(Type.STRING, depth)
            rhs = self.generate_expression(Type.STRING, depth)
            return f"({lhs} + {rhs})"

        return self.generate_atom(target_type)

    def generate_func_call_expr(self, target_type: str, depth: int) -> str:
        candidates = [n for n, s in STDLIB_SIGS.items()
                      if is_compatible(target_type, s["ret"])]
        if not candidates:
            return self.generate_atom(target_type)
        return self.generate_func_call(random.choice(candidates), depth)

    def generate_func_call(self, func_name: str, depth: int = 0) -> str:
        sig  = STDLIB_SIGS[func_name]
        args: list[str] = []
        for arg_type in sig["args"]:
            if arg_type == Type.ANY:
                arg_type = random.choice([Type.INT, Type.STRING, Type.BOOL])
            elif arg_type == Type.NUMBER:
                arg_type = random.choice([Type.INT, Type.FLOAT])
            args.append(self.generate_expression(arg_type, depth + 1))
        return f"{func_name}({', '.join(args)})"


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Generate type-aware MufiZ programs")
    parser.add_argument("--output", type=str, default="corpus/smart_corpus.txt",
                        help="Output file path (default: corpus/smart_corpus.txt)")
    parser.add_argument("--num-programs", type=int, default=100,
                        help="Number of programs to generate (default: 100)")
    args = parser.parse_args()
    
    gen = TypeAwareGenerator()
    programs = []
    for _ in range(args.num_programs):
        programs.append(gen.generate_program(14))
    
    # Write to file
    output = "\n# ---\n".join(programs)
    with open(args.output, "w") as f:
        f.write(output)
    
    print(f"Generated {args.num_programs} programs to {args.output}")
    import os
    size = os.path.getsize(args.output)
    print(f"File size: {size:,} bytes")
