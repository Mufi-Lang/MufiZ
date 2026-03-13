/**
 * mufi_neural.h — C header for the MufiZ Neural LSP Engine FFI.
 *
 * Link against libmufi_neural.dylib (macOS) or libmufi_neural.so (Linux).
 *
 * Swift bridging
 * --------------
 * Add this header to your Swift package's bridging header or modulemap:
 *
 *   // BridgingHeader.h
 *   #include "mufi_neural.h"
 *
 * Then call from Swift:
 *
 *   let json = mufi_complete(tokenizerPath, checkpointPath, source, 8)!
 *   let result = String(cString: json)
 *   mufi_free_string(json)
 */

#ifndef MUFI_NEURAL_H
#define MUFI_NEURAL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

/**
 * Return the top-`top_n` completion candidates for `source` as a
 * heap-allocated JSON string.
 *
 * JSON shape:
 *   [{ "token": "var", "probability": 0.42 }, ...]
 *
 * @param tokenizer_path  Path to tokenizer.json (UTF-8, null-terminated).
 * @param checkpoint_path Path to epoch_NNN.safetensors (UTF-8, null-terminated).
 * @param source          MufiZ source text at the cursor position.
 * @param top_n           Number of candidates to return (1–32).
 * @return                Heap-allocated JSON string, or NULL on error.
 *                        Caller MUST free with mufi_free_string().
 */
char *mufi_complete(
    const char *tokenizer_path,
    const char *checkpoint_path,
    const char *source,
    uint32_t    top_n
);

/**
 * Return per-token diagnostic items for `source` as a heap-allocated JSON string.
 *
 * JSON shape:
 *   [{
 *     "token":       "else",
 *     "start_byte":  12,
 *     "end_byte":    16,
 *     "perplexity":  1074383.0,
 *     "severity":    "error",
 *     "message":     "Unexpected `else` here ..."
 *   }, ...]
 *
 * @param tokenizer_path  Path to tokenizer.json (UTF-8, null-terminated).
 * @param checkpoint_path Path to epoch_NNN.safetensors (UTF-8, null-terminated).
 * @param source          MufiZ source text.
 * @return                Heap-allocated JSON string, or NULL on error.
 *                        Caller MUST free with mufi_free_string().
 */
char *mufi_diagnose(
    const char *tokenizer_path,
    const char *checkpoint_path,
    const char *source
);

/**
 * Free a string returned by mufi_complete() or mufi_diagnose().
 * Safe to call with NULL.
 *
 * @param ptr  Pointer previously returned by mufi_complete / mufi_diagnose.
 */
void mufi_free_string(char *ptr);

#ifdef __cplusplus
}
#endif

#endif /* MUFI_NEURAL_H */
