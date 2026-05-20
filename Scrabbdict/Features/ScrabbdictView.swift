//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import SwiftUI

@ViewAction(for: ScrabbdictFeature.self)
struct ScrabbdictView: View {
    @Bindable var store: StoreOf<ScrabbdictFeature>
    @FocusState var isSearchFocused: Bool
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    titleToolbar
                    settingsToolbar
                }
        }
        .tint(Color.brandAccent)
    }
}

private extension ScrabbdictView {
    @ToolbarContentBuilder
    var settingsToolbar: some ToolbarContent {
        if #available(iOS 26, *) {
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                settingsButton
            }
        }
    }

    var titleToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            HStack(spacing: 0) {
                Text("Scrabb")
                    .foregroundStyle(Color.primary)
                Text("dict")
                    .foregroundStyle(Color.brandAccent)
            }
            .font(.system(size: 24, weight: .bold))
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Scrabbdict")
        }
    }

    var content: some View {
        VStack(spacing: 32) {
            SearchBarView(
                text: $store.query,
                searchMode: $store.searchMode,
                isSearchModePickerExpanded: $store.isSearchModePickerExpanded,
                isFocused: $isSearchFocused,
                onClear: { send(.clearButtonTapped) },
                onSearchModePickerTapped: { send(.searchModePickerTapped) },
                onSearchModeSelected: { send(.searchModeSelected($0)) },
                onSearch: { send(.searchButtonTapped) }
            )
            .zIndex(1)

            resultArea
                .animation(.easeOut(duration: 0.12), value: store.search)
                .zIndex(0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: 420, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(background)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { send(.backgroundTapped) }
        .bind($store.isSearchFocused, to: $isSearchFocused)
        .onAppear { send(.loaded) }
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { settingsStore in
            SettingsView(store: settingsStore)
                .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
        }
    }

    var background: some View {
        ScrabbleTableBackground()
    }

    var settingsButton: some View {
        Button {
            send(.settingsButtonTapped)
        } label: {
            Image("Settings")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.brandAccent)
        }
        .accessibilityLabel("Settings")
    }

    @ViewBuilder
    var resultArea: some View {
        if let searchSkeletonVariant = store.search {
            SearchSkeletonView(variant: searchSkeletonVariant)
                .transition(.opacity)
        } else if let result = store.result {
            VStack(spacing: 24) {
                ResultCardView(result: result)

                if store.showsRackWordsButton {
                    rackWordsButton
                }
            }
            .transition(.opacity)
        } else if !store.words.isEmpty {
            WordsListView(words: store.words)
                .transition(.opacity)
        } else if let emptyResult = store.emptyResult {
            EmptySearchResultView(result: emptyResult)
                .transition(.opacity)
        } else {
            Spacer(minLength: 0)
        }
    }

    var rackWordsButton: some View {
        RackWordsButton {
            send(.rackWordsButtonTapped)
        }
    }
}

#Preview {
    ScrabbdictView(
        store: Store(
            initialState: ScrabbdictFeature.State(),
            reducer: ScrabbdictFeature.init
        )
    )
}
