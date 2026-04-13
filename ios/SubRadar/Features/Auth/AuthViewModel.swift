//
//  AuthViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showRegister = false

    let mode: StorageMode

    init(mode: StorageMode) {
        self.mode = mode
    }

    func loginWithEmail(appState: AppState) {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Заполните все поля"
            return
        }
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isLoading = false
            appState.completeAuth(mode: self.mode)
        }
    }

    func loginWithGoogle(appState: AppState) {
        appState.completeAuth(mode: mode)
    }
}
