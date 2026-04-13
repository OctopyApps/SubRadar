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
                AuthView(mode: mode)
                    .environmentObject(appState)
                    .transition(.opacity)
            case .main:
                Text("Главный экран — скоро")
                    .environmentObject(appState)
                    .transition(.opacity)
            }
            Button("Сбросить (debug)") {
                appState.resetForDebug()
            }
            .font(.system(size: 12))
            .foregroundColor(Color(hex: "#3A3A60"))
            .padding(.top, 8)
        }
        
    }
}
