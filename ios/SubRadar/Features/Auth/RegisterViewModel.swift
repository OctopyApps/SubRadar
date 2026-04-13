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

    func register(appState: AppState) {
        errorMessage = nil

        guard !email.isEmpty, !password.isEmpty, !passwordConfirm.isEmpty else {
            errorMessage = "Заполните все поля"
            return
        }
        guard password == passwordConfirm else {
            errorMessage = "Пароли не совпадают"
            return
        }
        guard password.count >= 8 else {
            errorMessage = "Пароль должен быть не менее 8 символов"
            return
        }

        isLoading = true

        Task {
            do {
                try await registerRequest(email: email, password: password)
                await MainActor.run {
                    isLoading = false
                    // Сохраняем конфигурацию и идём на главный экран
                    appState.completeAuth(mode: mode)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func registerRequest(email: String, password: String) async throws {
        // Заглушка на эндпоинт /register
        // Потом заменим на реальный URL сервера из конфигурации
        guard let url = URL(string: "https://api.subradar.io/register") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        // Симулируем задержку сети пока нет реального сервера
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Когда будет реальный сервер — раскомментируй:
        // let (_, response) = try await URLSession.shared.data(for: request)
        // guard let http = response as? HTTPURLResponse, http.statusCode == 201 else {
        //     throw URLError(.badServerResponse)
        // }
    }
}
