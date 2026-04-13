//
//  OnboardingViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var selectedMode: StorageMode?
    @Published var isAnimatingSelection = false

    func select(_ mode: StorageMode, appState: AppState) {
        guard !isAnimatingSelection else { return }
        selectedMode = mode
        isAnimatingSelection = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            appState.selectMode(mode)
        }
    }
}
