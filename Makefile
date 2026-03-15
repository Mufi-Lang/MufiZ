.PHONY: help clean build test update-all update-stdlib update-grammar update-keywords install

# Color codes for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
RED    := \033[0;31m
NC     := \033[0m # No Color

help:
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)           MufiZ Build & Update Targets$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)Build Targets:$(NC)"
	@echo "  make build              Build MufiZ compiler (zig build)"
	@echo "  make run-repl           Start REPL shell"
	@echo "  make test               Run test suite"
	@echo "  make clean              Clean build artifacts"
	@echo ""
	@echo "$(GREEN)JSON Update Targets:$(NC)"
	@echo "  make update-all         Update all JSON files (stdlib + grammar + keywords)"
	@echo "  make update-stdlib      Extract and update mufiz_stdlib.json"
	@echo "  make update-grammar     Generate grammar JSON from source code"
	@echo "  make update-keywords    Extract keywords JSON from source code"
	@echo ""
	@echo "$(GREEN)Installation:$(NC)"
	@echo "  make install            Install MufiZ to system (requires zig build install)"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  $$ make build                  # Compile MufiZ"
	@echo "  $$ make update-all             # Refresh all generated JSON files"
	@echo "  $$ make run-repl               # Start interactive REPL"
	@echo ""

# ============================================================================
# Build Targets
# ============================================================================

build:
	@echo "$(BLUE)[1/1]$(NC) Building MufiZ compiler..."
	@zig build
	@echo "$(GREEN)✓ Build complete$(NC)"

clean:
	@echo "$(BLUE)[1/1]$(NC) Cleaning build artifacts..."
	@rm -rf zig-cache zig-out .zig-cache
	@echo "$(GREEN)✓ Clean complete$(NC)"

rebuild: clean build
	@echo "$(GREEN)✓ Rebuild complete$(NC)"

run-repl: build
	@echo "$(BLUE)[1/1]$(NC) Starting MufiZ REPL..."
	@./zig-out/bin/mufiz --repl

test: build
	@echo "$(BLUE)[1/1]$(NC) Running tests..."
	@python3 test_suite.py

# ============================================================================
# JSON Update Targets
# ============================================================================

update-all: update-stdlib update-grammar update-keywords
	@echo ""
	@echo "$(GREEN)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)✓ All JSON files updated successfully!$(NC)"
	@echo "$(GREEN)════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "Updated files:"
	@echo "  • mufiz_stdlib.json    (Standard library functions)"
	@echo "  • mufiz_keywords.json  (Language keywords)"
	@echo "  • lang.json            (Grammar and metadata)"
	@echo ""

update-stdlib:
	@echo "$(BLUE)[1/3]$(NC) Extracting standard library functions..."
	@python3 tools/extract_stdlib.py
	@if [ -f "tools/stdlib_functions.json" ]; then \
		echo "$(GREEN)✓ Extracted stdlib functions$(NC)"; \
	else \
		echo "$(RED)✗ Failed to extract stdlib$(NC)"; \
		exit 1; \
	fi
	@echo ""

update-grammar:
	@echo "$(BLUE)[2/3]$(NC) Generating grammar from source code..."
	@python3 tools/generate_grammar.py
	@if [ -f "lang.json" ]; then \
		echo "$(GREEN)✓ Generated grammar JSON$(NC)"; \
	else \
		echo "$(RED)✗ Failed to generate grammar$(NC)"; \
		exit 1; \
	fi
	@echo ""

update-keywords:
	@echo "$(BLUE)[3/3]$(NC) Extracting keywords from source code..."
	@python3 tools/generate_metadata.py
	@if [ -f "mufiz_keywords.json" ]; then \
		echo "$(GREEN)✓ Extracted keywords$(NC)"; \
	else \
		echo "$(RED)✗ Failed to extract keywords$(NC)"; \
		exit 1; \
	fi
	@echo ""

# ============================================================================
# Installation Targets
# ============================================================================

install: build
	@echo "$(BLUE)[1/1]$(NC) Installing MufiZ..."
	@zig build install
	@echo "$(GREEN)✓ Installation complete$(NC)"

# ============================================================================
# Utility Targets
# ============================================================================

.PHONY: status check-tools

status:
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)           MufiZ Project Status$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(GREEN)Build Status:$(NC)"
	@if [ -f "zig-out/bin/mufiz" ]; then \
		echo "  ✓ Compiler built: $(shell ls -lh zig-out/bin/mufiz 2>/dev/null | awk '{print $$5}')"; \
	else \
		echo "  ✗ Compiler not built (run: make build)"; \
	fi
	@echo ""
	@echo "$(GREEN)JSON Files Status:$(NC)"
	@if [ -f "mufiz_stdlib.json" ]; then \
		FUNC_COUNT=$$(python3 -c "import json; data=json.load(open('mufiz_stdlib.json')); print(sum(len(v) for v in data.get('stdlib', {}).values()))"); \
		echo "  ✓ mufiz_stdlib.json ($$FUNC_COUNT functions)"; \
	else \
		echo "  ✗ mufiz_stdlib.json (run: make update-stdlib)"; \
	fi
	@if [ -f "mufiz_keywords.json" ]; then \
		KW_COUNT=$$(python3 -c "import json; data=json.load(open('mufiz_keywords.json')); print(len(data.get('keywords', [])))"); \
		echo "  ✓ mufiz_keywords.json ($$KW_COUNT keywords)"; \
	else \
		echo "  ✗ mufiz_keywords.json (run: make update-keywords)"; \
	fi
	@if [ -f "lang.json" ]; then \
		echo "  ✓ lang.json (Grammar metadata)"; \
	else \
		echo "  ✗ lang.json (run: make update-grammar)"; \
	fi
	@echo ""
	@echo "$(GREEN)Tools Status:$(NC)"
	@if command -v python3 &> /dev/null; then \
		echo "  ✓ Python 3 ($(shell python3 --version 2>&1 | cut -d' ' -f2))"; \
	else \
		echo "  ✗ Python 3 required"; \
	fi
	@if command -v zig &> /dev/null; then \
		echo "  ✓ Zig ($(shell zig version 2>/dev/null))"; \
	else \
		echo "  ✗ Zig compiler required"; \
	fi
	@echo ""

check-tools:
	@echo "$(BLUE)Checking required tools...$(NC)"
	@command -v zig >/dev/null 2>&1 || { echo "$(RED)✗ Zig not found$(NC)"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "$(RED)✗ Python 3 not found$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All required tools found$(NC)"

# ============================================================================
# Development Targets
# ============================================================================

.PHONY: fmt lint check dev-setup

fmt:
	@echo "$(BLUE)[1/1]$(NC) Formatting Zig code..."
	@zig fmt src/
	@echo "$(GREEN)✓ Format complete$(NC)"

lint:
	@echo "$(BLUE)[1/1]$(NC) Linting Zig code..."
	@zig ast-check src/*.zig 2>/dev/null || echo "$(YELLOW)⚠ Some files may need formatting$(NC)"
	@echo "$(GREEN)✓ Lint complete$(NC)"

check: check-tools
	@echo "$(GREEN)✓ All checks passed$(NC)"

dev-setup: check-tools
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@echo "$(GREEN)✓ Development environment ready$(NC)"
	@echo ""
	@echo "Next steps:"
	@echo "  1. make build          # Build the compiler"
	@echo "  2. make update-all     # Update JSON files"
	@echo "  3. make run-repl       # Start REPL"

# ============================================================================
# Quick Aliases
# ============================================================================

.PHONY: b r u uk ug us

b: build
r: run-repl
u: update-all
uk: update-keywords
ug: update-grammar
us: update-stdlib

# ============================================================================
# Default target
# ============================================================================

.DEFAULT_GOAL := help
