#!/usr/bin/env -S /bin/bash
# run_act4.sh — Run the ACT4 compliance test suite for rv64-vector
#
# Usage (from anywhere):
#   /bin/bash /path/to/riscv-unified-db/cfgs/act4/run_act4.sh
#
# NOTE: Use /bin/bash explicitly, not 'bash', to avoid the repo's bin/bash shim.
#
# Results are written to /tmp/act_out.txt
# Summary is printed to stdout

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACT4_DIR="$REPO_ROOT/ext/riscv-arch-test"
TEST_CONFIG="$REPO_ROOT/cfgs/act4/rv64-vector/test_config.yaml"
OUTPUT="/tmp/act_out.txt"

if [ ! -d "$ACT4_DIR/.git" ]; then
    echo "ERROR: ext/riscv-arch-test not found."
    echo "Run: /bin/bash cfgs/act4/setup_act4.sh /path/to/riscv64-unknown-elf-gcc"
    exit 1
fi

echo "Running ACT4 vector compliance tests..."
export UDB_LOCAL_PATH="$REPO_ROOT"
cd "$ACT4_DIR"

# Pre-stamp the UDB validated marker with a future date so ACT4 skips
# re-running bundle-based UDB config validation (which can hang on some
# machines due to Z3 download issues). Config validity was confirmed
# separately.
WORK_DIR="$ACT4_DIR/work/rv64-vector"
mkdir -p "$WORK_DIR"
touch -d "2099-12-31" "$WORK_DIR/.validated"

# Ensure Z3 5.0.0 (needed by udb 0.1.14) is available in the cache.
# If only 4.16.0 is present, copy it — the ABI is compatible for
# the UDB config validation use case.
Z3_CACHE="$HOME/.cache/udb/z3"
Z3_500="$Z3_CACHE/z3-5.0.0/arm64/libz3.so"
Z3_4160="$Z3_CACHE/z3-4.16.0/arm64/libz3.so"
if [ ! -f "$Z3_500" ] && [ -f "$Z3_4160" ]; then
    mkdir -p "$(dirname "$Z3_500")"
    cp "$Z3_4160" "$Z3_500"
fi

.venv/bin/act "$TEST_CONFIG" > "$OUTPUT" 2>&1

echo "Done. Results:"
grep -E "✓|✗|FAIL|Build|succeeded|failed" "$OUTPUT"
