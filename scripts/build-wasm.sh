#!/bin/bash
set -e

# Build directory
OUTPUT_DIR="zig-out/wasm"
mkdir -p "$OUTPUT_DIR"

echo "Building MufiZ WebAssembly module..."

# Find clap path
CLAP_PATH=$(find /Users/mustafif/.cache/zig/p -name "clap.zig" | head -n 1)

# Compile wasm.zig to WASM
# We only provide root and clap, let lib.zig handle imports from build.zig options if possible
# Or just use -D flags if we were using zig build, but here we are using zig build-lib
zig build-lib \
  -target wasm32-wasi \
  -dynamic \
  -rdynamic \
  --name mufiz \
  -O ReleaseSmall \
  -Mroot=src/wasm.zig \
  -Mclap="$CLAP_PATH"

mv mufiz.wasm "$OUTPUT_DIR/"
rm -f mufiz.wasm.o mufiz.h

echo "WASM build complete: $OUTPUT_DIR/mufiz.wasm"
