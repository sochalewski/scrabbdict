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
                .sheet(item: $store.scope(\.destination?.settings, action: \.destination.settings)) { settingsStore in
                    SettingsView(store: settingsStore)
                        .presentationDetents(horizontalSizeClass == .regular ? [.large] : [.medium, .large])
                }
        }
        .tint(.brandAccent)
    }
}

private extension ScrabbdictView {
    var contentMaxWidth: CGFloat {
        horizontalSizeClass == .regular ? 560 : .infinity
    }

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
                    .foregroundStyle(.primary)
                Text(verbatim: "dict")
                    .foregroundStyle(.brandAccent)
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

                VStack(spacing: 0) {
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
                    .dynamicTypeSize(...(horizontalSizeClass == .regular ? .accessibility3 : .accessibility2))
                    .padding(.horizontal, contentHorizontalPadding)
                    .frame(maxWidth: contentMaxWidth)
                    .zIndex(1)

                    resultArea
                        .animation(.easeOut(duration: 0.12), value: store.search)
                        .transition(.opacity)
                        .resultContentLayout(
                            maxWidth: contentMaxWidth,
                            horizontalPadding: contentHorizontalPadding
                        )
                        .zIndex(0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
            Image(.settings)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.brandAccent)
        }
        .accessibilityLabel(.settingsTitle)
    }

    @ViewBuilder
    var resultArea: some View {
        if let searchSkeletonVariant = store.search {
            searchSkeleton(for: searchSkeletonVariant)
                .scrollDisabled(true)
        } else if let result = store.result {
            scrollArea {
                ResultCardStackView(
                    result: result,
                    showsRackWordsButton: store.showsRackWordsButton,
                    rackWordsAction: { send(.rackWordsButtonTapped) }
                )
            }
        } else if let result = store.emptyResult {
            scrollArea {
                EmptySearchResultView(result: result)
            }
        } else if !store.words.isEmpty {
            listArea {
                WordsListView(words: store.words)
            }
        } else {
            Spacer(minLength: 0)
        }
    }

    var scrollMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: resultTopSpacing)

            Rectangle()
                .fill(.black)
        }
        .ignoresSafeArea(edges: .all)
    }

    @ViewBuilder
    func searchSkeleton(for variant: SearchSkeletonView.Variant) -> some View {
        switch variant {
        case .result:
            scrollArea {
                SearchSkeletonView(variant: variant)
            }
        case .words:
            listArea {
                SearchSkeletonView(variant: variant)
            }
        }
    }

    func listArea(@ViewBuilder content: () -> some View) -> some View {
        content()
            .contentMargins(.top, resultTopSpacing, for: .scrollContent)
            .maskedScrollArea(scrollMask)
    }

    func scrollArea(@ViewBuilder content: () -> some View) -> some View {
        ScrollView(.vertical) {
            content()
                .padding(.top, resultTopSpacing)
                .padding(.horizontal, contentHorizontalPadding)
                .frame(maxWidth: contentMaxWidth)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .maskedScrollArea(scrollMask)
    }
}

private extension View {
    func maskedScrollArea(_ mask: some View) -> some View {
        scrollClipDisabled()
            .mask(mask)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private let contentHorizontalPadding: CGFloat = 26
private let resultTopSpacing: CGFloat = 32

#Preview {
    ScrabbdictView(
        store: Store(
            initialState: ScrabbdictFeature.State(),
            reducer: ScrabbdictFeature.init
        )
    )
}
