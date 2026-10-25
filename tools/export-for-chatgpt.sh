#!/usr/bin/env bash
# Write outbox/changes.patch (our edits relative to the last ChatGPT snapshot)
# and outbox/app-source.zip (full current source) for handing back to ChatGPT.
set -euo pipefail
APP=babylon-workbench
ROOT=$(git rev-parse --show-toplevel)
cd "$ROOT"
BASE=$(git log --format=%H -1 --grep='^upstream snapshot')
mkdir -p outbox
git diff "$BASE" HEAD -- "$APP" > outbox/changes.patch
git archive --format=zip -o outbox/app-source.zip HEAD "$APP"
echo "Base snapshot: $(git log --format='%h %s' -1 "$BASE")"
git diff --stat "$BASE" HEAD -- "$APP" | tail -1
echo "Wrote outbox/changes.patch and outbox/app-source.zip"
