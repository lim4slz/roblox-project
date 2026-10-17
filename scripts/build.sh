#!/usr/bin/env bash
# Builds everything from source:
#   1. generates the map/tool/audio models with Lune   -> assets/*.rbxm
#   2. assembles the place with Rojo                   -> build/DoomspireBrickbattle.rbxl
#   3. runs the test suite
#   4. packages the deliverable                        -> dist/DoomspireBrickbattle.zip
#
# Needs rojo and lune on PATH (`rokit install` sets up the pinned versions).
# Set SKIP_TESTS=1 to skip step 3.
set -euo pipefail

cd "$(dirname "$0")/.."

PLACE=DoomspireBrickbattle

echo "==> Generating map assets"
lune run map/build.luau

echo "==> Building place"
mkdir -p build dist
rojo build default.project.json --output "build/$PLACE.rbxl"

if [[ "${SKIP_TESTS:-0}" != "1" ]]; then
	echo "==> Running tests"
	lune run tests/run.luau
fi

echo "==> Packaging"
cp "build/$PLACE.rbxl" "dist/$PLACE.rbxl"
rm -f "dist/$PLACE.zip"
zip -qr "dist/$PLACE.zip" \
	"dist/$PLACE.rbxl" \
	README.md LICENSE default.project.json rokit.toml stylua.toml .luaurc \
	src map assets tests scripts docs \
	-x "*.DS_Store"
echo "Wrote dist/$PLACE.zip"
