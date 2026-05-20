# Scrabbdict

Scrabbdict is an iOS dictionary helper for word games. It can validate a word, find words that can be built from a set of tiles, and search dictionaries with a simple `?` wildcard pattern.

[![Download Scrabbdict on the App Store](images/app_store.svg)](https://apps.apple.com/pl/app/scrabbdict/id687530221)

The app is written in Swift and SwiftUI. State management uses [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture), and analytics/crash reporting use Firebase.

## Legal Notice

© 2013-2026 Piotr Sochalewski

Scrabbdict is an independent, non-commercial hobby project. The developer does not derive profit from the application and has no affiliation, association, authorization, sponsorship, or endorsement from Hasbro, Mattel, NASPA Word List, Collins Coalition, Éditions Larousse, or any other owner or publisher of the referenced word lists, trademarks, or related intellectual property.

All trademarks, service marks, trade names, word list names, and other protected designations referenced in or in connection with this application are the property of their respective owners. Their use is for identification and compatibility purposes only and does not imply any relationship with, or endorsement by, the respective owners.

## Licensing

The project source code is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).

The maintainer may continue to sign and publish the official App Store version independently. The app name, icon, App Store listing, bundle identifier, and backend configuration are not covered by the open source license.

## Dictionary Data

This repository does not include full dictionaries because of licensing restrictions. It includes only small sample dictionaries: each sample contains approximately `0.0001` of the most popular words for the given language.

To build or test Scrabbdict with complete dictionary behavior, provide your own word lists and regenerate the DAWG files. You can also use the checked-in samples for development, but they are intentionally incomplete. Local tests are allowed to fail when run without full dictionaries.

## Repository Layout

- `Scrabbdict/` - the iOS app target.
- `Scrabbdict/Features/` - SwiftUI views and TCA reducers.
- `Scrabbdict/Helpers/` - dictionary loading, validation, analytics, Crashlytics, and local storage clients.
- `Scrabbdict/Models/` - app domain models such as `Language`, `Word`, and `SearchMode`.
- `Scrabbdict/Files/DAWG/` - generated binary dictionary files used by the app.
- `Scrabbdict/Settings.bundle/` - iOS Settings app metadata, legal notice, and third-party notices.
- `DAWGWizard/` - command-line generator that converts `.txt` word lists into compact `.dawg` files.
- `DAWGWizard/Files/` - source word lists.
- `ScrabbdictTests/` - unit and feature tests.
- `Scripts/dawg` - helper script that builds and runs `DAWGWizard`.

## Requirements

- macOS with Xcode installed.
- iOS 17.0 or newer deployment target.
- Swift Package Manager support through Xcode.
- A Firebase iOS app configuration file named `GoogleService-Info.plist`.

Xcode resolves the Swift Package Manager dependencies from `Scrabbdict.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`.

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
2. Add your own `Scrabbdict/GoogleService-Info.plist`.
3. Open `Scrabbdict.xcodeproj` in Xcode.
4. Let Xcode resolve packages.
5. Select the `Scrabbdict` scheme.
6. Select an iOS simulator or a signing-capable device.
7. Build and run from Xcode.

If you use a different Apple developer team or bundle identifier, update the target signing settings in Xcode before building for a device.

## Running Tests

Open the project in Xcode, select the `Scrabbdict` scheme, and run the test action. The test plan is stored at:

```text
ScrabbdictTests/Scrabbdict.xctestplan
```

The repository samples are not full dictionaries. Tests that depend on complete word-list coverage may fail locally until you provide full dictionaries and regenerate the corresponding `.dawg` files.

## How the DAWG Dictionaries Work

Scrabbdict does not search raw text files at runtime. Instead, each word list is compiled into a DAWG: a Directed Acyclic Word Graph. A DAWG is similar to a trie, but equivalent suffix subgraphs are merged, so common endings are stored once instead of repeated for many words.

The generator in `DAWGWizard/` works broadly like this:

1. Read a UTF-8 `.txt` word list, one word per line.
2. Sort the words.
3. Insert each word into an incremental graph builder.
4. Minimize completed branches by reusing previously seen equivalent nodes.
5. Write a compact little-endian binary file with:
   - a header containing magic/version/counts,
   - a node table,
   - an edge table.

The app loads these generated `.dawg` files with memory-mapped `Data` when possible. Validation walks graph edges for an exact word. Tile search performs a depth-first traversal while consuming available letters. Pattern search treats `?` as a single-character wildcard.

The binary format is defined in `DAWGWizard/DAWGBuilder.swift` and read by `Scrabbdict/Helpers/DAWG.swift`.

## Regenerating Dictionaries

Use the helper script from the repository root:

```sh
Scripts/dawg
```

That compiles `DAWGWizard` with `xcrun swiftc` and writes generated dictionaries to:

```text
Scrabbdict/Files/DAWG/
```

Generate only selected languages:

```sh
Scripts/dawg pl_PL
Scripts/dawg en_US_twl fr_ODS
```

Use custom input or output directories:

```sh
Scripts/dawg --input-dir /path/to/word-lists --output-dir /tmp/dawg
```

Input files are matched by language/file stem. For example, `pl_PL` expects:

```text
DAWGWizard/Files/pl_PL.txt
```

and produces:

```text
Scrabbdict/Files/DAWG/pl_PL.dawg
```

## Supported Dictionaries

The app currently references these language identifiers:

- `en_GB_sowpods` - English SOWPODS / Collins-style word list.
- `en_US_twl` - English TWL / NASPA-style word list.
- `fr_ODS` - French ODS-style word list.
- `pl_PL` - Polish word list from [sjp.pl](https://sjp.pl/sl/growy/), licensed under GPL 2 and CC BY 4.0.

Names, descriptions, and language-specific behavior are defined in `Scrabbdict/Models/Language.swift`.

## Third-Party Notices

User-visible third-party notices are maintained in:

```text
Scrabbdict/Settings.bundle/Root.plist
```

When Swift Package Manager dependencies change, update that file to match `Package.resolved`.

## Contributing Notes

- Keep generated `.dawg` files in sync with their source `.txt` word lists when changing dictionary data.
- Keep legal notices and third-party notices current when changing dependencies, assets, or app branding.
- Prefix commit messages with `[AI]` when the commit mainly contains AI-generated code, for example `[AI] Optimize DAWG performance`.
- Do not commit personal signing credentials, provisioning profiles, private API keys, or production service configuration for forks.
