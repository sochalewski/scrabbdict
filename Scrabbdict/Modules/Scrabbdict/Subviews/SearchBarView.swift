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
    let searchModePickerAvailableHeight: CGFloat

    @ScaledMetric(relativeTo: .title2) var searchFieldHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .title2) var pickerTopPadding: CGFloat = 60
    @ScaledMetric(relativeTo: .title2) var clearButtonSize: CGFloat = 32
    @ScaledMetric(relativeTo: .title2) var actionButtonSize: CGFloat = 42

    var body: some View {
        searchField
            .overlay(alignment: .top) {
                if isSearchModePickerExpanded {
                    searchModePicker
                        .padding(.top, pickerTopPadding)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                        .accessibilityAddTraits(.isModal)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .animation(.easeInOut(duration: 0.18), value: isSearchModePickerExpanded)
    }
}

private extension SearchBarView {
    var searchModePickerMaxHeight: CGFloat {
        max(120, searchModePickerAvailableHeight - pickerTopPadding - 16)
    }

    var searchField: some View {
        HStack(spacing: (searchFieldHeight - actionButtonSize) / 2) {
            textField
            searchModeButton
            searchButton
        }
        .padding(.horizontal, (searchFieldHeight - actionButtonSize) / 2)
        .frame(height: searchFieldHeight)
        .background(.surface)
        .clipShape(Capsule(style: .circular))
        .overlay(
            Capsule(style: .circular)
                .stroke(.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: .appShadow, radius: 18, x: 0, y: 8)
    }

    var searchModePicker: some View {
        SearchModePickerView(
            searchMode: searchMode,
            maxHeight: searchModePickerMaxHeight,
            onSearchModeSelected: onSearchModeSelected
        )
        .frame(maxWidth: .infinity)
    }

    var textField: some View {
        HStack(spacing: 0) {
            searchTextField
            textFieldTrailingControl
        }
    }

    var searchTextField: some View {
        TextField(text: $text) {
            Text(verbatim: "")
        }
        .font(.title2.weight(.medium))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.primaryInk)
        .tint(.brandAccent)
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .submitLabel(.search)
        .focused($isFocused)
        .onSubmit(onSearch)
        .contentShape(.rect)
        .accessibilityLabel(.searchFieldAccessibilityLabel)
        .accessibilityValue(text.wordQueryAccessibilityValue)
        .onChange(of: text) { _, newValue in
            text = newValue.sanitizedWordQuery
        }
    }

    @ViewBuilder
    var textFieldTrailingControl: some View {
        if isFocused, !text.isEmpty {
            clearButton
        }
    }

    var clearButton: some View {
        Button(action: onClear) {
            Image(systemName: "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondaryText)
                .frame(width: clearButtonSize)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(.searchFieldClear)
    }

    var searchModeButton: some View {
        Button(action: onSearchModePickerTapped) {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.brandAccent)
                .frame(width: actionButtonSize, height: actionButtonSize)
                .background(.brandAccent.opacity(0.12), in: .circle)
                .rotationEffect(.degrees(isSearchModePickerExpanded ? 180 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(.searchModeAccessibilityLabel)
        .accessibilityValue(searchMode.title)
    }

    var searchButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: actionButtonSize, height: actionButtonSize)
                .background(.brandAccent, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
        .shadow(color: .appShadow, radius: 8, x: 0, y: 3)
        .accessibilityLabel(.searchButtonAccessibilityLabel)
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
                onSearch: {},
                searchModePickerAvailableHeight: 320
            )
            .padding()
            .onAppear { isFocused = true }
        }
    }

    return SearchBarPreview()
}
