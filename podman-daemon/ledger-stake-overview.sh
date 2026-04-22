#!/bin/bash
#
# Generate a CSV overview of stake distribution for generated keys.
# Usage: ./ledger-stake-overview.sh [output_dir] [prefix]
#
# Reads .pub key files and genesis.json from <output_dir>, matches keys
# against the ledger, and produces a CSV showing balance, delegated stake,
# and total effective stake for each generated key.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/output}"
PREFIX="${2:-trailblazer-mesa}"
CSV_FILE="${OUTPUT_DIR}/stake-overview.csv"

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "Error: Output directory '${OUTPUT_DIR}' does not exist" >&2
    exit 1
fi

if [[ ! -f "${OUTPUT_DIR}/genesis.json" ]]; then
    echo "Error: genesis.json not found in ${OUTPUT_DIR}" >&2
    exit 1
fi

if ! command -v python3 &>/dev/null; then
    echo "Error: python3 is required but not found in PATH" >&2
    exit 1
fi

python3 - "$OUTPUT_DIR" "$PREFIX" "$CSV_FILE" << 'PYEOF'
import csv
import glob
import json
import os
import sys
from collections import defaultdict

output_dir = sys.argv[1]
prefix = sys.argv[2]
csv_file = sys.argv[3]

# --- Build pubkey -> name map from .pub files ---
pubmap = {}
pub_files = glob.glob(os.path.join(output_dir, f"{prefix}-*.pub"))
if not pub_files:
    print(f"Error: No .pub files matching '{prefix}-*' in {output_dir}", file=sys.stderr)
    sys.exit(1)

for path in pub_files:
    basename = os.path.basename(path).replace(".pub", "").replace(f"{prefix}-", "")
    with open(path) as f:
        pubmap[f.read().strip()] = basename

# --- Load ledger ---
with open(os.path.join(output_dir, "genesis.json")) as f:
    accounts = json.load(f)

acct_by_pk = {a["pk"]: a for a in accounts}

# --- Compute delegated stake per key ---
delegated_stake = defaultdict(float)
delegator_count = defaultdict(int)

for a in accounts:
    delegate = a.get("delegate", a["pk"])
    if delegate in pubmap and delegate != a["pk"]:
        delegated_stake[delegate] += float(a["balance"])
        delegator_count[delegate] += 1

# --- Sort keys: bp first (numeric), then plain (numeric) ---
def sort_key(name):
    kind = name.rstrip("0123456789")
    num = int(name[len(kind):]) if name[len(kind):] else 0
    order = 0 if kind == "bp" else 1
    return (order, num)

sorted_names = sorted(pubmap.items(), key=lambda kv: sort_key(kv[1]))

# --- Write CSV ---
rows = []
for pk, name in sorted_names:
    acct = acct_by_pk.get(pk)
    if acct:
        balance = float(acct["balance"])
        delegate = acct.get("delegate", pk)
        self_delegated = delegate == pk
    else:
        balance = 0.0
        self_delegated = True
        delegate = pk

    ds = delegated_stake.get(pk, 0.0)
    dc = delegator_count.get(pk, 0)
    total = balance + ds

    # Resolve delegate name if it's one of our keys
    delegate_name = pubmap.get(delegate, "external") if not self_delegated else "self"

    rows.append({
        "name": name,
        "pubkey": pk,
        "balance": f"{balance:.2f}",
        "delegated_stake": f"{ds:.2f}",
        "total_stake": f"{total:.2f}",
        "delegators": dc,
        "delegates_to": delegate_name,
    })

grand_total = sum(float(r["total_stake"]) for r in rows)

for r in rows:
    ts = float(r["total_stake"])
    r["pct_total"] = f"{(ts / grand_total * 100):.2f}" if grand_total > 0 else "0.00"

fields = ["name", "pubkey", "balance", "delegated_stake", "total_stake", "pct_total", "delegators", "delegates_to"]

with open(csv_file, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fields)
    writer.writeheader()
    writer.writerows(rows)

# --- Print summary to stdout ---
total_bp_stake = sum(float(r["total_stake"]) for r in rows if r["name"].startswith("bp"))
total_plain_stake = sum(float(r["total_stake"]) for r in rows if r["name"].startswith("plain"))

print(f"Stake overview written to {csv_file}")
print(f"  Keys: {len(rows)} ({sum(1 for r in rows if r['name'].startswith('bp'))} bp, "
      f"{sum(1 for r in rows if r['name'].startswith('plain'))} plain)")
print(f"  BP total stake:    {total_bp_stake:>18,.2f} MINA")
print(f"  Plain total stake: {total_plain_stake:>18,.2f} MINA")
print(f"  Grand total:       {grand_total:>18,.2f} MINA")
PYEOF
