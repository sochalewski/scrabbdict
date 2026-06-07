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

    private var searchModePickerMaxHeight: CGFloat {
        max(120, searchModePickerAvailableHeight - pickerTopPadding - 16)
    }

    var body: some View {
        searchField
            .overlay(alignment: .top) {
                if isSearchModePickerExpanded {
                    searchModePicker
                        .padding(.top, pickerTopPadding)
                        .transition(.opacity.combined(with: .offset(y: -8)))
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.12), value: isFocused)
            .animation(.easeInOut(duration: 0.18), value: isSearchModePickerExpanded)
    }

    private var searchField: some View {
        HStack(spacing: (searchFieldHeight - actionButtonSize) / 2) {
            textField
            searchModeButton
            searchButton
        }
        .padding(.horizontal, (searchFieldHeight - actionButtonSize) / 2)
        .frame(height: searchFieldHeight)
        .background(Color.surface)
        .clipShape(Capsule(style: .circular))
        .overlay(
            Capsule(style: .circular)
                .stroke(Color.surfaceStroke, lineWidth: 1)
        )
        .shadow(color: Color.appShadow, radius: 18, x: 0, y: 8)
    }

    private var searchModePicker: some View {
        SearchModePickerView(
            searchMode: searchMode,
            maxHeight: searchModePickerMaxHeight,
            onSearchModeSelected: onSearchModeSelected
        )
        .frame(maxWidth: .infinity)
    }

    private var textField: some View {
        HStack(spacing: 0) {
            searchTextField
            textFieldTrailingControl
        }
    }

    private var searchTextField: some View {
        TextField(text: $text) {
            Text(verbatim: "")
        }
        .font(.title2.weight(.medium))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(Color.primaryInk)
        .tint(Color.brandAccent)
        .multilineTextAlignment(.center)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .submitLabel(.search)
        .focused($isFocused)
        .onSubmit(onSearch)
        .contentShape(.rect)
        .accessibilityLabel(.searchFieldAccessibilityLabel)
        .onTapGesture {
            isFocused = true
        }
        .onChange(of: text) { _, newValue in
            text = newValue.sanitizedWordQuery
        }
    }

    @ViewBuilder
    private var textFieldTrailingControl: some View {
        if isFocused, !text.isEmpty {
            clearButton
        }
    }

    private var clearButton: some View {
        Button(action: onClear) {
            Image(systemName: "xmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondaryText)
                .frame(width: clearButtonSize)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(.searchFieldClear)
    }

    private var searchModeButton: some View {
        Button(action: onSearchModePickerTapped) {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.brandAccent)
                .frame(width: actionButtonSize, height: actionButtonSize)
                .background(Color.brandAccent.opacity(0.12), in: .circle)
                .rotationEffect(.degrees(isSearchModePickerExpanded ? 180 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(.searchModeAccessibilityLabel)
        .accessibilityValue(searchMode.title)
    }

    private var searchButton: some View {
        Button(action: onSearch) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: actionButtonSize, height: actionButtonSize)
                .background(Color.brandAccent, in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
        .shadow(color: Color.appShadow, radius: 8, x: 0, y: 3)
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
