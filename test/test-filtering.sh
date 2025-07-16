#!/usr/bin/env bash
set -euo pipefail

# Test script to demonstrate improved rsync include/exclude functionality
# This script shows how the updated rule ordering properly handles complex filtering

echo "=== Testing Improved Rsync Include/Exclude Functionality ==="

# Create test directory structure
TEST_DIR="$(mktemp -d)"
SRC_DIR="$TEST_DIR/source"
DEST_DIR="$TEST_DIR/dest"

mkdir -p "$SRC_DIR"/{kustomize/{base,overlays,protected},src/{main,test},docs,build,node_modules}

# Create some test files
touch "$SRC_DIR/kustomize/base/deployment.yaml"
touch "$SRC_DIR/kustomize/overlays/prod.yaml"
touch "$SRC_DIR/kustomize/protected/secret.yaml"
touch "$SRC_DIR/src/main/app.py"
touch "$SRC_DIR/src/test/test_app.py"
touch "$SRC_DIR/docs/README.md"
touch "$SRC_DIR/build/artifact.jar"
touch "$SRC_DIR/node_modules/package.json"
touch "$SRC_DIR/root-file.txt"

echo "Created test structure:"
find "$SRC_DIR" -type f | sort

# Function to test rsync with given parameters
test_rsync() {
    local description="$1"
    shift
    local dest_subdir
    dest_subdir="$DEST_DIR/$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')"
    mkdir -p "$dest_subdir"
    
    echo ""
    echo "=== $description ==="
    echo "Command: rsync -av $* $SRC_DIR/ $dest_subdir/"
    rsync -av "$@" "$SRC_DIR/" "$dest_subdir/"
    echo "Result:"
    find "$dest_subdir" -type f | sort | sed "s|$dest_subdir/||"
}

# Test Case 1: Include only kustomize
test_rsync "Include Only Kustomize" \
    --include='kustomize/***' --exclude='*'

# Test Case 2: Include kustomize but exclude protected (FIXED VERSION)
test_rsync "Include Kustomize Exclude Protected - FIXED" \
    --include='kustomize/' --exclude='kustomize/protected/***' --include='kustomize/***' --exclude='*'

# Test Case 3: Multiple includes with nested paths
test_rsync "Multiple Includes with Excludes" \
    --include='kustomize/' --exclude='kustomize/protected/***' --include='kustomize/***' \
    --include='src/' --exclude='src/test/***' --include='src/***' \
    --include='docs/***' \
    --exclude='*'

# Test Case 4: Complex real-world scenario
test_rsync "Real-world Complex Filtering" \
    --include='kustomize/' --exclude='kustomize/protected/***' --include='kustomize/***' \
    --include='src/' --exclude='src/test/***' --include='src/***' \
    --include='docs/***' \
    --exclude='build/***' --exclude='node_modules/***' --exclude='*.log' --exclude='*.tmp' \
    --exclude='*'

echo ""
echo "=== Comparison: Before vs After Fix ==="
echo ""
echo "BEFORE (incorrect rule order):"
echo "  --include=kustomize/ --include=kustomize/*** --exclude=kustomize/protected --exclude=*"
echo "  Result: Still includes protected/ because exclude comes after broad include"
echo ""
echo "AFTER (correct rule order):"
echo "  --include=kustomize/ --exclude=kustomize/protected/*** --include=kustomize/*** --exclude=*"
echo "  Result: Properly excludes protected/ because exclude comes before broad include"

echo ""
echo "=== Rule Generation Logic ==="
cat << 'EOF'
The improved system generates rules in this order:

1. Directory traversal includes (--include=dir/)
2. Specific excludes (--exclude=dir/subdir/***)  
3. Content includes (--include=dir/***)
4. Final exclude all (--exclude=*)

For RSYNC_INCLUDE=kustomize,src and RSYNC_EXCLUDE=kustomize/protected,src/test:

Generated rules:
  --exclude=.git                          # Base exclusion
  --include=kustomize/                    # Allow traversal
  --include=src/                          # Allow traversal  
  --exclude=kustomize/protected           # Exclude before content include
  --exclude=src/test                      # Exclude before content include
  --include=kustomize/***                 # Include all kustomize content
  --include=src/***                       # Include all src content
  --exclude=*                             # Exclude everything else
EOF

echo ""
echo "=== Test Results Summary ==="
echo "Test directory: $TEST_DIR"
echo "Source structure:"
find "$SRC_DIR" -type f | sort | sed "s|$SRC_DIR/||"

echo ""
echo "All test results are in: $DEST_DIR"
echo "To clean up: rm -rf $TEST_DIR" 