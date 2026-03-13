/* smoke.c — quick integration test for the Swift FFI dylib.
 *
 * Build via:  make smoke
 * Or manually:
 *   clang -o /tmp/mufi_smoke tests/smoke.c \
 *         -I include -L target/release -lmufi_neural \
 *         -Wl,-rpath,$(pwd)/target/release
 *   TOKENIZER=tokenizer.json CHECKPOINT=checkpoints/epoch_020.safetensors \
 *     /tmp/mufi_smoke
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "mufi_neural.h"

static void fail(const char *msg) {
    fprintf(stderr, "FAIL: %s\n", msg);
    exit(1);
}

int main(void) {
    const char *tok  = getenv("TOKENIZER");
    const char *ckpt = getenv("CHECKPOINT");
    if (!tok || !ckpt) {
        fprintf(stderr, "Set TOKENIZER and CHECKPOINT env vars.\n");
        return 1;
    }

    /* ── completion ── */
    printf("→ mufi_complete ... ");
    fflush(stdout);
    char *completions = mufi_complete(tok, ckpt, "var x = 10;\nvar y = ", 5);
    if (!completions) fail("mufi_complete returned NULL");
    if (strstr(completions, "text") == NULL)
        fail("completion JSON missing 'text' field");
    printf("OK\n%s\n\n", completions);
    mufi_free_string(completions);

    /* ── diagnostics (clean code — expect empty array) ── */
    printf("→ mufi_diagnose (clean) ... ");
    fflush(stdout);
    char *diags_clean = mufi_diagnose(tok, ckpt, "fun add(a, b) { return a + b; }");
    if (!diags_clean) fail("mufi_diagnose returned NULL");
    printf("OK\n%s\n\n", diags_clean);
    mufi_free_string(diags_clean);

    /* ── diagnostics (injected error) ── */
    printf("→ mufi_diagnose (injected error) ... ");
    fflush(stdout);
    char *diags_err = mufi_diagnose(tok, ckpt,
        "var x = 10; else { var y = 20; }");
    if (!diags_err) fail("mufi_diagnose returned NULL");
    printf("OK\n%s\n\n", diags_err);
    mufi_free_string(diags_err);

    printf("All smoke tests passed.\n");
    return 0;
}
