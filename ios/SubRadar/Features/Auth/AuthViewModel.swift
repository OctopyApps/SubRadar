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

    // MARK: - Intents

    func loginWithEmail(appState: AppState) {
        guard validate() else { return }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let service = makeAuthService(appState: appState)
                let token = try await service.login(email: email.lowercased().trimmingCharacters(in: .whitespaces),
                                                    password: password)
                isLoading = false
                appState.completeAuth(mode: mode, token: token)
            } catch {
                isLoading = false
                errorMessage = AuthError.from(error)
            }
        }
    }

    func loginWithGoogle(appState: AppState) {
        // TODO: подключить GoogleSignIn SDK
        errorMessage = "Google Sign-In ещё не реализован"
    }

    func loginWithApple(appState: AppState) {
        // TODO: подключить Sign in with Apple
        errorMessage = "Sign in with Apple ещё не реализован"
    }

    // MARK: - Private

    private func validate() -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Заполните все поля"
            return false
        }
        guard isValidEmail(email) else {
            errorMessage = "Введите корректный email"
            return false
        }
        return true
    }

    private func isValidEmail(_ email: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}")
        return predicate.evaluate(with: email)
    }

    private func makeAuthService(appState: AppState) -> AuthService {
        let config = UserDefaultsService.shared.configuration?.serverConfiguration ?? .shared()
        return AuthService(baseURL: config.baseURL)
    }
}
