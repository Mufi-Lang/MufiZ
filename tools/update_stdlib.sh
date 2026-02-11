#!/bin/bash
# Convenience script to update stdlib functions and generate test data

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "================================"
echo "MufiZ Stdlib Update Utility"
echo "================================"
echo ""

# Step 1: Extract stdlib functions
echo "Step 1: Extracting stdlib functions from source..."
python3 tools/extract_stdlib.py

if [ ! -f "tools/stdlib_functions.json" ]; then
    echo "Error: Failed to generate stdlib_functions.json"
    exit 1
fi

FUNC_COUNT=$(python3 -c "import json; print(json.load(open('tools/stdlib_functions.json'))['total_count'])")
echo "✓ Extracted $FUNC_COUNT standard library functions"
echo ""

# Step 2: Show module breakdown
echo "Step 2: Module breakdown:"
python3 -c "
import json
with open('tools/stdlib_functions.json') as f:
    data = json.load(f)
    for module in sorted(data['by_module'].keys()):
        count = len(data['by_module'][module])
        print(f'  {module:12} {count:3} functions')
"
echo ""

# Step 3: Optionally generate test data
if [ "$1" = "--generate" ] || [ "$1" = "-g" ]; then
    COUNT="${2:-10}"
    OUTPUT_DIR="${3:-./test_dataset}"

    echo "Step 3: Generating $COUNT test programs..."
    python3 tools/mufiz_dataset_gen.py --count "$COUNT" --output "$OUTPUT_DIR"
    echo "✓ Test data generated in $OUTPUT_DIR"
else
    echo "Step 3: Skipping test data generation"
    echo "  (use --generate to generate test programs)"
fi

echo ""
echo "================================"
echo "Update complete!"
echo "================================"
echo ""
echo "Usage:"
echo "  $0                    # Extract stdlib only"
echo "  $0 --generate         # Extract + generate 10 test programs"
echo "  $0 -g 100 ./output    # Extract + generate 100 programs to ./output"
echo ""
