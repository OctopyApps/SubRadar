//
//  SubRadarApp.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

//
//  SubRadarApp.swift
//  SubRadar
//

import SwiftUI

@main
struct SubRadarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(appState.colorSchemePreference.colorScheme)
        }
    }
}

// MARK: - ContentView

private struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            switch appState.currentScreen {
            case .onboarding:
                OnboardingView()
                    .transition(.opacity)
            case .auth(let mode):
                switch mode {
                case .shared:
                    AuthView(mode: mode)
                        .transition(.opacity)
                case .selfHosted:
                    ServerSetupView(mode: mode)
                        .transition(.opacity)
                case .local:
                    EmptyView()
                }
            case .main:
                SubscriptionsView()
                    .transition(.opacity)
            }

            #if DEBUG
            VStack {
                Spacer()
                Button("Сбросить (debug)") {
                    appState.resetForDebug()
                }
                .font(.system(size: 12))
                .foregroundColor(.srTextTertiary)
                .padding(.bottom, 8)
            }
            #endif
        }
    }
}
