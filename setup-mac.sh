#!/bin/bash

# Backward-compatible entry point: keep old automation on the safe bootstrap path.
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd -P)
exec "$script_dir/bootstrap" "$@"
