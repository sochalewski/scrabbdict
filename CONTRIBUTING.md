# Contributing to Scrabbdict

Thank you for taking the time to improve Scrabbdict. This guide explains how to make contributions that are easy to review and safe to ship.

Scrabbdict is an independent, non-commercial iOS dictionary helper for word games. The source code is open source, but the official App Store listing, app name, icon, bundle identifier, signing setup, backend configuration, and full dictionary data are not part of the public contribution surface.

## Before You Start

- Read the project overview, requirements, dictionary notes, and build instructions in [README.md](README.md).
- Run `make init` once after cloning to install the local development tools and pre-commit hook.
- Open `Scrabbdict.xcodeproj` in Xcode and use the `Scrabbdict` scheme for local development.
- Provide your own `Scrabbdict/GoogleService-Info.plist` if you want to build or run the app.
- Do not commit personal signing credentials, provisioning profiles, private API keys, or production service configuration for forks.

The `.dictionaries` directory is a private submodule used by the maintainer. Public contributors should expect it to be unavailable. Use the checked-in `.samples` data or your own local word list archives when working on dictionary behavior.

## Issues

When opening an issue, include:

- The affected app version, iOS version, device or simulator, and language/dictionary if relevant.
- Clear steps to reproduce the problem.
- The expected behavior and the actual behavior.
- Screenshots or recordings for UI issues.
- Crash logs or console output when they are available and safe to share.

Avoid attaching proprietary word lists, private Firebase files, signing assets, or credentials.

## Pull Requests

Keep pull requests focused. A small PR that changes one behavior, fixes one bug, or adds one clearly scoped feature is easier to review than a broad mixed change.

Before opening a pull request:

- Rebase or merge the latest `main` as appropriate for your workflow.
- Run `make format` or rely on the installed pre-commit hook for Swift formatting.
- Run `make format-lint-strict`.
- Run the relevant tests from Xcode using the `Scrabbdict` scheme and `Scrabbdict` test plan.
- Include screenshots or recordings for visible UI changes.
- Describe the change, the reason for it, and the verification you performed.

Prefix commit messages with `[AI]` when the commit mainly contains AI-generated code, for example `[AI] Optimize DAWG performance`.

## Code Style

- Follow the existing SwiftUI and Composable Architecture patterns before introducing new structure.
- Prefer macro-based TCA APIs, such as `@Reducer`, and the unlabeled `scope(_:action:)` / `Scope(_:action:)` forms used by the project.
- Keep main SwiftUI view declarations focused on stored properties and `body`.
- Move helper computed properties and helper methods into a `private extension` directly below the view declaration and above previews.
- Prefer inferred static member syntax when the surrounding API provides clear type context.
- Keep user-facing text localizable with the existing localization patterns.
- Prefer system-aware typography and Dynamic Type-friendly text styles over fixed point sizes.

## UI, Accessibility, and Localization

For user-facing UI changes:

- Cover controls and dynamic content with appropriate accessibility labels, values, hints, traits, and reading order.
- Check affected flows with VoiceOver and Dynamic Type.
- Update `Scrabbdict/Resources/Localizable.xcstrings` for localized user-facing copy.
- When updating dictionary names or descriptions, update all supported locales together: `en`, `fr`, and `pl`.
- Keep protected dictionary names, abbreviations, trademarks, and source names unchanged unless the underlying dictionary source changes.

Snapshot references under `ScrabbdictTests/Snapshots/__Snapshots__/` are tracked with Git LFS. Update snapshots only when the visual change is intentional, and include the snapshot changes in the same pull request as the code that caused them.

## DAWG and Dictionary Changes

DAWG code is performance-critical. Changes to the DAWG binary format, generator, runtime reader, validation, tile search, or pattern search need extra care.

When changing DAWG-related code:

- Keep generated `.dawg` files in sync with their source `.zip` word list archives when changing dictionary data.
- Preserve the documented binary format unless the change intentionally migrates it.
- Add or update correctness tests for format, generation, loading, validation, tile search, or wildcard behavior as appropriate.
- Run `Scripts/dawg-performance main current` and compare the result before submitting the pull request.

Do not submit full proprietary dictionaries to the public repository.

## Dependencies and Notices

When Swift Package Manager dependencies used by the app at runtime change, update the user-visible third-party notices in:

```text
Scrabbdict/Resources/Settings.bundle/Root.plist
```

Test-only dependencies do not need to appear in the Settings bundle unless they become part of the shipped app.

Keep legal notices current when changing dependencies, assets, dictionary references, app branding, or public-facing copy.

## Review Checklist

Use this checklist before requesting review:

- The PR has a clear scope and description.
- Formatting passes with `make format-lint-strict`.
- Relevant tests were run, or the PR explains why they were not run.
- UI changes include screenshots or recordings.
- Accessibility and Dynamic Type were checked for affected flows.
- Localization updates include all supported locales when needed.
- Snapshot changes are intentional and included with the related code.
- DAWG performance was measured for DAWG runtime, generator, or binary format changes.
- No credentials, private service configuration, signing assets, or proprietary word lists are included.
