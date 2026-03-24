#!/bin/bash
#
# Batch process Mina key files: combine private+public and escape JSON key field.
# Usage: ./process-keys.sh [output_dir]
#
# Finds all .pub key files in <output_dir>, pairs each with its private key,
# runs combine-keys.sh and escape_json_key.py, and writes results to
# <output_dir>/combined_keys/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/output}"
COMBINED_DIR="${OUTPUT_DIR}/combined_keys"

# Resolve paths to utilities
COMBINE_SCRIPT="${SCRIPT_DIR}/combine-keys.sh"
ESCAPE_SCRIPT="${SCRIPT_DIR}/escape_json_key.py"

# --- Validate prerequisites ---
if [[ ! -x "$COMBINE_SCRIPT" ]]; then
    echo "Error: combine-keys.sh not found or not executable at ${COMBINE_SCRIPT}" >&2
    exit 1
fi

if [[ ! -f "$ESCAPE_SCRIPT" ]]; then
    echo "Error: escape_json_key.py not found at ${ESCAPE_SCRIPT}" >&2
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but not found in PATH" >&2
    exit 1
fi

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory '${OUTPUT_DIR}' does not exist" >&2
    exit 1
fi

# --- Find all .pub key files (top-level only, not in subdirectories) ---
shopt -s nullglob
PUB_FILES=("${OUTPUT_DIR}"/*.pub)
shopt -u nullglob

if [[ ${#PUB_FILES[@]} -eq 0 ]]; then
    echo "Error: No .pub key files found in ${OUTPUT_DIR}" >&2
    exit 1
fi

echo "Found ${#PUB_FILES[@]} key pairs in ${OUTPUT_DIR}"

# --- Idempotent: clean and recreate combined_keys directory ---
if [[ -d "$COMBINED_DIR" ]]; then
    echo "Cleaning existing ${COMBINED_DIR}/"
    rm -rf "$COMBINED_DIR"
fi
mkdir -p "$COMBINED_DIR"

# --- Process each key pair ---
PROCESSED=0
FAILED=0

for pub_file in "${PUB_FILES[@]}"; do
    # Derive private key path (same name without .pub)
    priv_file="${pub_file%.pub}"
    basename_priv="$(basename "$priv_file")"

    if [[ ! -f "$priv_file" ]]; then
        echo "  SKIP: No private key for $(basename "$pub_file")" >&2
        FAILED=$((FAILED + 1))
        continue
    fi

    # Extract the key type+number suffix (e.g., "bp1", "plain5")
    if [[ "$basename_priv" =~ -(bp[0-9]+)$ ]]; then
        short_name="${BASH_REMATCH[1]}"
    elif [[ "$basename_priv" =~ -(plain[0-9]+)$ ]]; then
        short_name="${BASH_REMATCH[1]}"
    elif [[ "$basename_priv" =~ -(key[0-9]+)$ ]]; then
        short_name="${BASH_REMATCH[1]}"
    else
        echo "  SKIP: Cannot parse key type from ${basename_priv}" >&2
        FAILED=$((FAILED + 1))
        continue
    fi

    out_file="${COMBINED_DIR}/${short_name}.json"
    echo "  Processing ${basename_priv} -> ${short_name}.json"

    # Step 1: Combine private + public key into JSON
    "$COMBINE_SCRIPT" "$priv_file" "$pub_file" "$out_file"

    # Step 2: Escape the key field in-place
    python3 "$ESCAPE_SCRIPT" "$out_file"

    PROCESSED=$((PROCESSED + 1))
done

echo ""
echo "Done. Processed ${PROCESSED} key pairs into ${COMBINED_DIR}/"
if [[ $FAILED -gt 0 ]]; then
    echo "Warning: ${FAILED} key pair(s) skipped due to errors" >&2
    exit 1
fi
