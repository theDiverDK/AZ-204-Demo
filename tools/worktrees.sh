#!/bin/bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Run this script from inside a git repository." >&2
  exit 1
fi
cd "$repo_root"

main_branch="main"
if ! git show-ref --verify --quiet refs/heads/${main_branch}; then
  current="$(git rev-parse --abbrev-ref HEAD)"
  git branch -m "$current" "$main_branch"
fi

branches=(
  "lp/01-init"
  "lp/02-functions"
  "lp/03-storage"
  "lp/04-cosmos"
  "lp/05-container"
  "lp/06-auth"
  "lp/07-keyvault"
  "lp/08-apim"
  "lp/09-events"
  "lp/10-messages"
  "lp/11-appinsight"
)

worktree_dirs=(
  "worktrees/01-init"
  "worktrees/02-functions"
  "worktrees/03-storage"
  "worktrees/04-cosmos"
  "worktrees/05-container"
  "worktrees/06-auth"
  "worktrees/07-keyvault"
  "worktrees/08-apim"
  "worktrees/09-events"
  "worktrees/10-messages"
  "worktrees/11-appinsight"
)

mkdir -p worktrees

for i in "${!branches[@]}"; do
  branch="${branches[$i]}"
  dir="${worktree_dirs[$i]}"

  if ! git show-ref --verify --quiet "refs/heads/${branch}"; then
    git branch "$branch" "$main_branch"
  fi

  if [[ -d "$dir/.git" || -f "$dir/.git" ]]; then
    echo "Worktree exists: $dir"
    continue
  fi

  if [[ -e "$dir" && -n "$(ls -A "$dir" 2>/dev/null || true)" ]]; then
    echo "Skipping non-empty path: $dir"
    continue
  fi

  git worktree add "$dir" "$branch"
  echo "Created worktree: $dir -> $branch"
done

git worktree list
