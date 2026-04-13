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

    func selectMode(_ mode: StorageMode) {
        switch mode {
        case .local:
            let config = AppConfiguration.local()
            defaults.configuration = config
            withAnimation(.easeInOut(duration: 0.4)) {
                currentScreen = .main
            }
        case .shared, .selfHosted:
            withAnimation(.easeInOut(duration: 0.3)) {
                currentScreen = .auth(mode)
            }
        }
    }

    func completeAuth(mode: StorageMode, token: String? = nil) {
        let config: AppConfiguration
        switch mode {
        case .local:
            config = .local()
        case .shared:
            config = .shared(token: token)
        case .selfHosted:
            config = .selfHosted(token: token, serverURL: nil)
        }
        defaults.configuration = config
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
