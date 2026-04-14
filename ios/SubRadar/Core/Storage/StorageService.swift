//
//  StorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

/// Единый интерфейс для работы с подписками.
/// ViewModel знает только про этот протокол — не важно, SwiftData это, сервер или что-то ещё.
protocol StorageService: AnyObject {
    /// Загрузить все подписки
    func fetchSubscriptions() async throws -> [Subscription]

    /// Сохранить новую подписку
    func save(_ subscription: Subscription) async throws

    /// Обновить существующую подписку (ищет по id)
    func update(_ subscription: Subscription) async throws

    /// Удалить подписку
    func delete(_ subscription: Subscription) async throws
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case notFound
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Подписка не найдена"
        case .saveFailed(let e):
            return "Не удалось сохранить: \(e.localizedDescription)"
        case .fetchFailed(let e):
            return "Не удалось загрузить: \(e.localizedDescription)"
        }
    }
}
