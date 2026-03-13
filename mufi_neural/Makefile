# mufi_neural Makefile
#
# Targets:
#   make           — build the release dylib + binary
#   make swift     — copy dylib + header to swift-pkg/ for use in a Swift package
#   make smoke     — run a quick C smoke test against the dylib
#   make clean     — remove build artifacts

CARGO        := cargo
RELEASE_DIR  := target/release
DYLIB        := $(RELEASE_DIR)/libmufi_neural.dylib
HEADER       := include/mufi_neural.h
SWIFT_OUT    := swift-pkg/Sources/MufiNeural

# Default checkpoint / tokenizer paths used by smoke test
TOKENIZER    ?= tokenizer.json
CHECKPOINT   ?= checkpoints/epoch_020.safetensors

.PHONY: all swift smoke clean

all:
	$(CARGO) build --release

## ── Swift package ──────────────────────────────────────────────────────────
# Copies the dylib and C header into a Swift package stub so you can add
# mufi_neural as a local binary target.
swift: all
	mkdir -p $(SWIFT_OUT)/include
	cp $(DYLIB)  $(SWIFT_OUT)/libmufi_neural.dylib
	cp $(HEADER) $(SWIFT_OUT)/include/mufi_neural.h
	@echo ""
	@echo "✅  Swift artefacts written to $(SWIFT_OUT)/"
	@echo "    Add to your Swift package with:"
	@echo "      .binaryTarget(name: \"MufiNeural\","
	@echo "                    path: \"Sources/MufiNeural/libmufi_neural.dylib\")"
	@echo ""
	@echo "    Bridging header:"
	@echo "      #include \"mufi_neural.h\""

## ── C smoke test ───────────────────────────────────────────────────────────
# Compiles a tiny C program that loads the dylib at link time and calls
# mufi_complete / mufi_diagnose on a trivial source snippet.
smoke: all
	@echo "Building smoke test..."
	clang -o /tmp/mufi_smoke \
	    tests/smoke.c \
	    -I include \
	    -L $(RELEASE_DIR) -lmufi_neural \
	    -Wl,-rpath,$(CURDIR)/$(RELEASE_DIR)
	@echo "Running smoke test..."
	TOKENIZER=$(TOKENIZER) CHECKPOINT=$(CHECKPOINT) /tmp/mufi_smoke
	@echo "✅  Smoke test passed."

clean:
	$(CARGO) clean
	rm -f /tmp/mufi_smoke
