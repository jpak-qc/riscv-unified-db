#!/usr/bin/env bash
# setup_act4.sh — Set up the riscv-arch-test framework for ACT4 vector testing
#
# Run from the riscv-unified-db repo root:
#   bash cfgs/act4/setup_act4.sh [/path/to/riscv64-unknown-elf-gcc]
#
# Optional argument: path to a GCC 16+ riscv64-unknown-elf-gcc binary.
# If not provided, the script will auto-detect or skip the compiler update.
#
# This script:
#   1. Clones riscv-arch-test if not already present
#   2. Applies local patches needed for UDB ISS + GCC 16 compatibility
#   3. Updates test_config.yaml with the correct GCC path
#   4. Installs Python dependencies

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACT4_DIR="$REPO_ROOT/ext/riscv-arch-test"
ACT4_COMMIT="288a965"
TEST_CONFIG="$REPO_ROOT/cfgs/act4/rv64-vector/test_config.yaml"
# ACT invokes `bundle` internally. Put mise's generated shims ahead of the
# repository's bin/ wrappers, which otherwise recurse through bin/bash.
export PATH="${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"

# Determine GCC 16 path
GCC_PATH="${1:-}"
if [ -z "$GCC_PATH" ]; then
    # Auto-detect: look for riscv64-unknown-elf-gcc on PATH with version >= 16
    for candidate in riscv64-unknown-elf-gcc $(which riscv64-unknown-elf-gcc 2>/dev/null); do
        ver=$("$candidate" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        major=$(echo "$ver" | cut -d. -f1)
        if [ "${major:-0}" -ge 16 ] 2>/dev/null; then
            GCC_PATH="$candidate"
            break
        fi
    done
fi

echo "=== ACT4 setup for riscv-unified-db ==="
echo "Repo root: $REPO_ROOT"

# Step 1: Clone riscv-arch-test if needed
if [ ! -d "$ACT4_DIR/.git" ]; then
    echo "Cloning riscv-arch-test..."
    git clone https://github.com/riscv/riscv-arch-test.git "$ACT4_DIR"
    git -C "$ACT4_DIR" checkout "$ACT4_COMMIT"
else
    echo "ext/riscv-arch-test already present ($(git -C "$ACT4_DIR" rev-parse --short HEAD))"
fi

# Step 2: Apply patches to the ACT4 Python framework
FRAMEWORK="$ACT4_DIR/framework/src/act"

echo "Patching ACT4 framework for UDB ISS + GCC 16..."

# Patch 1: config.py — lower GCC version requirement to match GCC 16
python3 - "$FRAMEWORK/config.py" << 'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path).read()
content = re.sub(
    r'REQUIRED_GCC_MAJOR_VERSION\s*=\s*\d+.*',
    'REQUIRED_GCC_MAJOR_VERSION = 16',
    content
)
open(path, 'w').write(content)
print(f"  patched {path}")
PYEOF

# Patch 2: select_tests.py — add Sv* to priv extensions and skip tests/priv/ dir
python3 - "$FRAMEWORK/select_tests.py" << 'PYEOF'
import sys, re
path = sys.argv[1]
content = open(path).read()
# Extend PRIV_EXTENSIONS to include Sv* (assembler bugs in upstream arch-test)
content = content.replace(
    'PRIV_EXTENSIONS = {"Sm", "S", "U"}',
    'PRIV_EXTENSIONS = {"Sm", "S", "U", "Sv32", "Sv39", "Sv48", "Sv57"}'
)
# Add in_priv_dir check to also skip tests/priv/ directory when include_priv_tests=False
old = '        # Skip privileged tests if disabled\n        if not include_priv_tests and not test_metadata.required_extensions.isdisjoint(PRIV_EXTENSIONS):\n            continue'
new = '''        # Skip privileged tests if disabled. Also skip any test under a "priv/"
        # directory — upstream arch-test priv tests have assembler bugs (bare
        # register numbers, 64-bit .set expressions) not yet fixed in arch-test.
        in_priv_dir = "priv" in test_metadata.test_path.parts
        if not include_priv_tests and (
            not test_metadata.required_extensions.isdisjoint(PRIV_EXTENSIONS) or in_priv_dir
        ):
            continue'''
if old in content:
    content = content.replace(old, new)
    print(f"  patched {path}")
else:
    print(f"  WARNING: could not find expected text in {path} — may already be patched")
open(path, 'w').write(content)
PYEOF

echo "Patches applied."

# Step 3: Update test_config.yaml with the configured toolchain paths.
if [ -n "$GCC_PATH" ]; then
    echo "Setting compiler_exe to: $GCC_PATH"
    sed -i "s|^compiler_exe:.*|compiler_exe: $GCC_PATH|" "$TEST_CONFIG"
    OBJDUMP_PATH="${GCC_PATH%gcc}objdump"
    if [ -x "$OBJDUMP_PATH" ]; then
        echo "Setting objdump_exe to: $OBJDUMP_PATH"
        sed -i "s|^objdump_exe:.*|objdump_exe: $OBJDUMP_PATH|" "$TEST_CONFIG"
    else
        echo "WARNING: matching objdump not found at: $OBJDUMP_PATH"
    fi
else
    echo "WARNING: GCC 16+ not found. Update compiler_exe in $TEST_CONFIG manually."
    echo "  Pass path as argument: bash cfgs/act4/setup_act4.sh /path/to/riscv64-unknown-elf-gcc"
fi
echo "Setting up Python environment..."
cd "$ACT4_DIR"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
if ! .venv/bin/python -m pip --version >/dev/null 2>&1; then
    # uv-created environments intentionally omit pip.
    .venv/bin/python -m ensurepip --upgrade >/dev/null
fi
.venv/bin/python -m pip install -e framework/ -q
echo "Python environment ready."

# Step 4: Install Ruby gems (requires UDB_LOCAL_PATH for local gem resolution)
echo ""
echo "=== Ruby gem setup ==="
echo "To run ACT4 with local UDB gems, set UDB_LOCAL_PATH before running act:"
echo "  export UDB_LOCAL_PATH=$REPO_ROOT"
echo "  cd $ACT4_DIR"
echo "  UDB_LOCAL_PATH=$REPO_ROOT .venv/bin/act $REPO_ROOT/cfgs/act4/rv64-vector/test_config.yaml"
echo ""
echo "=== Setup complete ==="
echo ""
echo "Build the ISS first:"
echo "  cd $REPO_ROOT && ./do build:iss CONFIG=rv64-vector"
echo ""
echo "Then run ACT4:"
echo "  cd $ACT4_DIR"
echo "  UDB_LOCAL_PATH=$REPO_ROOT .venv/bin/act $REPO_ROOT/cfgs/act4/rv64-vector/test_config.yaml"
