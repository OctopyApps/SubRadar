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

    // Заполняется после успешного подключения — передаётся наружу для алерта миграции
    private(set) var pendingToken: String = ""
    private(set) var pendingServerConfig: ServerConfiguration = .shared()

    /// Вызывается после успешного подключения. Параметр — подписки из старого хранилища (может быть пустым).
    var onConnected: ((_ token: String, _ serverConfig: ServerConfiguration) -> Void)?

    init(mode: StorageMode) {
        self.mode = mode
    }

    // MARK: - Intents

    func connect(appState: AppState) {
        guard validate() else { return }
        errorMessage = nil
        isLoading = true

        let portNumber = Int(port)!
        let serverConfig = ServerConfiguration.selfHosted(
            host: host.trimmingCharacters(in: .whitespaces),
            port: portNumber
        )
        let service = AuthService(baseURL: serverConfig.baseURL, session: URLSessionFactory.selfHosted)

        Task {
            do {
                let token = try await service.selfHosted(secret: secret)
                isLoading = false
                // Передаём управление наружу — там решат про миграцию
                onConnected?(token, serverConfig)
            } catch {
                isLoading = false
                errorMessage = AuthError.from(error)
            }
        }
    }

    // MARK: - Private

    private func validate() -> Bool {
        guard !host.isEmpty else {
            errorMessage = "Введите адрес сервера"
            return false
        }
        guard isValidHost(host) else {
            errorMessage = "Некорректный адрес (пример: 192.168.1.1 или myserver.com)"
            return false
        }
        guard let portNumber = Int(port), (1...65535).contains(portNumber) else {
            errorMessage = "Порт должен быть числом от 1 до 65535"
            return false
        }
        guard !secret.isEmpty else {
            errorMessage = "Введите секретный ключ"
            return false
        }
        return true
    }

    private func isValidHost(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        return trimmed.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

// MARK: - ServerSetupError

enum ServerSetupError: LocalizedError {
    case badURL
    case invalidResponse
    case wrongSecret
    case serverError

    var errorDescription: String? {
        switch self {
        case .badURL:           return "Неверный адрес сервера"
        case .invalidResponse:  return "Неожиданный ответ сервера"
        case .wrongSecret:      return "Неверный секретный ключ"
        case .serverError:      return "Ошибка на стороне сервера"
        }
    }
}
