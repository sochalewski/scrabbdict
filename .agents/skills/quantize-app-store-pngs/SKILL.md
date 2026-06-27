---
name: quantize-app-store-pngs
description: Quantize currently changed PNG files in Marketing/AppStore/Scrabbdict.butterkit/Assets and regenerate matching Marketing/README screenshots. Use when Codex needs to optimize Scrabbdict App Store PNG assets while preserving unchanged committed assets and staged state.
---

# Quantize App Store PNGs

## Rules

- Use `scripts/quantize_changed_pngs.sh`; do not run a broad folder-wide `pngquant` command.
- Only select source `*.png` files that are changed under `Marketing/AppStore/Scrabbdict.butterkit/Assets`.
- Treat "changed" as files reported by `git diff --name-only --diff-filter=ACMRT HEAD -- Marketing/AppStore/Scrabbdict.butterkit/Assets`.
- Never quantize committed ButterKit PNGs that are unchanged from `HEAD`.
- Before quantizing changed ButterKit PNGs, regenerate only the matching README screenshot PNGs whose stable ButterKit parent asset is changed.
- Do not parse `Marketing/AppStore/Scrabbdict.butterkit/Document.json` during normal execution; screenshot names are stable and encoded in the script.
- Ignore untracked unstaged files.
- Preserve staged state: PNGs that were staged before quantization must be re-staged after quantization; unstaged tracked PNGs must remain unstaged.
- Stop instead of modifying a partially staged PNG that has both staged and unstaged changes, because re-staging would collapse that split.

## README Screenshot Mapping

The script uses this fixed ButterKit-to-README mapping:

- `Marketing/AppStore/Scrabbdict.butterkit/Assets/AE47019C-73E8-4C0B-A949-31C0CC8131EA.png` -> `Marketing/README/screenshot-1.png`
- `Marketing/AppStore/Scrabbdict.butterkit/Assets/1BBF5C40-CB0D-4FC3-A298-382A64CC634D.png` -> `Marketing/README/screenshot-2.png`
- `Marketing/AppStore/Scrabbdict.butterkit/Assets/4C10B9BF-BCD8-4C27-B92D-12A7CC7540A9.png` -> `Marketing/README/screenshot-3.png`
- `Marketing/AppStore/Scrabbdict.butterkit/Assets/60639882-7F0A-4F0D-9345-D11AF2CE5EF4.png` -> `Marketing/README/screenshot-4.png`

For each changed mapped parent asset, the script resizes the still-unquantized ButterKit source to the existing README screenshot resolution, writes it to the mapped README path, and quantizes it with the same `pngquant` settings used for ButterKit assets. README screenshots whose mapped parent asset is unchanged must not be touched.

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

For mapped README screenshots, the script first resizes the parent ButterKit asset to the destination README screenshot dimensions and then runs the same `pngquant` command on the README image before quantizing the original ButterKit asset.

After running, report the regenerated README screenshots, processed ButterKit files, and whether any previously staged files were re-staged.
