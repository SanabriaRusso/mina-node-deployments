#!/bin/bash

# Script to combine Mina private and public key files into JSON format
# Usage: ./combine-keys.sh <private_key_file> <public_key_file> [output_file]

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <private_key_file> <public_key_file> [output_file]"
    echo "Example: $0 pre-mesa-bp1 pre-mesa-bp1.pub bp1.json"
    exit 1
fi

PRIVATE_KEY_FILE="$1"
PUBLIC_KEY_FILE="$2"
OUTPUT_FILE="${3:-combined-key.json}"

# Check if input files exist
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
    echo "Error: Private key file '$PRIVATE_KEY_FILE' not found"
    exit 1
fi

if [ ! -f "$PUBLIC_KEY_FILE" ]; then
    echo "Error: Public key file '$PUBLIC_KEY_FILE' not found"
    exit 1
fi

# Read the private key (JSON format)
PRIVATE_KEY_CONTENT=$(cat "$PRIVATE_KEY_FILE")

# Read the public key (single line)
PUBLIC_KEY_CONTENT=$(cat "$PUBLIC_KEY_FILE" | tr -d '\n\r')

# Create the combined JSON
cat > "$OUTPUT_FILE" << EOF
{
    "key": $PRIVATE_KEY_CONTENT,
    "pub": "$PUBLIC_KEY_CONTENT"
}
EOF

echo "Keys combined successfully into '$OUTPUT_FILE'"