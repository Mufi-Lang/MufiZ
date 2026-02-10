#!/bin/bash
# generate_100k.sh - Convenience script for generating 100K MuFi dataset
# Usage: ./generate_100k.sh [dataset_directory] [cores]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DATASET_DIR="${1:-../mufiz-dataset-100k}"
CORES="${2:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"
MUFIZ_BIN="./zig-out/bin/mufiz"
TARGET_COUNT=100000
BATCH_SIZE=2000

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        MuFi 100K Dataset Generation Script                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo

# Check if MuFi binary exists
if [ ! -f "$MUFIZ_BIN" ]; then
    echo -e "${RED}✗ Error: MuFi binary not found at $MUFIZ_BIN${NC}"
    echo -e "${YELLOW}  Building MuFi...${NC}"
    zig build || {
        echo -e "${RED}✗ Build failed. Please build MuFi manually first.${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ MuFi built successfully${NC}"
fi

# Check if dataset already exists
if [ -d "$DATASET_DIR" ] && [ -f "$DATASET_DIR/metadata.json" ]; then
    echo -e "${YELLOW}⚠ Dataset already exists at: $DATASET_DIR${NC}"
    echo
    python3 tools/manage_dataset.py status --dir "$DATASET_DIR" --mufiz "$MUFIZ_BIN"
    echo
    read -p "$(echo -e ${YELLOW}Resume generation? [Y/n]: ${NC})" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        RESUME="--resume"
    else
        read -p "$(echo -e ${RED}Start fresh? This will DELETE existing programs! [y/N]: ${NC})" -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Aborted.${NC}"
            exit 0
        fi
        RESUME=""
    fi
else
    RESUME=""
fi

echo -e "${BLUE}Configuration:${NC}"
echo -e "  Dataset directory: ${GREEN}$DATASET_DIR${NC}"
echo -e "  CPU cores:         ${GREEN}$CORES${NC}"
echo -e "  Target programs:   ${GREEN}$TARGET_COUNT${NC}"
echo -e "  Batch size:        ${GREEN}$BATCH_SIZE${NC}"
echo -e "  MuFi binary:       ${GREEN}$MUFIZ_BIN${NC}"
echo

# Estimate time
RATE=7  # files per second per core (conservative estimate)
TOTAL_RATE=$((RATE * CORES))
ESTIMATED_SECONDS=$((TARGET_COUNT / TOTAL_RATE))
ESTIMATED_MINUTES=$((ESTIMATED_SECONDS / 60))

echo -e "${YELLOW}Estimated time: ~$ESTIMATED_MINUTES minutes${NC}"
echo

read -p "$(echo -e ${GREEN}Press Enter to start generation...${NC})" -r
echo

# Initialize if needed
if [ ! -f "$DATASET_DIR/metadata.json" ]; then
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Step 1: Initializing Repository${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    python3 tools/manage_dataset.py init \
        --target $TARGET_COUNT \
        --dir "$DATASET_DIR" \
        --mufiz "$MUFIZ_BIN" || {
        echo -e "${RED}✗ Initialization failed${NC}"
        exit 1
    }
    echo -e "${GREEN}✓ Repository initialized${NC}"
    echo
fi

# Generate programs
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 2: Generating Programs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
START_TIME=$(date +%s)

python3 tools/manage_dataset.py generate \
    --count $TARGET_COUNT \
    --cores $CORES \
    --batch $BATCH_SIZE \
    --dir "$DATASET_DIR" \
    --mufiz "$MUFIZ_BIN" \
    $RESUME || {
    echo -e "${RED}✗ Generation failed or interrupted${NC}"
    echo -e "${YELLOW}  Run this script again with the same directory to resume.${NC}"
    exit 1
}

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
DURATION_MIN=$((DURATION / 60))

echo -e "${GREEN}✓ Generation completed in $DURATION_MIN minutes${NC}"
echo

# Validate sample
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 3: Validating Sample${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
python3 tools/manage_dataset.py validate \
    --sample 1000 \
    --dir "$DATASET_DIR" \
    --mufiz "$MUFIZ_BIN" || {
    echo -e "${YELLOW}⚠ Validation found some issues${NC}"
}
echo

# Create archives
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Step 4: Creating Archives${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
ARCHIVE_DIR="$(dirname "$DATASET_DIR")/mufiz-archives"
mkdir -p "$ARCHIVE_DIR"

python3 tools/manage_dataset.py archive \
    --format all \
    --dir "$DATASET_DIR" \
    --output "$ARCHIVE_DIR" \
    --mufiz "$MUFIZ_BIN" || {
    echo -e "${YELLOW}⚠ Archive creation failed${NC}"
}
echo

# Final status
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Final Status${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
python3 tools/manage_dataset.py status \
    --dir "$DATASET_DIR" \
    --mufiz "$MUFIZ_BIN"

echo
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Generation Complete! 🎉                       ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}Dataset location:${NC} $DATASET_DIR"
echo -e "${GREEN}Archives location:${NC} $ARCHIVE_DIR"
echo
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Review dataset: ${YELLOW}cd $DATASET_DIR${NC}"
echo -e "  2. Test programs:  ${YELLOW}$MUFIZ_BIN -r programs/prog_0.mufi${NC}"
echo -e "  3. Share archives: ${YELLOW}ls -lh $ARCHIVE_DIR${NC}"
echo
echo -e "${GREEN}Thank you for using MuFi Dataset Generator!${NC}"
