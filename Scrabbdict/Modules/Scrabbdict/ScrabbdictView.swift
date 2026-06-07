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

    private var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 560 : .infinity
    }

    var body: some View {
        NavigationStack {
            content
                .onAppear { send(.loaded) }
                .navigationTitle(.init(verbatim: ""))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    titleToolbar
                    settingsToolbar
                }
                .bind($store.isSearchFocused, to: $isSearchFocused)
                .alert(item: $store.alert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text(.alertOk))
                    )
                }
                .sheet(item: $store.scope(state: \.destination?.settings, action: \.destination.settings)) { settingsStore in
                    SettingsView(store: settingsStore)
                        .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
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
                Text(verbatim: "Scrabb")
                    .foregroundStyle(Color.primary)
                Text(verbatim: "dict")
                    .foregroundStyle(Color.brandAccent)
            }
            .font(.title2.weight(.bold))
            .lineLimit(1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(.init(verbatim: "Scrabbdict"))
        }
    }

    var content: some View {
        GeometryReader { proxy in
            ZStack {
                ScrabbleTableBackground()

                VStack(spacing: 32) {
                    SearchBarView(
                        text: $store.query,
                        searchMode: $store.searchMode,
                        isSearchModePickerExpanded: $store.isSearchModePickerExpanded,
                        isFocused: $isSearchFocused,
                        onClear: { send(.clearButtonTapped) },
                        onSearchModePickerTapped: { send(.searchModePickerTapped) },
                        onSearchModeSelected: { send(.searchModeSelected($0)) },
                        onSearch: { send(.searchButtonTapped) },
                        searchModePickerAvailableHeight: proxy.size.height
                    )
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                    .zIndex(1)

                    resultArea
                        .animation(.easeOut(duration: 0.12), value: store.search)
                        .zIndex(0)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: contentMaxWidth, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onTapGesture { send(.backgroundTapped) }
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
        .accessibilityLabel(.settingsTitle)
    }

    @ViewBuilder
    var resultArea: some View {
        if let searchSkeletonVariant = store.search {
            SearchSkeletonView(variant: searchSkeletonVariant)
                .transition(.opacity)
        } else if let result = store.result {
            resultCardArea(result: result)
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

    func resultCardArea(result: ValidatorResult) -> some View {
        ScrollView(.vertical) {
            VStack(spacing: 24) {
                ResultCardView(result: result)

                if store.showsRackWordsButton {
                    rackWordsButton
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
