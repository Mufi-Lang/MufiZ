# Grammar generation

This document explains how to generate a human-readable grammar (EBNF) and a
machine-friendly grammar manifest (JSON) from the MufiZ source.

Summary
- I added a small, best-effort generator at `tools/generate_grammar.py`.
- The generator extracts tokens and keywords from `src/scanner_optimized.zig`, and
  precedence + Pratt rule information from `src/compiler.zig` (the `getRule()` table).
- It emits:
  - A readable EBNF grammar: `docs/grammar.ebnf`
  - A JSON manifest for tooling: `manifests/grammar.json`

Quick start
1. Make sure you have Python 3 installed.
2. Run the generator (defaults shown):
   - `python3 tools/generate_grammar.py`
   - Or explicitly: `python3 tools/generate_grammar.py --ebnf docs/grammar.ebnf --json manifests/grammar.json`
   - To also emit Bison/Flex skeletons, run:
     `python3 tools/generate_grammar.py --bison`
3. Inspect the generated files:
   - `docs/grammar.ebnf` — EBNF intended for documentation and human consumption
   - `manifests/grammar.json` — structured representation for tools/scripts
   - If `--bison` was used:
     - `manifests/grammar.y` — Bison grammar skeleton
     - `manifests/lexer.l` — Flex lexer skeleton

What the generator does (high level)
- Reads `src/scanner_optimized.zig` to collect:
  - the `TokenType` enum,
  - the `KEYWORD_TABLE` and keyword strings.
- Reads `src/compiler.zig` to collect:
  - precedence constants (`PREC_*`) and their numeric values,
  - the `getRule()` switch that maps tokens to `prefix`/`infix` handlers and precedence.
- Synthesizes a precedence-based expression grammar (assignment → ternary → or → and → equality → ... → primary), and adds skeleton rules for statements/declarations (e.g. `if`, `for`, `class`, `fun`, `switch`).

Important caveats and limitations
- This is a best-effort, *synthesized* grammar. The generator tries to infer grammar structure from an imperative parser; it does not reverse-engineer a formal grammar perfectly.
- Ambiguities in the language:
  - `{ }` is overloaded: it is a block in statement position and also an object/float-vector literal in expression position. The generator documents both uses, but the context-sensitive distinction remains.
  - `# { ... }` is a hash-table literal (hash-table vs float-vector is distinguished by the `#` token).
  - `[` is used both as a vector/matrix literal prefix and as an indexing operator; parse-time context decides which.
  - `=>` appears both as a `pair` operator and as the `case` marker inside `switch` statements; generator reflects both usages.
- Some behaviors are implemented as semantic logic (e.g., compound assignment like `+=`/`-=` is handled in `namedVariable` rather than via a simple Pratt rule). The generated grammar approximates those cases.
- F-strings (`F_STRING`) are treated as a single token: the parser desugars them into `format` calls; the generator records the token but does not expand interpolation semantics.
- Exponent associativity and a few finer precedence/associativity details are approximated.

How to improve or extend
- Add more detailed analysis of the parser function bodies (e.g., `ifStatement`, `forStatement`, `switchStatement`) to extract more precise right-hand side shapes.
- Add emitters to `tools/generate_grammar.py` to produce other grammar formats:
  - ANTLR (`.g4`)
  - Bison/Yacc (`.y`) + lexer
  - A PEG (`.peg`) grammar
- Add a CI step that runs the generator and:
  - either checks that generated files haven't diverged from the committed versions (fail on diff),
  - or regenerates and commits them as part of a release process.

Examples and tips
- Regenerate the grammar after any syntax-related change (scanner, token table, parser rule table).
- If you add a new token or keyword, consider updating `LITERAL_TOKEN_MAP` in the generator if it is a punctuator (so the EBNF shows a readable symbol instead of a token name).
- If you want the generator to cover more cases (e.g., produce a fully-fledged ANTLR grammar), open an issue or send a PR — I can add an emitter that maps the existing token and precedence info into an ANTLR `g4` file.

Where to look in the code
- Token and keyword definitions: `src/scanner_optimized.zig` (look at `TokenType` and `KEYWORD_TABLE`)
- Parsing rules & precedence: `src/compiler.zig` (look at `PREC_*` and `getRule()`)

If you'd like, I can:
- Add an ANTLR emitter to `tools/generate_grammar.py` and a CI job to validate the generated grammar,
- Or make the generator aim for a stricter, testable grammar by analyzing parse function bodies more precisely.

Thanks — let me know which next step you prefer (ANLTR/Bison emitter, CI integration, or more precise grammar extraction).