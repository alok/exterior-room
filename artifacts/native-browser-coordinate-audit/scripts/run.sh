#!/bin/sh
# Local, offline reproduction. Does not change the repository, its index or shared caches.
set -eu
AUDIT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
AUDIT_BUILD=$(mktemp -d "${TMPDIR:-/tmp}/polynomial-coordinate-audit.XXXXXX")
node "$AUDIT_ROOT/scripts/compare.mjs" --verify
swiftc -module-cache-path "$AUDIT_BUILD/module-cache" \
  "$AUDIT_ROOT/inputs/PolynomialAction.swift" "$AUDIT_ROOT/scripts/main.swift" \
  -o "$AUDIT_BUILD/compare"
"$AUDIT_BUILD/compare" "$AUDIT_ROOT/inputs/polynomial-action-cases.json" > "$AUDIT_BUILD/native-positions.json"
node "$AUDIT_ROOT/scripts/compare.mjs" "$AUDIT_BUILD/native-positions.json" "$AUDIT_BUILD/result.json"
printf 'Reproduction output retained at %s\n' "$AUDIT_BUILD"
