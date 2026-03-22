#!/usr/bin/env bash
# Publishes the current docs/ tree to branch gh-pages (orphan history), matching
# .github/workflows/deploy-docs.yml + peaceiris force_orphan behavior.
# Requires: git, push access to origin (SSH or HTTPS with credential).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
cp -a "$ROOT/docs/." "$TMP/"
cd "$TMP"
git init -q
git checkout -q -b gh-pages
git add -A
git -c user.email="deploy@local" -c user.name="docs deploy" commit -q -m "Deploy docs $(date -u +%Y-%m-%dT%H:%MZ)"
REMOTE="$(git -C "$ROOT" remote get-url origin)"
git remote add origin "$REMOTE"
git push -f origin gh-pages
echo "OK: pushed docs to gh-pages ($REMOTE)"
