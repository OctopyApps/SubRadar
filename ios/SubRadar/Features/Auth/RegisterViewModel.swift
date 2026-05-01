//
//  RegisterViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var passwordConfirm = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    let mode: StorageMode

    init(mode: StorageMode) {
        self.mode = mode
    }

    // MARK: - Intents

    func register(appState: AppState) {
        guard validate() else { return }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let service = makeAuthService(appState: appState)
                let token = try await service.register(
                    email: email.lowercased().trimmingCharacters(in: .whitespaces),
                    password: password
                )
                isLoading = false
                // После регистрации сразу авторизуем — токен уже есть
                appState.completeAuth(mode: mode, token: token)
            } catch {
                isLoading = false
                errorMessage = AuthError.from(error)
            }
        }
    }

    // MARK: - Private

    private func validate() -> Bool {
        guard !email.isEmpty, !password.isEmpty, !passwordConfirm.isEmpty else {
            errorMessage = "Заполните все поля"
            return false
        }
        guard NSPredicate(format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}")
            .evaluate(with: email) else {
            errorMessage = "Введите корректный email"
            return false
        }
        guard password == passwordConfirm else {
            errorMessage = "Пароли не совпадают"
            return false
        }
        guard password.count >= 8 else {
            errorMessage = "Пароль должен быть не менее 8 символов"
            return false
        }
        return true
    }

    private func makeAuthService(appState: AppState) -> AuthService {
        let config = UserDefaultsService.shared.configuration?.serverConfiguration ?? .shared()
        return AuthService(
            baseURL: config.baseURL,
            session: URLSessionFactory.session(for: mode)
        )
    }
}
