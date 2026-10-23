#!/bin/sh
set -eu
EXTERIOR_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$EXTERIOR_ROOT"
python3 lean/build.py
exec python3 server.py "$@"
