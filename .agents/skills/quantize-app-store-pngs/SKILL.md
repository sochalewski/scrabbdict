---
name: quantize-app-store-pngs
description: Quantize only currently changed PNG files in Marketing/AppStore/Scrabbdict.butterkit/Assets using pngquant. Use when Codex needs to optimize Scrabbdict App Store PNG assets while preserving unchanged committed assets and staged state.
---

# Quantize App Store PNGs

## Rules

- Use `scripts/quantize_changed_pngs.sh`; do not run a broad folder-wide `pngquant` command.
- Only operate on changed `*.png` files under `Marketing/AppStore/Scrabbdict.butterkit/Assets`.
- Treat "changed" as files reported by `git diff --name-only --diff-filter=ACMRT HEAD -- Marketing/AppStore/Scrabbdict.butterkit/Assets`.
- Never modify committed PNGs that are unchanged from `HEAD`.
- Ignore untracked unstaged files.
- Preserve staged state: PNGs that were staged before quantization must be re-staged after quantization; unstaged tracked PNGs must remain unstaged.
- Stop instead of modifying a partially staged PNG that has both staged and unstaged changes, because re-staging would collapse that split.

## Dependency

Use whichever `pngquant` executable is installed. Do not require or mention a specific version.

If `pngquant` is missing, the skill may try to install it with Homebrew:

```bash
brew install pngquant
```

Follow the normal approval rules before running Homebrew or any other command that requires elevated permissions or network access.

## Usage

From the repository root, inspect the affected files first:

```bash
bash .agents/skills/quantize-app-store-pngs/scripts/quantize_changed_pngs.sh --dry-run
```

Then quantize the changed PNGs:

```bash
bash .agents/skills/quantize-app-store-pngs/scripts/quantize_changed_pngs.sh
```

The script runs exactly this command for each selected PNG:

```bash
pngquant --quality=80-95 --speed 1 --skip-if-larger --force --ext .png <file.png>
```

After running, report the processed files and note whether any previously staged files were re-staged.
