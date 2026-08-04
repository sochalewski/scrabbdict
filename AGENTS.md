# Project Instructions

## Communication and Language

- Keep responses free of boilerplate: include only the decision, changes, results, and any relevant risks.
- Always generate code and code documentation, project Markdown file changes, commit title suggestions, merge request title suggestions, merge request descriptions, and App Store change descriptions in English.

## Architecture

- Follow the existing SwiftUI and Composable Architecture patterns in this project before introducing new structure or abstractions.

## DAWG

- When changing code directly related to the DAWG binary format, DAWG generation, or DAWG runtime implementation, run `Scripts/dawg-performance main current`. Base performance decisions on the paired `overall` estimate, its 95% confidence interval, and the run-level verdict from that single comparison; treat absolute timings from separate runs, machines, or toolchains as diagnostic only.
- Treat DAWG code as performance-critical. Prefer the fastest implementation that preserves correctness and the documented binary format, even when it is less immediately readable than a more general or idiomatic version.
- Treat lexicographically ascending results from `DAWG.words(from:minLength:)` and `DAWG.words(matching:)` as part of the runtime contract. `DAWGBuilder` must write the alphabet table by strictly ascending scalar value and every node's edge block by strictly ascending alphabet index; callers may rely on Swift's stable sort to preserve this scalar-lexicographic order between equal-scoring words. This order is not localized collation, so Polish user-facing score ties must use Polish alphabetical order after scoring.
- Tests covering DAWG enumeration must compare returned arrays directly. Do not call `.sorted()` in those assertions, because doing so hides ordering regressions.

## Scoring

- When changing `Language.points(for:)`, letter point tables, or word scoring normalization, run `Scripts/points-performance main current` and compare the normalized scoring input benchmark results to make sure the change does not regress performance.
- Keep word scoring code efficient. User-input normalization must preserve composed and decomposed Unicode equivalence before DAWG lookup and scoring, while `Language.points(for:)` should remain optimized for normalized scoring inputs and DAWG-produced words.

## Composable Architecture

- Prefer macro-based APIs over protocol conformances, for example `@Reducer` instead of `Reducer`.
- Prefer `scope(_:action:)` and `Scope(_:action:)` over the labeled `scope(state:action:)` and `Scope(state:action:)` forms.

## SwiftUI

- Keep the main view declaration focused on stored properties and `body`.
- Move helper computed properties and helper methods that would otherwise be `private` into a `private extension` placed directly below the view declaration and above any previews. Because the extension itself is private, do not repeat `private` on those members unless a narrower access boundary is specifically needed.
- Prefer inferred static member syntax when the surrounding API already provides a clear type context, for example `.resultCaption` instead of `Color.resultCaption` or `.headline` instead of `Font.headline`. Keep explicit type names only when the shorthand does not compile, when the context is too generic, or when using shorthand would require adding an artificial type annotation.

## Localization

- Keep user-facing text localizable. Prefer the existing `LocalizedStringResource` and `Text` localization patterns over hardcoded display strings.
- Do not introduce SwiftUI localization patterns that extract placeholder-only or otherwise empty keys into `.xcstrings` files. Compose localized copy through explicit `LocalizedStringResource` entries or existing localization helpers so generated catalogs contain meaningful keys and translations, not accidental format strings.

## Typography

- Use system-aware typography. Prefer dynamic SwiftUI text styles and existing font patterns over hardcoded point sizes; do not force fixed font sizes unless there is a narrowly justified non-text rendering need.

## Testing

- Treat snapshot changes as intentional UI changes. Do not update or accept snapshots just to make tests pass without confirming the visual change is expected.

## Contributor Guidance

- When making repository changes, follow the contributor-facing process and verification guidance in [CONTRIBUTING.md](CONTRIBUTING.md).
