# Project Instructions

## Workflow

- Before repository changes, read and follow the relevant sections of [CONTRIBUTING.md](CONTRIBUTING.md) for setup, SwiftUI/TCA code style, verification, and review requirements.
- Write code, code documentation, project Markdown, commit/MR titles and descriptions, and App Store release notes in English.
- Keep responses concise: decisions, changes, results, and relevant risks.

## SwiftUI

- Inside a `private extension`, omit member-level `private` unless a narrower access boundary is needed.
- Prefer inferred static members when context is clear; keep explicit types if inference fails or would require an artificial type annotation.
- Use `LocalizedStringResource`, `Text`, or existing helpers for localized copy; never introduce empty or placeholder-only `.xcstrings` keys.
- Use dynamic text styles; fixed font sizes require a justified non-text rendering need.

## Dictionaries and Scoring

- Before DAWG changes, read and preserve the [format, locale, and result-ordering contracts](README.md#how-the-dawg-dictionaries-work), including locale-header handling for both raw `.txt` and `.zip` sources.
- Prefer the fastest correct DAWG implementation that preserves the documented binary format, even over a more readable abstraction.
- Compare DAWG enumeration arrays directly; never use `.sorted()` in those assertions.
- Create or rewrite dictionary ZIP archives only with `7zz a -tzip -mx=9`.
- Preserve composed/decomposed Unicode equivalence at user-input boundaries before lookup and scoring; keep `Language.points(for:)` optimized for normalized inputs and DAWG-produced words.

## Required Verification

- DAWG format, generation, or runtime code changes: run `Scripts/dawg-performance main current`. Judge the paired `overall` estimate, 95% confidence interval, and run-level verdict from that invocation; absolute timings across runs, machines, or toolchains are diagnostic only.
- Changes to `Language.points(for:)`, letter point tables, or scoring normalization: run `Scripts/points-performance main current` and compare normalized-input results for regressions.
- Accept snapshot updates only after confirming the visual change is intentional.
