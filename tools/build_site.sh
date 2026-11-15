#!/usr/bin/env bash
# Builds ./dist: the landing page at / and the playable game at /play/
set -e
cd "$(dirname "$0")/.."
rm -rf dist && mkdir -p dist/play
cp site/index.html site/robots.txt dist/
cp game/index.html dist/play/index.html
echo "dist/ ready (landing page + /play/)"
