//
//  AppState.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import SwiftUI

enum AppScreen {
    case onboarding
    case auth(StorageMode)
    case main
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen

    private let defaults = UserDefaultsService.shared

    init() {
        if let config = defaults.configuration, config.isAuthenticated {
            currentScreen = .main
        } else {
            currentScreen = .onboarding
        }
    }

    // MARK: - Storage Mode

    /// Текущий режим хранения из сохранённой конфигурации.
    /// Возвращает .local если конфигурация ещё не задана (онбординг).
    var storageMode: StorageMode {
        defaults.configuration?.storageMode ?? .local
    }

    // MARK: - Intents

    func selectMode(_ mode: StorageMode) {
        switch mode {
        case .local:
            defaults.configuration = .local()
            withAnimation(.easeInOut(duration: 0.4)) {
                currentScreen = .main
            }
        case .shared, .selfHosted:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentScreen = .auth(mode)
            }
        }
    }

    func completeAuth(mode: StorageMode, token: String? = nil, serverURL: String? = nil) {
        switch mode {
        case .local:
            defaults.configuration = .local()
        case .shared:
            defaults.configuration = .shared(token: token)
        case .selfHosted:
            defaults.configuration = .selfHosted(token: token, serverURL: serverURL)
        }
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = .main
        }
    }

    func logout() {
        defaults.configuration = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = .onboarding
        }
    }

    func resetForDebug() {
        defaults.configuration = nil
        withAnimation(.easeInOut(duration: 0.4)) {
            currentScreen = .onboarding
        }
    }
}
