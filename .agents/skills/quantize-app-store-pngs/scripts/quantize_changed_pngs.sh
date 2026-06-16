#!/usr/bin/env bash
set -euo pipefail

asset_dir="Marketing/AppStore/Scrabbdict.butterkit/Assets"
dry_run=0

usage() {
  printf 'Usage: %s [--dry-run]\n' "$0"
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $# -eq 1 ]]; then
  case "$1" in
    --dry-run)
      dry_run=1
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
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if [[ ! -d "$asset_dir" ]]; then
  printf 'Asset directory not found: %s\n' "$asset_dir" >&2
  exit 1
fi

if ! command -v pngquant >/dev/null 2>&1; then
  printf 'pngquant is not installed. Install it with: brew install pngquant\n' >&2
  exit 127
fi

changed_pngs=()
staged_pngs=()
partially_staged_pngs=()

while IFS= read -r -d '' path; do
  case "$path" in
    "$asset_dir"/*.png)
      if [[ -f "$path" ]]; then
        changed_pngs+=("$path")
        has_staged=0
        has_unstaged=0
        if ! git diff --cached --quiet -- "$path"; then
          has_staged=1
        fi
        if ! git diff --quiet -- "$path"; then
          has_unstaged=1
        fi
        if [[ "$has_staged" -eq 1 && "$has_unstaged" -eq 1 ]]; then
          partially_staged_pngs+=("$path")
        elif [[ "$has_staged" -eq 1 ]]; then
          staged_pngs+=("$path")
        fi
      fi
      ;;
  esac
done < <(git diff -z --name-only --diff-filter=ACMRT HEAD -- "$asset_dir")

if [[ ${#changed_pngs[@]} -eq 0 ]]; then
  printf 'No changed PNG files under %s.\n' "$asset_dir"
  exit 0
fi

if [[ ${#partially_staged_pngs[@]} -gt 0 ]]; then
  printf 'Refusing to quantize partially staged PNG files:\n' >&2
  for path in "${partially_staged_pngs[@]}"; do
    printf '  %s\n' "$path" >&2
  done
  printf 'Commit, stage, or unstage these files first so the script can preserve staging state.\n' >&2
  exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf 'Changed PNG files that would be quantized:\n'
  for path in "${changed_pngs[@]}"; do
    printf '  %s\n' "$path"
  done
  if [[ ${#staged_pngs[@]} -gt 0 ]]; then
    printf 'Previously staged PNG files that would be re-staged:\n'
    for path in "${staged_pngs[@]}"; do
      printf '  %s\n' "$path"
    done
  fi
  exit 0
fi

for path in "${changed_pngs[@]}"; do
  pngquant --quality=80-95 --speed 1 --skip-if-larger --force --ext .png "$path"
  printf 'Quantized %s\n' "$path"
done

if [[ ${#staged_pngs[@]} -gt 0 ]]; then
  git add -- "${staged_pngs[@]}"
  printf 'Re-staged %d previously staged PNG file(s).\n' "${#staged_pngs[@]}"
fi
