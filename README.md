# Scrabbdict

<p align="center">
  <img src="Marketing/AppStore/Scrabbdict.butterkit/Assets/AE47019C-73E8-4C0B-A949-31C0CC8131EA.png" alt="Screenshot #1" width="180" />
  <img src="Marketing/AppStore/Scrabbdict.butterkit/Assets/1BBF5C40-CB0D-4FC3-A298-382A64CC634D.png" alt="Screenshot #2" width="180" />
  <img src="Marketing/AppStore/Scrabbdict.butterkit/Assets/4C10B9BF-BCD8-4C27-B92D-12A7CC7540A9.png" alt="Screenshot #3" width="180" />
  <img src="Marketing/AppStore/Scrabbdict.butterkit/Assets/60639882-7F0A-4F0D-9345-D11AF2CE5EF4.png" alt="Screenshot #4" width="180" />
</p>

Scrabbdict is an iOS dictionary helper for word games. It can validate a word, find words that can be built from a set of tiles, and search dictionaries with a simple `?` wildcard pattern.

[![Download Scrabbdict on the App Store](Marketing/AppStore/app_store.svg)](https://apps.apple.com/pl/app/scrabbdict/id687530221)

The app is written in Swift and SwiftUI. State management uses [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), and analytics/crash reporting use Firebase.

## Legal Notice

© 2013-2026 Piotr Sochalewski

Scrabbdict is an independent, non-commercial hobby project. The developer does not derive profit from the application and has no affiliation, association, authorization, sponsorship, or endorsement from Hasbro, Mattel, NASPA Word List, Collins Coalition, Éditions Larousse, Polska Federacja Scrabble, Wydawnictwo Naukowe PWN or any other owner or publisher of the referenced word lists, trademarks, or related intellectual property.

All trademarks, service marks, trade names, word list names, and other protected designations referenced in or in connection with this application are the property of their respective owners. Their use is for identification and compatibility purposes only and does not imply any relationship with, or endorsement by, the respective owners.

## Licensing

The project source code is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).

The maintainer may continue to sign and publish the official App Store version independently. The app name, icon, App Store listing, bundle identifier, and backend configuration are not covered by the open source license.

## Dictionary Data

This repository does not include full dictionaries because of licensing restrictions. It includes only small sample dictionaries: each sample contains approximately `0.0001` of the most popular words for the given language.

To build or test Scrabbdict with complete dictionary behavior, provide your own word lists and regenerate the DAWG files. You can also use the checked-in samples for development, but they are intentionally incomplete. Local tests are allowed to fail when run without full dictionaries.

## Repository Layout

- `Scrabbdict/` - the iOS app target.
- `Scrabbdict/Modules/` - app modules with SwiftUI views, TCA reducers, and module-local subviews.
- `Scrabbdict/Modules/App/` - app entry point and application delegate.
- `Scrabbdict/Modules/Scrabbdict/` - main dictionary search module.
- `Scrabbdict/Modules/Settings/` - settings module.
- `Scrabbdict/Services/` - dictionary loading, validation, analytics, Crashlytics, and local storage clients.
- `Scrabbdict/Models/` - app domain models such as `Language`, `Word`, and `SearchMode`.
- `Scrabbdict/Resources/` - bundled app resources, including asset catalogs, localization, Settings metadata, and dictionaries.
- `Scrabbdict/Resources/Dictionaries/` - generated binary dictionary files used by the app, copied from `.dictionaries/DAWG` or `.samples/DAWG`.
- `DAWGBuilder/` - command-line generator that converts zipped `.txt` word lists into compact `.dawg` files.
- `DAWGBuilder/RAW/` - local ignored source word list archives copied from `.dictionaries/RAW` or `.samples/RAW`.
- `.samples/` - checked-in sample `.dawg` and source `.zip` dictionary files used when the private dictionary submodule is unavailable.
- `ScrabbdictTests/` - unit, feature, and snapshot tests grouped by area.
- `Marketing/AppStore/Scrabbdict.butterkit/` - App Store screenshot project and exported PNG assets.
- `Scripts/dawg` - helper script that builds and runs `DAWGBuilder`.
- `Scripts/swiftformat-lint.sh` - Xcode build phase script that checks Swift formatting.
- `Makefile` and `.mise.toml` - local development tooling setup.

## Requirements

- macOS with Xcode installed.
- iOS 17.0 or newer deployment target.
- Swift Package Manager support through Xcode.
- A Firebase iOS app configuration file named `GoogleService-Info.plist`.
- Local development tools managed by [mise](https://mise.jdx.dev/): SwiftFormat and `git-format-staged`.

Xcode resolves the Swift Package Manager dependencies from `Scrabbdict.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

## Local Tooling

The Xcode project includes a `SwiftFormat Lint` build phase. Run the project setup once before building locally:

```sh
make init
```

That installs or verifies `mise`, installs the tools pinned in `.mise.toml`, and installs a pre-commit hook that formats staged Swift files.

Useful commands:

```sh
make format
make format-lint
```

## App Store Screenshots

App Store screenshots are maintained with [ButterKit](https://butterkit.app). The editable ButterKit project and exported PNG assets live under:

```text
Marketing/AppStore/Scrabbdict.butterkit
```

The exported screenshots are part of the repository assets and should be regenerated from the ButterKit project when App Store presentation copy, device frames, or screenshot content changes.

## Firebase Configuration

The app imports Firebase Analytics and Crashlytics. To build your own copy, you must provide your own Firebase configuration:

1. Create or open a Firebase project.
2. Add an iOS app in Firebase using the bundle identifier you intend to build with. The checked-in project currently uses `pl.sochalewski.Scrabbdict`.
3. Download `GoogleService-Info.plist`.
4. Place it at:

   ```text
   Scrabbdict/GoogleService-Info.plist
   ```

For public forks, do not commit production Firebase credentials or service configuration unless you intentionally want that Firebase project to be used by other builds. A common approach is to keep a local `GoogleService-Info.plist` and commit a sanitized example file instead.

## Building the App

1. Clone the repository.
2. Run `make init`.
3. Add your own `Scrabbdict/GoogleService-Info.plist`.
4. Open `Scrabbdict.xcodeproj` in Xcode.
5. Let Xcode resolve packages.
6. Select the `Scrabbdict` scheme.
7. Select an iOS simulator or a signing-capable device.
8. Build and run from Xcode.

If you use a different Apple developer team or bundle identifier, update the target signing settings in Xcode before building for a device.

## Running Tests

Open the project in Xcode, select the `Scrabbdict` scheme, and run the test action. The active test plan includes unit tests, feature reducer tests, and snapshot tests. Performance tests are kept in the plan but skipped by default.

The test plan is stored at:

```text
ScrabbdictTests/Scrabbdict.xctestplan
```

Snapshot references are stored under:

```text
ScrabbdictTests/Snapshots/__Snapshots__/
```

The repository samples are not full dictionaries. Tests that depend on complete word-list coverage may fail locally until you provide full dictionaries and regenerate the corresponding `.dawg` files.

## How the DAWG Dictionaries Work

Scrabbdict does not search raw text files at runtime. Instead, each word list is compiled into a DAWG: a Directed Acyclic Word Graph. A DAWG is similar to a trie, but equivalent suffix subgraphs are merged, so common endings are stored once instead of repeated for many words.

The generator in `DAWGBuilder/` works broadly like this:

1. Read a UTF-8 `.txt` word list from a `.zip` archive, one word per line.
2. Sort the words.
3. Insert each word into an incremental graph builder.
4. Minimize completed branches by reusing previously seen equivalent nodes.
5. Write a compact little-endian binary file with:
   - a header containing magic/version/counts,
   - a small alphabet table,
   - a node table,
   - an edge table.

The app loads generated `.dawg` files with memory-mapped `Data` when possible. Validation walks graph edges for an exact word. Tile search performs a depth-first traversal while consuming available letters. Pattern search treats `?` as a single-character wildcard.

At a high level, the DAWG v3 binary layout is:

- header: magic, version, word count, node count, edge count, and alphabet count,
- alphabet table: the distinct `UInt16` Unicode scalar values used by edge labels,
- node table: each node stores `firstEdge` as `UInt32` and a packed `UInt16` edge count, with the high bit reserved as the word-terminating flag,
- edge table: each edge stores a `UInt8` alphabet index and a 24-bit little-endian target node index.

The binary format is defined in `DAWGBuilder/DAWGBuilder.swift` and read by `Scrabbdict/Services/DAWG.swift`.

## Regenerating Dictionaries

Use the helper script from the repository root:

```sh
Scripts/dawg
```

That compiles `DAWGBuilder` with `xcrun swiftc` and writes generated dictionaries to:

```text
Scrabbdict/Resources/Dictionaries/
```

Generate only selected languages:

```sh
Scripts/dawg pl_OSPS
Scripts/dawg en_US_nwl fr_ODS
```

Use custom input or output directories:

```sh
Scripts/dawg --input-dir /path/to/word-lists --output-dir /tmp/dawg
```

Input files are matched by language/file stem. By default, `Scripts/dawg` reads from `DAWGBuilder/RAW`. For example, `pl_OSPS` expects:

```text
DAWGBuilder/RAW/pl_OSPS.zip
```

and produces:

```text
Scrabbdict/Resources/Dictionaries/pl_OSPS.dawg
```

## Supported Dictionaries

The app currently references these language identifiers:

- `en_GB_csw` - English CSW-style (formerly SOWPODS) word list.
- `en_US_nwl` - English NASPA-style (formerly OTCWL) word list.
- `fr_ODS` - French ODS-style word list.
- `pl_OSPS` - Polish OSPS-style word list.

Names, descriptions, and language-specific behavior are defined in `Scrabbdict/Models/Language.swift`.

## Localization

User-visible translations are maintained in:

```text
Scrabbdict/Resources/Localizable.xcstrings
```

Keep locale-specific wording in the string catalog, but keep dictionary metadata that must stay identical across translations in code. In particular, dictionary word counts are defined as numeric values in `Scrabbdict/Models/Language.swift` and are injected into localized strings after locale-aware number formatting. Do not duplicate formatted word counts manually in each translation.

When updating dictionary names or descriptions, update all supported locales together (`en`, `fr`, and `pl`) and keep protected dictionary names, abbreviations, trademarks, and source names unchanged unless the underlying dictionary source changes. The string catalog comments mark terms that should not be translated.

## Third-Party Notices

User-visible third-party notices are maintained in:

```text
Scrabbdict/Resources/Settings.bundle/Root.plist
```

When Swift Package Manager dependencies used by the app at runtime change, update that file to match `Package.resolved`. Test-only dependencies, such as snapshot testing tools, do not need to appear in the user-visible Settings bundle unless they become part of the shipped app.

## Contributing Notes

- Keep generated `.dawg` files in sync with their source `.zip` word list archives when changing dictionary data.
- Cover UI changes with accessibility metadata, including labels, values, hints, traits, and reading order where they affect VoiceOver or other assistive technologies.
- Check UI changes with VoiceOver and Dynamic Type when they affect navigation, controls, results, settings, or other user-facing flows.
- Keep legal notices and third-party notices current when changing dependencies, assets, or app branding.
- Prefix commit messages with `[AI]` when the commit mainly contains AI-generated code, for example `[AI] Optimize DAWG performance`.
- Do not commit personal signing credentials, provisioning profiles, private API keys, or production service configuration for forks.
