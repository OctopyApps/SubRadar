//
//  ServerSetupViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

@MainActor
final class ServerSetupViewModel: ObservableObject {
    @Published var host = ""
    @Published var port = "8080"
    @Published var secret = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    let mode: StorageMode

    init(mode: StorageMode) {
        self.mode = mode
    }

    func connect(appState: AppState) {
        errorMessage = nil

        guard !host.isEmpty else {
            errorMessage = "Введите адрес сервера"
            return
        }
        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            errorMessage = "Порт должен быть числом от 1 до 65535"
            return
        }
        guard !secret.isEmpty else {
            errorMessage = "Введите секретный ключ"
            return
        }

        isLoading = true

        Task {
            do {
                let token = try await checkConnection(
                    host: host,
                    port: portNumber,
                    secret: secret
                )
                isLoading = false
                let serverURL = "http://\(host):\(port)"
                appState.completeAuth(mode: mode, token: token, serverURL: serverURL)
            } catch {
                isLoading = false
                errorMessage = mapError(error)
            }
        }
    }

    // MARK: - Private

    private func checkConnection(host: String, port: Int, secret: String) async throws -> String? {
        guard let url = URL(string: "http://\(host):\(port)/auth") else {
            throw ServerSetupError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = ServerAuthBody(secret: secret)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ServerSetupError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            let decoded = try JSONDecoder().decode(ServerAuthResponse.self, from: data)
            return decoded.token
        case 401:
            throw ServerSetupError.wrongSecret
        case 500...:
            throw ServerSetupError.serverError
        default:
            throw ServerSetupError.invalidResponse
        }
    }

    private func mapError(_ error: Error) -> String {
        if let e = error as? ServerSetupError { return e.message }
        if let e = error as? URLError {
            switch e.code {
            case .notConnectedToInternet: return "Нет подключения к интернету"
            case .timedOut:               return "Сервер не отвечает — проверьте адрес и порт"
            case .cannotConnectToHost:    return "Не удалось подключиться к серверу"
            default:                      return "Ошибка сети"
            }
        }
        return "Неизвестная ошибка"
    }
}

// MARK: - Models

private struct ServerAuthBody: Encodable {
    let secret: String
}

private struct ServerAuthResponse: Decodable {
    let token: String
}

// MARK: - Errors

enum ServerSetupError: Error {
    case badURL
    case invalidResponse
    case wrongSecret
    case serverError

    var message: String {
        switch self {
        case .badURL:           return "Неверный адрес сервера"
        case .invalidResponse:  return "Неожиданный ответ сервера"
        case .wrongSecret:      return "Неверный секретный ключ"
        case .serverError:      return "Ошибка на стороне сервера"
        }
    }
}
