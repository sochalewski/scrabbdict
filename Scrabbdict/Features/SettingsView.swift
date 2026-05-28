//
//  Scrabbdict
//  Copyright © 2026 Piotr Sochalewski.
//  Licensed under the Apache License, Version 2.0.
//

import ComposableArchitecture
import SwiftUI

@ViewAction(for: SettingsFeature.self)
struct SettingsView: View {
    let store: StoreOf<SettingsFeature>

    var body: some View {
        NavigationStack {
            ScrollView(.vertical) {
                content
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.settingsBackground.ignoresSafeArea())
            .navigationTitle(.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .cancel) { send(.cancelButtonTapped) }
                            .foregroundStyle(Color.settingsAccent)
                    } else {
                        Button(.settingsCancel) { send(.cancelButtonTapped) }
                            .foregroundStyle(Color.settingsAccent)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26, *) {
                        Button(role: .confirm) { send(.saveButtonTapped) }
                            .foregroundStyle(Color.settingsAccent)
                    } else {
                        Button(.settingsSave) { send(.saveButtonTapped) }
                            .foregroundStyle(Color.settingsAccent)
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                send(.loaded)
            }
        }
        .tint(Color.settingsAccent)
    }
}

private extension SettingsView {
    var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.settingsDictionary)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.settingsText)

            VStack(spacing: 0) {
                ForEach(Language.allCases, id: \.self) { language in
                    Button {
                        send(.languageSelected(language))
                    } label: {
                        let isSelected = store.selectedLanguage == language

                        HStack {
                            Text(language.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.settingsText)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.settingsAccent)
                            }
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .background {
                            Color.settingsRowBackground

                            if isSelected {
                                Color.settingsAccent.opacity(0.18)
                            }
                        }
                        .overlay(alignment: .bottom) {
                            if language != Language.allCases.last {
                                Rectangle()
                                    .fill(Color.divider)
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.surfaceStroke, lineWidth: 1)
            )

            ZStack(alignment: .topLeading) {
                ForEach(Language.allCases, id: \.self) { language in
                    (
                        Text(language.description)
                            + Text(verbatim: "\n\n")
                            + Text(.languageWordCount)
                            + Text(verbatim: " ")
                            + Text(language.wordCount, format: .number)
                    )
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.settingsText.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(store.selectedLanguage == language ? 1 : 0)
                    .accessibilityHidden(store.selectedLanguage != language)
                }
            }
            .padding(.top, 16)
        }
    }
}

#Preview {
    SettingsView(
        store: Store(
            initialState: SettingsFeature.State(),
            reducer: SettingsFeature.init
        )
    )
}
