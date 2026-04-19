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
        guard isValidEmail(email) else {
            errorMessage = "Введите корректный email"
            return
        }
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let token = try await authRequest(email: email, password: password)
                isLoading = false
                appState.completeAuth(mode: mode, token: token)
            } catch {
                isLoading = false
                errorMessage = mapError(error)
            }
        }
    }

    func loginWithGoogle(appState: AppState) {
        // TODO: подключить GoogleSignIn SDK
        appState.completeAuth(mode: mode, token: nil)
    }

    // MARK: - Private

    private func isValidEmail(_ email: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@",
            "[A-Z0-9a-z._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}")
        return predicate.evaluate(with: email)
    }

    private func authRequest(email: String, password: String) async throws -> String? {
        let serverConfig = UserDefaultsService.shared.configuration?.serverConfiguration ?? .shared()
        guard let url = serverConfig.authURL else {
            throw AuthError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = AuthRequestBody(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(AuthResponseBody.self, from: data)
            return decoded.token
        case 401:
            throw AuthError.wrongCredentials
        case 500...:
            throw AuthError.serverError
        default:
            throw AuthError.invalidResponse
        }
    }

    private func mapError(_ error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.message
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "Нет подключения к интернету"
            case .timedOut:
                return "Сервер не отвечает"
            default:
                return "Ошибка сети"
            }
        }
        return "Неизвестная ошибка"
    }
}

// MARK: - Models

private struct AuthRequestBody: Encodable {
    let email: String
    let password: String
}

private struct AuthResponseBody: Decodable {
    let token: String
}

// MARK: - Errors

enum AuthError: Error {
    case badURL
    case invalidResponse
    case wrongCredentials
    case serverError

    var message: String {
        switch self {
        case .badURL:           return "Неверный адрес сервера"
        case .invalidResponse:  return "Неожиданный ответ сервера"
        case .wrongCredentials: return "Неверный email или пароль"
        case .serverError:      return "Ошибка на стороне сервера"
        }
    }
}
