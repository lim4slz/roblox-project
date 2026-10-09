#!/usr/bin/env bash
# Strict Luau type-check of the game source with Roblox type definitions.
# Usage: scripts/analyze.sh            (downloads definitions on first run)
set -euo pipefail
cd "$(dirname "$0")/.."

LUAU_LSP_VERSION="1.70.1"
DEFS=".cache/globalTypes.d.luau"

if [ ! -f "$DEFS" ]; then
	mkdir -p .cache
	echo "Downloading Roblox type definitions (luau-lsp ${LUAU_LSP_VERSION})..."
	curl -sSfL -o "$DEFS" \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/${LUAU_LSP_VERSION}/scripts/globalTypes.None.d.luau"
fi

rojo sourcemap default.project.json --output sourcemap.json

luau-lsp analyze \
	--sourcemap=sourcemap.json \
	--definitions=@roblox="$DEFS" \
	--platform=roblox \
	--ignore="vendor/**" \
	src
