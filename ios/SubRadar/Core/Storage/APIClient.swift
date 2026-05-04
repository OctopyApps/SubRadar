//
//  APIClient.swift
//  SubRadar
//
//  Created by Алексей Розанов on 28.04.2026.
//

import Foundation

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case noToken
    case networkError(underlying: Error)
    case serverError(statusCode: Int, message: String)
    case decodingError(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Неверный адрес сервера"
        case .noToken:
            return "Требуется авторизация"
        case .networkError(let e):
            return "Ошибка сети: \(e.localizedDescription)"
        case .serverError(let code, let msg):
            return "Ошибка сервера \(code): \(msg)"
        case .decodingError(let e):
            return "Ошибка разбора ответа: \(e.localizedDescription)"
        }
    }
}

// MARK: - APIClient

final class APIClient {

    private let baseURL: String
    private let tokenProvider: () -> String?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            // Сначала пробуем с дробными секундами (Go default: RFC3339Nano)
            let formatterNano = ISO8601DateFormatter()
            formatterNano.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatterNano.date(from: str) { return date }
            // Fallback: без дробных секунд
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Не удалось разобрать дату: \(str)"
            )
        }
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let session: URLSession

    init(baseURL: String, tokenProvider: @escaping () -> String?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.tokenProvider = tokenProvider
        self.session = session
    }

    // MARK: - Public: с телом ответа

    func get<Response: Decodable>(_ path: String) async throws -> Response {
        let request = try makeRequest(method: "GET", path: path, body: Optional<String>.none)
        return try await perform(request)
    }

    func post<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let request = try makeRequest(method: "POST", path: path, body: body)
        return try await perform(request)
    }

    func put<Body: Encodable, Response: Decodable>(_ path: String, body: Body) async throws -> Response {
        let request = try makeRequest(method: "PUT", path: path, body: body)
        return try await perform(request)
    }

    // MARK: - Public: без тела ответа (204 No Content)

    func delete(_ path: String) async throws {
        let request = try makeRequest(method: "DELETE", path: path, body: Optional<String>.none)
        try await performVoid(request)
    }

    // MARK: - Private

    private func makeRequest<Body: Encodable>(
        method: String,
        path: String,
        body: Body?
    ) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        guard let token = tokenProvider() else { throw APIError.noToken }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        if let body {
            request.httpBody = try encoder.encode(body)
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            print("🔴 DECODING ERROR: \(error)")
            print("🔴 RAW JSON: \(String(data: data, encoding: .utf8) ?? "nil")")
            throw APIError.decodingError(underlying: error)
        }
    }

    private func performVoid(_ request: URLRequest) async throws {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            // Пытаемся вытащить сообщение из тела {"error": "..."}
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw APIError.serverError(statusCode: http.statusCode, message: message)
        }
    }
}

// MARK: - StorageError mapping

extension APIError {
    func toStorageError() -> StorageError {
        switch self {
        case .networkError(let e): return .fetchFailed(underlying: e)
        case .decodingError(let e): return .fetchFailed(underlying: e)
        default: return .saveFailed(underlying: self)
        }
    }
}
