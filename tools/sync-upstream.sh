#!/usr/bin/env bash
# Pull ChatGPT's latest app-source.zip, record it as an "upstream snapshot" commit
# built on top of the previous snapshot, then merge it into the current branch.
# Snapshot commits form their own line of history, so git can 3-way merge
# ChatGPT's changes with ours instead of overwriting them.
set -euo pipefail
URL=${UPSTREAM_ZIP_URL:-https://babylon-workbench-starter.gardengrass19.chatgpt.site/app-source.zip}
APP=babylon-workbench
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
[ -z "$(git status --porcelain)" ] || { echo "Working tree not clean; commit first." >&2; exit 1; }

TMP=$(mktemp -d)
trap 'git worktree remove --force "$TMP/wt" 2>/dev/null || true; rm -rf "$TMP"' EXIT
curl -fsSL -o "$TMP/src.zip" "$URL"
mkdir "$TMP/unz" && unzip -q "$TMP/src.zip" -d "$TMP/unz"
SRC="$TMP/unz/$APP"; [ -d "$SRC" ] || SRC="$TMP/unz"
SUM=$(sha256sum "$TMP/src.zip" | cut -c1-12)

PREV=$(git log --format=%H -1 --grep='^upstream snapshot' || true)
if git log --format=%B -1 --grep='^upstream snapshot' | grep -q "zip-sha256: $SUM"; then
  echo "Upstream unchanged ($SUM)."; exit 0
fi

git worktree add -q --detach "$TMP/wt" "${PREV:-HEAD}"
rm -rf "$TMP/wt/$APP" && mkdir -p "$TMP/wt/$APP" && cp -a "$SRC/." "$TMP/wt/$APP/"
git -C "$TMP/wt" add -A "$APP"
if git -C "$TMP/wt" diff --cached --quiet; then
  echo "Upstream content unchanged."; exit 0
fi
git -C "$TMP/wt" commit -q -m "upstream snapshot $(date -u +%Y-%m-%dT%H:%MZ)" -m "Source: $URL
zip-sha256: $SUM"
SNAP=$(git -C "$TMP/wt" rev-parse HEAD)
echo "Snapshot $SNAP:"; git diff --stat "${PREV:-HEAD}" "$SNAP" -- "$APP" | tail -1
git merge --no-edit -m "Merge upstream snapshot $SUM" "$SNAP"
