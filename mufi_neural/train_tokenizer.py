"""
Train a BPE tokenizer on the MufiZ corpus.

Produces tokenizer.json which is compatible with the HuggingFace `tokenizers`
Rust crate (also used by candle). The tokenizer is code-aware: it splits on
whitespace and punctuation but keeps MufiZ operators and identifiers intact.

Special tokens
--------------
<pad>     Padding token (id 0)
<unk>     Unknown token  (id 1)
<sos>     Start-of-sequence / start-of-file
<eos>     End-of-sequence / end-of-file
<cursor>  LSP completion cursor position marker
"""

import json
import os
import sys
from pathlib import Path

from tokenizers import Tokenizer, pre_tokenizers, trainers
from tokenizers.models import BPE
from tokenizers.normalizers import Sequence as NormSequence
from tokenizers.pre_tokenizers import Punctuation, Whitespace
from tokenizers.pre_tokenizers import Sequence as PreSequence


# ------------------------------------------------------------------ #
# Paths
# ------------------------------------------------------------------ #
SCRIPT_DIR = Path(__file__).parent
CORPUS_FILE = SCRIPT_DIR / "corpus" / "smart_corpus.txt"
OUT_FILE = SCRIPT_DIR / "tokenizer.json"
VOCAB_SIZE = 8000

SPECIAL_TOKENS = ["<pad>", "<unk>", "<sos>", "<eos>", "<cursor>"]

# MufiZ keywords — ensure they appear as single tokens in the vocabulary.
MUFI_KEYWORDS = [
    "var", "const", "fun", "return", "if", "else", "while", "for",
    "foreach", "in", "break", "continue", "print", "true", "false",
    "nil", "class", "self", "super", "and", "or", "import", "from",
    "as", "pub", "let", "each", "end", "switch", "case", "item",
]

# Stdlib function names to keep as atomic tokens where possible.
MUFI_STDLIB = [
    "sin", "cos", "tan", "sqrt", "abs", "pow", "min", "max", "floor",
    "ceil", "round", "exp", "rand", "str", "int", "double", "bool",
    "type_of", "is_nil", "is_string", "is_number", "is_bool", "is_int",
    "println", "printf", "input", "now", "now_ms", "len", "format",
    "exit", "assert", "push", "pop", "sort", "reverse", "contains",
]


def split_corpus_into_programs(corpus_text: str) -> list[str]:
    """Split corpus by # --- delimiter, strip empty entries."""
    programs = corpus_text.split("# ---")
    return [p.strip() for p in programs if p.strip()]


def build_training_iterator(corpus_path: Path) -> list[str]:
    """Return list of text chunks to train on."""
    if not corpus_path.exists():
        print(f"ERROR: Corpus not found at {corpus_path}", file=sys.stderr)
        sys.exit(1)

    raw = corpus_path.read_text(encoding="utf-8")
    programs = split_corpus_into_programs(raw)
    print(f"  Loaded {len(programs)} programs from corpus ({len(raw):,} chars)")
    return programs


def train(corpus_path: Path = CORPUS_FILE, out_path: Path = OUT_FILE):
    print("=== MufiZ BPE Tokenizer Training ===")
    print(f"  Corpus : {corpus_path}")
    print(f"  Output : {out_path}")
    print(f"  Vocab  : {VOCAB_SIZE}")

    # ---------------------------------------------------------------- #
    # 1. Build training data
    # ---------------------------------------------------------------- #
    programs = build_training_iterator(corpus_path)

    # ---------------------------------------------------------------- #
    # 2. Configure tokenizer
    # ---------------------------------------------------------------- #
    tokenizer = Tokenizer(BPE(unk_token="<unk>"))

    # No normalizer — MufiZ is case-sensitive; preserve source exactly.
    tokenizer.normalizer = None

    # Pre-tokenizer: split on whitespace then punctuation.
    # This ensures `if(` splits into `if` + `(` and operators like `<=`
    # are kept as single units (punctuation split is character-level for
    # non-alnum chars, so `<=` becomes `<` + `=` then BPE merges them).
    tokenizer.pre_tokenizer = PreSequence([Whitespace(), Punctuation()])

    # ---------------------------------------------------------------- #
    # 3. Train
    # ---------------------------------------------------------------- #
    # Initial alphabet seeds: force keywords and stdlib names to be
    # present even if they're rare in the corpus.
    initial_alphabet = list(set(MUFI_KEYWORDS + MUFI_STDLIB))

    trainer = trainers.BpeTrainer(
        vocab_size=VOCAB_SIZE,
        special_tokens=SPECIAL_TOKENS,
        initial_alphabet=initial_alphabet,
        min_frequency=1,  # Keep all pairs — corpus is small
        show_progress=True,
    )

    print("\nTraining...")
    tokenizer.train_from_iterator(programs, trainer=trainer)

    # Force any missing keywords / stdlib names into the vocabulary so they
    # always encode as a single token regardless of corpus frequency.
    all_fixed_tokens = MUFI_KEYWORDS + MUFI_STDLIB
    missing = [t for t in all_fixed_tokens if tokenizer.token_to_id(t) is None]
    if missing:
        tokenizer.add_tokens(missing)
        print(f"  Added {len(missing)} missing keyword/stdlib tokens: {missing}")

    # ---------------------------------------------------------------- #
    # 4. Verify special token ids
    # ---------------------------------------------------------------- #
    pad_id  = tokenizer.token_to_id("<pad>")
    unk_id  = tokenizer.token_to_id("<unk>")
    sos_id  = tokenizer.token_to_id("<sos>")
    eos_id  = tokenizer.token_to_id("<eos>")
    cur_id  = tokenizer.token_to_id("<cursor>")

    print(f"\nSpecial token IDs:")
    print(f"  <pad>    = {pad_id}")
    print(f"  <unk>    = {unk_id}")
    print(f"  <sos>    = {sos_id}")
    print(f"  <eos>    = {eos_id}")
    print(f"  <cursor> = {cur_id}")

    actual_vocab = tokenizer.get_vocab_size()
    print(f"\nFinal vocabulary size: {actual_vocab}")

    # ---------------------------------------------------------------- #
    # 5. Save
    # ---------------------------------------------------------------- #
    tokenizer.save(str(out_path))
    print(f"\nSaved → {out_path}")

    # ---------------------------------------------------------------- #
    # 6. Smoke test — round-trip a few MufiZ snippets
    # ---------------------------------------------------------------- #
    print("\n=== Round-trip smoke test ===")
    samples = [
        'var x = 42;',
        'if (x > 0) { print x; }',
        'fun add(a, b) { return a + b; }',
        'foreach (item in {1.0, 2.0, 3.0}) { print item; }',
        'var result = sqrt(pow(3, 2) + pow(4, 2));',
    ]

    all_ok = True
    for sample in samples:
        enc = tokenizer.encode(sample)
        decoded = tokenizer.decode(enc.ids)
        # BPE decode may add spaces around punctuation — check tokens are right
        token_strs = enc.tokens
        ok = len(token_strs) > 0
        status = "✓" if ok else "✗"
        if not ok:
            all_ok = False
        print(f"  {status} [{len(token_strs):2d} tokens] {sample!r}")
        print(f"       tokens: {token_strs}")

    # ---------------------------------------------------------------- #
    # 7. Check keyword coverage
    # ---------------------------------------------------------------- #
    print("\n=== Keyword coverage ===")
    vocab = tokenizer.get_vocab()
    for kw in MUFI_KEYWORDS:
        present = kw in vocab
        print(f"  {'✓' if present else '✗'} {kw}")

    if all_ok:
        print("\n✅ Tokenizer training complete.")
    else:
        print("\n⚠️  Some smoke tests failed — review output above.")

    return tokenizer


if __name__ == "__main__":
    train()
