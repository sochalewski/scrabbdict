//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import SwiftUI

struct SearchBarView: View {
    @Binding var text: String
    @Binding var searchMode: SearchMode
    @Binding var isSearchModePickerExpanded: Bool
    @FocusState.Binding var isFocused: Bool

    let onClear: () -> Void
    let onSearchModePickerTapped: () -> Void
    let onSearchModeSelected: (SearchMode) -> Void
    let onSearch: () -> Void

    var body: some View {
        searchField
            .overlay(alignment: .top) {
                if isSearchModePickerExpanded {
                    searchModePicker
                        .padding(.top, 52)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                }
            }
            .frame(maxWidth: 320)
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .animation(.easeInOut(duration: 0.18), value: isSearchModePickerExpanded)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            textField

            searchModeButton

            searchButton
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(height: 44)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.appShadow, radius: 18, x: 0, y: 8)
    }

    private var searchModePicker: some View {
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

    private var textField: some View {
        TextField(text: $text) {
            Text(verbatim: "")
        }
        .font(.system(size: 21, weight: .medium))
        .foregroundStyle(Color.primaryInk)
        .tint(Color.brandAccent)
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .submitLabel(.search)
        .focused($isFocused)
        .onSubmit(onSearch)
        .padding(.trailing, text.isEmpty || !isFocused ? 0 : 30)
        .frame(height: 38)
        .accessibilityLabel(.searchFieldAccessibilityLabel)
        .onChange(of: text) { _, newValue in
            text = newValue.sanitizedWordQuery
        }
        .overlay(alignment: .trailing) {
            textFieldTrailingControl
        }
    }

    @ViewBuilder
    private var textFieldTrailingControl: some View {
        if !text.isEmpty {
            if isFocused {
                clearButton
            } else {
                focusTapTarget
            }
        }
    }

    private var clearButton: some View {
        Button(action: onClear) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.secondaryText)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(.searchFieldClear)
    }

    private var focusTapTarget: some View {
        Color.clear
            .frame(width: 30, height: 38)
            .contentShape(Rectangle())
            .onTapGesture {
                isFocused = true
            }
            .accessibilityHidden(true)
    }

    private var searchModeButton: some View {
        Button(action: onSearchModePickerTapped) {
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.brandAccent)
                .frame(width: 34, height: 34)
                .background(Color.brandAccent.opacity(0.12), in: Circle())
                .rotationEffect(.degrees(isSearchModePickerExpanded ? 180 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(.searchModeAccessibilityLabel)
        .accessibilityValue(searchMode.title)
    }

    private var searchButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 18, height: 18)
                .foregroundStyle(Color.white.opacity(text.isEmpty ? 0.65 : 1))
                .frame(width: 34, height: 34)
                .background(Color.brandAccent.opacity(text.isEmpty ? 0.35 : 1), in: Circle())
                .shadow(color: Color.appShadow.opacity(text.isEmpty ? 0 : 1), radius: 8, x: 0, y: 3)
        }
        .disabled(text.isEmpty)
        .accessibilityLabel(.searchButtonAccessibilityLabel)
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

                    Text(mode.description)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
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

#Preview {
    struct SearchBarPreview: View {
        @State var text = "query"
        @State var searchMode = SearchMode.auto
        @State var isSearchModePickerExpanded = false
        @FocusState var isFocused: Bool

        var body: some View {
            SearchBarView(
                text: $text,
                searchMode: $searchMode,
                isSearchModePickerExpanded: $isSearchModePickerExpanded,
                isFocused: $isFocused,
                onClear: { text = "" },
                onSearchModePickerTapped: { isSearchModePickerExpanded.toggle() },
                onSearchModeSelected: { searchMode = $0 },
                onSearch: {}
            )
            .padding()
            .onAppear { isFocused = true }
        }
    }

    return SearchBarPreview()
}
