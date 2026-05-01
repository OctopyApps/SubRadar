//
//  AuthService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 30.04.2026.
//

import Foundation

// MARK: - AuthService

final class AuthService {

    private let baseURL: String

    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private let session: URLSession

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Public

    /// Вход по email/паролю → возвращает JWT токен
    func login(email: String, password: String) async throws -> String {
        struct Body: Encodable { let email, password: String }
        return try await request(path: "/auth/login", body: Body(email: email, password: password))
    }

    /// Регистрация по email/паролю → возвращает JWT токен
    func register(email: String, password: String) async throws -> String {
        struct Body: Encodable { let email, password: String }
        return try await request(path: "/auth/register", body: Body(email: email, password: password))
    }

    /// Вход на self-hosted сервер по секретному ключу → возвращает JWT токен
    func selfHosted(secret: String) async throws -> String {
        struct Body: Encodable { let secret: String }
        return try await request(path: "/auth/self-hosted", body: Body(secret: secret))
    }

    // MARK: - Private

    // Вынесено за пределы generic функции — Swift не поддерживает вложенные типы в generic методах
    private struct TokenResponse: Decodable { let token: String }

    private func request<Body: Encodable>(path: String, body: Body) async throws -> String {
        guard let url = URL(string: baseURL + path) else {
            throw AuthError.badURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        req.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw AuthError.invalidResponse
        }

        // Пытаемся вытащить сообщение ошибки из тела {"error": "..."}
        let errorMessage = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]

        switch http.statusCode {
        case 200, 201:
            guard let decoded = try? decoder.decode(TokenResponse.self, from: data) else {
                throw AuthError.invalidResponse
            }
            return decoded.token
        case 401:
            throw AuthError.wrongCredentials
        case 409:
            throw AuthError.emailTaken
        case 403:
            throw AuthError.forbidden(message: errorMessage ?? "Доступ запрещён")
        default:
            throw AuthError.serverError(message: errorMessage ?? "Ошибка сервера \(http.statusCode)")
        }
    }
}

// MARK: - AuthError

enum AuthError: LocalizedError {
    case badURL
    case invalidResponse
    case wrongCredentials
    case emailTaken
    case forbidden(message: String)
    case serverError(message: String)

    var errorDescription: String? {
        switch self {
        case .badURL:                    return "Неверный адрес сервера"
        case .invalidResponse:           return "Неожиданный ответ сервера"
        case .wrongCredentials:          return "Неверный email или пароль"
        case .emailTaken:                return "Пользователь с таким email уже существует"
        case .forbidden(let msg):        return msg
        case .serverError(let msg):      return msg
        }
    }
}

// MARK: - URLError mapping

extension AuthError {
    static func from(_ error: Error) -> String {
        if let e = error as? AuthError { return e.localizedDescription }
        if let e = error as? URLError {
            switch e.code {
            case .notConnectedToInternet: return "Нет подключения к интернету"
            case .timedOut:               return "Сервер не отвечает"
            case .cannotConnectToHost:    return "Не удалось подключиться к серверу"
            default:                      return "Ошибка сети"
            }
        }
        return "Неизвестная ошибка"
    }
}
