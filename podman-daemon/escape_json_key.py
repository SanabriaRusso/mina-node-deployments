#!/usr/bin/env python3

import json
import sys
import argparse

def escape_key_field(input_file, output_file=None):
    """
    Read JSON file and escape quotes in the 'key' field by converting it to a string.
    """
    try:
        # Read the input JSON file
        with open(input_file, 'r') as f:
            data = json.load(f)

        # Check if 'key' field exists and is a dict
        if 'key' in data and isinstance(data['key'], dict):
            # Convert the key dict to JSON string (this automatically escapes quotes)
            data['key'] = json.dumps(data['key'])

        # Determine output file
        if output_file is None:
            output_file = input_file

        # Write the modified JSON
        with open(output_file, 'w') as f:
            json.dump(data, f, indent=2)

        print(f"Successfully processed {input_file} -> {output_file}")

    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in {input_file}: {e}", file=sys.stderr)
        sys.exit(1)
    except FileNotFoundError:
        print(f"Error: File {input_file} not found", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Escape quotes in the 'key' field of a JSON file by converting it to a string"
    )
    parser.add_argument('input_file', help='Input JSON file path')
    parser.add_argument('-o', '--output', help='Output file path (defaults to input file)')

    args = parser.parse_args()

    escape_key_field(args.input_file, args.output)

if __name__ == '__main__':
    main()