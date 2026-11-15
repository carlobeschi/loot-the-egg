#!/usr/bin/env bash
# Type-checks the Roblox scripts with luau-lsp (https://github.com/JohnnyMorganz/luau-lsp), outside Studio.
# Needs: the luau-lsp binary, and Roblox's type definitions (globalTypes.d.luau from the luau-lsp repo).
#   LUAU_LSP=/path/to/luau-lsp ROBLOX_DEFS=/path/to/globalTypes.d.luau bash roblox/tools/luau_check.sh
# Prints nothing but log lines when everything is fine. Uses the default (non-strict) mode, which catches
# unknown globals, missing table keys and wrong argument counts without flooding you with type noise.
set -euo pipefail
cd "$(dirname "$0")/.."
LSP="${LUAU_LSP:-luau-lsp}"
DEFS="${ROBLOX_DEFS:?set ROBLOX_DEFS to globalTypes.d.luau}"
MAP="$(mktemp)"
node tools/sourcemap.js > "$MAP"
OUT="$("$LSP" analyze --definitions="$DEFS" --sourcemap="$MAP" src studio-tools 2>&1 | grep -v '^\[INFO\]\|^\[WARN\]' || true)"
rm -f "$MAP"
if [ -n "$OUT" ]; then echo "$OUT"; exit 1; fi
echo "luau-lsp: no problems"
