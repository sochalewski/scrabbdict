#!/usr/bin/env bash
set -euo pipefail

asset_dir="Marketing/AppStore/Scrabbdict.butterkit/Assets"
readme_dir="Marketing/README"
dry_run=0
pngquant_args=(--quality=80-95 --speed 1 --skip-if-larger --force --ext .png)

usage() {
  printf 'Usage: %s [--dry-run]\n' "$0"
}

readme_screenshot_for_asset() {
  case "${1##*/}" in
    AE47019C-73E8-4C0B-A949-31C0CC8131EA.png)
      printf '%s/screenshot-1.png\n' "$readme_dir"
      ;;
    1BBF5C40-CB0D-4FC3-A298-382A64CC634D.png)
      printf '%s/screenshot-2.png\n' "$readme_dir"
      ;;
    4C10B9BF-BCD8-4C27-B92D-12A7CC7540A9.png)
      printf '%s/screenshot-3.png\n' "$readme_dir"
      ;;
    60639882-7F0A-4F0D-9345-D11AF2CE5EF4.png)
      printf '%s/screenshot-4.png\n' "$readme_dir"
      ;;
  esac
}

track_staging_state() {
  local path="$1"
  local has_staged=0
  local has_unstaged=0

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
}

image_dimensions() {
  local path="$1"
  "$sips_bin" -g pixelWidth -g pixelHeight "$path" | awk '
    /pixelWidth:/ { width = $2 }
    /pixelHeight:/ { height = $2 }
    END {
      if (width == "" || height == "") {
        exit 1
      }
      printf "%s %s\n", width, height
    }
  '
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
readme_source_pngs=()
readme_target_pngs=()
staged_pngs=()
partially_staged_pngs=()

while IFS= read -r -d '' path; do
  case "$path" in
    "$asset_dir"/*.png)
      if [[ -f "$path" ]]; then
        readme_path="$(readme_screenshot_for_asset "$path")"
        changed_pngs+=("$path")
        track_staging_state "$path"

        if [[ -n "$readme_path" ]]; then
          if [[ ! -f "$readme_path" ]]; then
            printf 'README screenshot not found for %s: %s\n' "$path" "$readme_path" >&2
            exit 1
          fi
          readme_source_pngs+=("$path")
          readme_target_pngs+=("$readme_path")
          track_staging_state "$readme_path"
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
  printf 'Refusing to modify partially staged PNG files:\n' >&2
  for path in "${partially_staged_pngs[@]}"; do
    printf '  %s\n' "$path" >&2
  done
  printf 'Commit, stage, or unstage these files first so the script can preserve staging state.\n' >&2
  exit 1
fi

if [[ "$dry_run" -eq 1 ]]; then
  if [[ ${#readme_source_pngs[@]} -gt 0 ]]; then
    printf 'README screenshot files that would be regenerated before quantization:\n'
    for index in "${!readme_source_pngs[@]}"; do
      printf '  %s <- %s\n' "${readme_target_pngs[$index]}" "${readme_source_pngs[$index]}"
    done
  fi
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

if [[ ${#readme_source_pngs[@]} -gt 0 ]]; then
  if ! sips_bin="$(command -v sips)"; then
    printf 'sips is not installed or not available on PATH.\n' >&2
    exit 127
  fi

  for index in "${!readme_source_pngs[@]}"; do
    source_path="${readme_source_pngs[$index]}"
    target_path="${readme_target_pngs[$index]}"
    dimensions="$(image_dimensions "$target_path")"
    read -r width height <<< "$dimensions"

    "$sips_bin" -z "$height" "$width" "$source_path" --out "$target_path" >/dev/null
    pngquant "${pngquant_args[@]}" "$target_path"
    printf 'Regenerated %s from %s\n' "$target_path" "$source_path"
  done
fi

for path in "${changed_pngs[@]}"; do
  pngquant "${pngquant_args[@]}" "$path"
  printf 'Quantized %s\n' "$path"
done

if [[ ${#staged_pngs[@]} -gt 0 ]]; then
  git add -- "${staged_pngs[@]}"
  printf 'Re-staged %d previously staged PNG file(s).\n' "${#staged_pngs[@]}"
fi
