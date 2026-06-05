//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct SearchModePickerView: View {
    let searchMode: SearchMode
    let onSearchModeSelected: (SearchMode) -> Void

    var body: some View {
        VStack(spacing: 6) {
            ForEach(SearchMode.allCases, id: \.self) { mode in
                searchModeOption(mode)
            }
        }
        .padding(6)
        .background(Color.settingsBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.appShadow.opacity(0.7), radius: 10, x: 0, y: 4)
    }

    private func searchModeOption(_ mode: SearchMode) -> some View {
        Button {
            onSearchModeSelected(mode)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primaryInk)

                    SearchModeDescriptionText(mode: mode)
                }

                Spacer(minLength: 8)

                searchModeSelectionIcon(mode)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                searchMode == mode ? Color.brandAccent.opacity(0.08) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityHint(mode.description)
    }

    private func searchModeSelectionIcon(_ mode: SearchMode) -> some View {
        Image(systemName: searchMode == mode ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(searchMode == mode ? Color.brandAccent : Color.secondaryText.opacity(0.45))
            .accessibilityHidden(true)
    }
}

private struct SearchModeDescriptionText: View {
    @Environment(\.locale) private var locale

    let mode: SearchMode

    private var localizedBundle: Bundle {
        guard
            let languageCode = locale.language.languageCode?.identifier,
            let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }

        return bundle
    }

    private var descriptionLocalizationValue: String.LocalizationValue {
        switch mode {
        case .auto: "search_mode.auto.description"
        case .check: "search_mode.check.description"
        case .rack: "search_mode.rack.description"
        }
    }

    var body: some View {
        let text = String(localized: descriptionLocalizationValue, bundle: localizedBundle)
        let tokens = Token.tokens(from: text)

        SearchModeDescriptionFlowLayout {
            ForEach(tokens) { token in
                switch token.kind {
                case let .text(value):
                    Text(verbatim: value)
                case let .space(value):
                    Text(verbatim: value)
                        .layoutValue(key: CollapsibleSpaceLayoutValueKey.self, value: true)
                case .wildcard:
                    WildcardTile()
                        .padding(.horizontal, 1)
                }
            }
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.secondaryText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: text))
    }
}

private struct SearchModeDescriptionFlowLayout: Layout {
    private struct Line {
        let items: [Item]
        let width: CGFloat
        let height: CGFloat
    }

    private struct Item {
        let subview: LayoutSubview
        let size: CGSize
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) -> CGSize {
        let lines = lines(for: subviews, maxWidth: proposal.width ?? .infinity)
        return CGSize(
            width: proposal.width ?? lines.map(\.width).max() ?? 0,
            height: lines.reduce(0) { $0 + $1.height }
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let lines = lines(for: subviews, maxWidth: bounds.width)
        var y = bounds.minY

        for line in lines {
            var x = bounds.minX

            for item in line.items {
                item.subview.place(
                    at: CGPoint(x: x, y: y + (line.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width
            }

            y += line.height
        }
    }

    private func lines(for subviews: Subviews, maxWidth: CGFloat) -> [Line] {
        var lines: [Line] = []
        var currentItems: [Item] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        func finishLine() {
            guard !currentItems.isEmpty else { return }
            lines.append(Line(items: currentItems, width: currentWidth, height: currentHeight))
            currentItems.removeAll()
            currentWidth = 0
            currentHeight = 0
        }

        for subview in subviews {
            let isSpace = subview[CollapsibleSpaceLayoutValueKey.self]
            let size = subview.sizeThatFits(.unspecified)

            if isSpace, currentItems.isEmpty {
                continue
            }

            if !currentItems.isEmpty, currentWidth + size.width > maxWidth {
                finishLine()

                if isSpace {
                    continue
                }
            }

            currentItems.append(Item(subview: subview, size: size))
            currentWidth += size.width
            currentHeight = max(currentHeight, size.height)
        }

        finishLine()
        return lines
    }
}

private struct CollapsibleSpaceLayoutValueKey: LayoutValueKey {
    static let defaultValue = false
}

private struct WildcardTile: View {
    var body: some View {
        Text(verbatim: "?")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.TableBackground.tileInk)
            .frame(width: 16, height: 16)
            .background {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.TableBackground.tileTop,
                                Color.TableBackground.tileBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.TableBackground.tileStroke, lineWidth: 0.8)
            }
            .shadow(color: Color.TableBackground.tileShadow, radius: 1, x: 0.4, y: 0.8)
            .accessibilityHidden(true)
    }
}

private struct Token: Identifiable {
    enum Kind {
        case text(String)
        case space(String)
        case wildcard
    }

    let id: Int
    let kind: Kind

    static func tokens(from text: String) -> [Self] {
        var tokens: [Self] = []
        var buffer = ""

        func flushText() {
            guard !buffer.isEmpty else { return }
            let tokenKind: Kind = buffer.allSatisfy(\.isWhitespace) ? .space(buffer) : .text(buffer)
            tokens.append(Self(id: tokens.count, kind: tokenKind))
            buffer.removeAll()
        }

        for character in text {
            if character == "?" {
                flushText()
                tokens.append(Self(id: tokens.count, kind: .wildcard))
            } else if character.isWhitespace {
                buffer.append(character)
                flushText()
            } else {
                buffer.append(character)
            }
        }

        flushText()
        return tokens
    }
}
