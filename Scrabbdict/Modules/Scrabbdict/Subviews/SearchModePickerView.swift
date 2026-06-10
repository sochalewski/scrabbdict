//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct SearchModePickerView: View {
    let searchMode: SearchMode
    let maxHeight: CGFloat
    let onSearchModeSelected: (SearchMode) -> Void

    var body: some View {
        ScrollView(.vertical) {
            options
                .padding(6)
        }
        .frame(maxHeight: maxHeight)
        .fixedSize(horizontal: false, vertical: true)
        .scrollBounceBehavior(.basedOnSize)
        .background(.settingsBackground, in: .rect(cornerRadius: 12))
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: .appShadow.opacity(0.7), radius: 10, x: 0, y: 4)
    }

    private var options: some View {
        VStack(spacing: 6) {
            ForEach(SearchMode.allCases, id: \.self) { mode in
                searchModeOption(mode)
            }
        }
    }

    private func searchModeOption(_ mode: SearchMode) -> some View {
        Button {
            onSearchModeSelected(mode)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primaryInk)

                    SearchModeDescriptionText(mode: mode)
                }

                Spacer(minLength: 8)

                searchModeSelectionIcon(mode)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .background(
                searchMode == mode ? .brandAccent.opacity(0.08) : .clear,
                in: .rect(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode.title)
        .accessibilityHint(mode.accessibilityDescription)
        .accessibilityAddTraits(searchMode == mode ? [.isSelected] : [])
    }

    private func searchModeSelectionIcon(_ mode: SearchMode) -> some View {
        Image(systemName: searchMode == mode ? "checkmark.circle.fill" : "circle")
            .font(.headline.weight(.semibold))
            .foregroundStyle(searchMode == mode ? .brandAccent : .secondaryText.opacity(0.45))
            .accessibilityHidden(true)
    }
}

private struct SearchModeDescriptionText: View {
    let mode: SearchMode

    @Environment(\.locale) var locale

    private var localizedBundle: Bundle {
        Bundle.localizationBundle(for: locale)
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
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondaryText)
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
    @ScaledMetric(relativeTo: .caption2) var fontSize: CGFloat = 10
    @ScaledMetric(relativeTo: .caption2) var tileSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption2) var cornerRadius: CGFloat = 3

    var body: some View {
        Text(verbatim: "?")
            .font(.system(size: fontSize, weight: .bold))
            .foregroundStyle(Color.TableBackground.tileInk)
            .frame(width: tileSize, height: tileSize)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .TableBackground.tileTop,
                                .TableBackground.tileBottom
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.TableBackground.tileStroke, lineWidth: 0.8)
            }
            .shadow(color: .TableBackground.tileShadow, radius: 1, x: 0.4, y: 0.8)
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
