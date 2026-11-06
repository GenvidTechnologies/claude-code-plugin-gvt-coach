#!/usr/bin/env bash
# Org-specific leak grep over tracked files. Called by .github/workflows/leak-guard.yml
# and by .gvt-agent.json commands.validate, so the rules live in one place and a
# violation fails the local gate, not only CI. Exits 1 on any hit.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Always blocked, everywhere: local filesystem paths and usernames
# are never legitimate in a committed file. The pattern also blocks
# private organization and project names.
always='C:/repos/|C:/Users/|fninoles|genvid-holdings|burbank'
# Exclude the files that define the patterns above, which would self-match.
guard=(':!.github/workflows/leak-guard.yml' ':!.github/scripts/leak-guard.sh')
found=0
# xargs exits 123 when every grep finds nothing, which is the clean case.
if git ls-files -z -- "${guard[@]}" | xargs -0 grep -nE "$always"; then
  echo "::error::leak pattern found (local path, username or private name — blocked everywhere)"
  found=1
fi
if [ "$found" -ne 0 ]; then exit 1; fi
echo "no leak patterns found"
