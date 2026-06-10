Follow the existing SwiftUI and Composable Architecture patterns in this project before introducing new structure or abstractions.
For Composable Architecture code, prefer macro-based APIs over protocol conformances, for example `@Reducer` instead of `Reducer`.

Keep user-facing text localizable. Prefer the existing `LocalizedStringResource` and `Text` localization patterns over hardcoded display strings.

Use system-aware typography. Prefer dynamic SwiftUI text styles and existing font patterns over hardcoded point sizes; do not force fixed font sizes unless there is a narrowly justified non-text rendering need.

Treat snapshot changes as intentional UI changes. Do not update or accept snapshots just to make tests pass without confirming the visual change is expected.

In SwiftUI code, prefer inferred static member syntax when the surrounding API already provides a clear type context, for example `.resultCaption` instead of `Color.resultCaption` or `.headline` instead of `Font.headline`.
Keep explicit type names only when the shorthand does not compile, when the context is too generic, or when using shorthand would require adding an artificial type annotation.
