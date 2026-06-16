#!/usr/bin/env bash
set -euo pipefail

base_ref=""

usage() {
  printf 'Usage: %s [--base <ref>]\n' "$0"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      if [[ $# -lt 2 || -z "$2" ]]; then
        usage >&2
        exit 2
      fi
      base_ref="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

current_branch="$(git symbolic-ref --quiet --short HEAD || true)"
if [[ -z "$current_branch" ]]; then
  printf 'Detached HEAD detected. Ask the user which base ref to use, then rerun with --base <ref>.\n' >&2
  exit 2
fi

head_sha="$(git rev-parse HEAD)"

ref_exists() {
  git rev-parse --verify --quiet "$1^{commit}" >/dev/null
}

is_default_base() {
  [[ "$1" == "main" || "$1" == "origin/main" ]]
}

infer_base_ref() {
  local best_ref=""
  local best_time=-1
  local ref ref_sha merge_base merge_base_time
  local candidates=()

  if ref_exists "main"; then
    candidates+=("main")
  fi
  if ref_exists "origin/main"; then
    candidates+=("origin/main")
  fi

  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    [[ "$ref" == "$current_branch" ]] && continue
    [[ "$ref" == "origin/$current_branch" ]] && continue
    [[ "$ref" == */HEAD ]] && continue
    [[ "$ref" == "main" || "$ref" == "origin/main" ]] && continue
    candidates+=("$ref")
  done < <(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes)

  for ref in "${candidates[@]}"; do
    ref_sha="$(git rev-parse "$ref^{commit}" 2>/dev/null || true)"
    [[ -z "$ref_sha" ]] && continue
    [[ "$ref_sha" == "$head_sha" ]] && continue

    merge_base="$(git merge-base HEAD "$ref" 2>/dev/null || true)"
    [[ -z "$merge_base" ]] && continue
    [[ "$merge_base" == "$head_sha" ]] && continue

    merge_base_time="$(git show -s --format=%ct "$merge_base")"
    if [[ "$merge_base_time" -gt "$best_time" ]]; then
      best_time="$merge_base_time"
      best_ref="$ref"
    fi
  done

  printf '%s\n' "$best_ref"
}

if [[ -z "$base_ref" ]]; then
  if [[ "$current_branch" == "main" ]]; then
    printf 'Current branch is main. Ask the user whether to continue and which base ref to use, then rerun with --base <ref>.\n' >&2
    exit 2
  fi

  base_ref="$(infer_base_ref)"
  if [[ -z "$base_ref" ]]; then
    printf 'Could not infer a parent branch. Ask the user which base ref to use, then rerun with --base <ref>.\n' >&2
    exit 2
  fi

  if ! is_default_base "$base_ref"; then
    printf 'Likely parent branch is %s, not main/origin/main. Ask the user whether to continue and which base ref to use, then rerun with --base <ref>.\n' "$base_ref" >&2
    exit 2
  fi
fi

if ! ref_exists "$base_ref"; then
  printf 'Base ref not found: %s\n' "$base_ref" >&2
  exit 2
fi

merge_base="$(git merge-base HEAD "$base_ref")"
commit_count="$(git rev-list --count "$merge_base..HEAD")"

printf 'Current branch: %s\n' "$current_branch"
printf 'Base ref: %s\n' "$base_ref"
printf 'Merge base: %s\n' "$merge_base"
printf 'Commit count: %s\n' "$commit_count"
printf '\n'

printf 'Commits:\n'
if [[ "$commit_count" -eq 0 ]]; then
  printf '  No commits ahead of %s.\n' "$base_ref"
else
  git log --reverse --format='  %h %s' "$merge_base..HEAD"
fi
printf '\n'

if [[ "$commit_count" -eq 1 ]]; then
  printf 'Suggested title from single commit:\n'
  git log -1 --format='%s' HEAD
  printf '\n'
fi

printf 'Changed files:\n'
if git diff --quiet "$merge_base"...HEAD; then
  printf '  No file changes relative to merge base.\n'
else
  git diff --name-status "$merge_base"...HEAD
fi
printf '\n'

printf 'Diff stats:\n'
git diff --stat "$merge_base"...HEAD
printf '\n'

printf 'Compact diff:\n'
git diff --find-renames --find-copies --compact-summary "$merge_base"...HEAD
