//
//  SubRadarApp.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import SwiftUI

@main
struct SubRadarApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            switch appState.currentScreen {
            case .onboarding:
                OnboardingView()
                    .environmentObject(appState)
                    .transition(.opacity)
            case .auth(let mode):
                switch mode {
                case .shared:
                    AuthView(mode: mode)
                        .environmentObject(appState)
                        .transition(.opacity)
                case .selfHosted:
                    ServerSetupView(mode: mode)
                        .environmentObject(appState)
                        .transition(.opacity)
                case .local:
                    EmptyView()
                }
            case .main:
                SubscriptionsView()
                    .environmentObject(appState)
                    .transition(.opacity)
            }
      
            #if DEBUG
            Button("Сбросить (debug)") {
                appState.resetForDebug()
            }
            .font(.system(size: 12))
            .foregroundColor(.srTextTertiary)
            .padding(.top, 8)
            #endif
        }
        
    }
}
