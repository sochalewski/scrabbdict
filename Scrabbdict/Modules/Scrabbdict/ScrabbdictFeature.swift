//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import Foundation

@Reducer
struct ScrabbdictFeature {
    @ObservableState
    struct State: Hashable, Sendable {
        @Presents var destination: Destination.State?
        var alert: ScrabbdictAlert?
        var isSearchFocused = false
        var query = ""
        var result: ValidatorResult?
        var emptyResult: EmptySearchResult?
        var search: SearchSkeletonView.Variant?
        var showsRackWordsButton = false
        var searchMode = SearchMode.auto
        var isSearchModePickerExpanded = false
        var words = [Word]()
    }

    enum Action: Sendable, Equatable, ViewAction, BindableAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)

        enum ViewAction: Sendable, Equatable {
            case alertDismissed
            case backgroundTapped
            case clearButtonTapped
            case loaded
            case searchModePickerTapped
            case searchModeSelected(SearchMode)
            case rackWordsButtonTapped
            case searchButtonTapped
            case settingsButtonTapped
        }

        enum InternalAction: Sendable, Equatable {
            case searchResponse(SearchResponse)

            enum SearchResponse: Sendable, Equatable {
                case checked(ValidatorResult)
                case failed(ValidatorError)
                case matchedWords([Word], emptyResult: EmptySearchResult)
            }
        }
    }

    @Reducer
    enum Destination {
        case settings(SettingsFeature)
    }

    private enum CancelID {
        case search
    }

    @Dependency(\.crashlyticsClient) var crashlytics
    @Dependency(\.analyticsClient) var analytics
    @Dependency(\.appReviewClient) var appReview
    @Dependency(\.continuousClock) var clock
    @Dependency(\.searchModeStorage) var searchModeStorage
    @Dependency(\.validatorClient) var validator

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.query) { _, _ in
                Reduce { state, _ in
                    clearOutput(&state)
                    return cancelSearch()
                }
            }
            .onChange(of: \.isSearchFocused) { _, newValue in
                Reduce { state, _ in
                    guard newValue else { return .none }
                    state.isSearchModePickerExpanded = false
                    return .none
                }
            }

        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                return handle(viewAction: viewAction, &state)
            case let .internal(internalAction):
                return handle(internalAction: internalAction, &state)
            case .destination(.presented(.settings(.delegate(.languageUpdated)))):
                clearOutput(&state)
                return cancelSearch()
            default:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }

    private func clearOutput(_ state: inout State) {
        state.emptyResult = nil
        state.words = []
        state.result = nil
        state.search = nil
        state.showsRackWordsButton = false
    }

    private func cancelSearch() -> Effect<Action> {
        .cancel(id: CancelID.search)
    }
}

private extension ScrabbdictFeature {
    func handle(viewAction: Action.ViewAction, _ state: inout State) -> Effect<Action> {
        switch viewAction {
        case .alertDismissed:
            state.alert = nil
            return .none
        case .backgroundTapped:
            state.isSearchFocused = false
            state.isSearchModePickerExpanded = false
            return .none
        case .clearButtonTapped:
            state.query = ""
            clearOutput(&state)
            return cancelSearch()
        case .loaded:
            state.searchMode = searchModeStorage.current()
            return .none
        case .searchModePickerTapped:
            state.isSearchFocused = false
            state.isSearchModePickerExpanded.toggle()
            return .none
        case let .searchModeSelected(searchMode):
            let didChangeSearchMode = state.searchMode != searchMode
            state.searchMode = searchMode
            state.isSearchModePickerExpanded = false
            searchModeStorage.setCurrent(searchMode)
            guard didChangeSearchMode else { return .none }
            analytics.logModeChanged(searchMode)
            clearOutput(&state)
            return cancelSearch()
        case .rackWordsButtonTapped:
            return searchRackWords(&state)
        case .searchButtonTapped:
            switch state.searchMode {
            case .auto:
                return searchAutomatically(&state)
            case .check:
                return checkWord(&state, showsRackWordsButton: false)
            case .rack:
                return searchRackOrPattern(&state)
            }
        case .settingsButtonTapped:
            state.isSearchFocused = false
            state.isSearchModePickerExpanded = false
            state.destination = .settings(.init())
            return .none
        }
    }

    func searchRackWords(_ state: inout State) -> Effect<Action> {
        searchWords(&state, emptyResult: .rack, operation: validator.words)
    }

    func searchAutomatically(_ state: inout State) -> Effect<Action> {
        state.isSearchFocused = false
        state.isSearchModePickerExpanded = false
        let query = state.query
        guard !query.isEmpty else { return .none }

        if query.contains("?") {
            return searchPattern(&state)
        } else {
            return checkWord(&state, showsRackWordsButton: true)
        }
    }

    func searchRackOrPattern(_ state: inout State) -> Effect<Action> {
        let query = state.query
        guard !query.isEmpty else {
            state.isSearchFocused = false
            state.isSearchModePickerExpanded = false
            return .none
        }

        if query.contains("?") {
            return searchPattern(&state)
        } else {
            return searchRackWords(&state)
        }
    }

    func checkWord(_ state: inout State, showsRackWordsButton: Bool) -> Effect<Action> {
        guard
            let query = beginSearch(
                &state,
                skeleton: .result(showsRackWordsButton: showsRackWordsButton),
                showsRackWordsButton: showsRackWordsButton
            )
        else {
            return .none
        }

        return runSearch {
            try await .checked(validator.check(query))
        }
    }

    func searchPattern(_ state: inout State) -> Effect<Action> {
        searchWords(&state, emptyResult: .pattern, operation: validator.regex)
    }

    func searchWords(
        _ state: inout State,
        emptyResult: EmptySearchResult,
        operation: @escaping @Sendable (String) async throws(ValidatorError) -> [Word]
    ) -> Effect<Action> {
        guard let query = beginSearch(&state, skeleton: .words) else {
            return .none
        }

        return runSearch {
            try await .matchedWords(operation(query), emptyResult: emptyResult)
        }
    }

    func beginSearch(
        _ state: inout State,
        skeleton: SearchSkeletonView.Variant,
        showsRackWordsButton: Bool = false
    ) -> String? {
        state.isSearchFocused = false
        state.isSearchModePickerExpanded = false
        let query = state.query
        guard !query.isEmpty else { return nil }

        clearOutput(&state)
        state.search = skeleton
        state.showsRackWordsButton = showsRackWordsButton
        return query
    }

    func runSearch(
        _ operation: @escaping @Sendable () async throws -> Action.InternalAction.SearchResponse
    ) -> Effect<Action> {
        .run { send in
            do {
                try await send(.internal(.searchResponse(operation())))
            } catch {
                await send(.internal(.searchResponse(.failed(error as? ValidatorError ?? .dictionaryUnavailable))))
            }
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}

private extension ScrabbdictFeature {
    func handle(internalAction: Action.InternalAction, _ state: inout State) -> Effect<Action> {
        switch internalAction {
        case let .searchResponse(.checked(result)):
            state.result = result
            state.search = nil
            return .run { _ in
                try await clock.sleep(for: .seconds(2))
                await appReview.requestReviewIfAppropriate()
            }
        case let .searchResponse(.failed(error)):
            state.search = nil
            state.alert = .init(kind: .dictionaryUnavailable)
            crashlytics.record(error)
            return .none
        case let .searchResponse(.matchedWords(words, emptyResult)):
            state.words = words
            state.emptyResult = words.isEmpty ? emptyResult : nil
            state.search = nil
            return .none
        }
    }
}

extension ScrabbdictFeature.Destination.State: Hashable, Sendable {}
extension ScrabbdictFeature.Destination.Action: Sendable, Equatable {}
