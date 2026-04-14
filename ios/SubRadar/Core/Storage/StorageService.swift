//
//  StorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

/// Единый интерфейс для работы с подписками и тегами.
/// ViewModel знает только про этот протокол — не важно, SwiftData это, сервер или что-то ещё.
protocol StorageService: AnyObject {

    // MARK: Subscriptions

    func fetchSubscriptions() async throws -> [Subscription]
    func save(_ subscription: Subscription) async throws
    func update(_ subscription: Subscription) async throws
    func delete(_ subscription: Subscription) async throws

    // MARK: Tags

    func fetchTags() async throws -> [Tag]
    /// Сохраняет тег если его ещё нет (идемпотентно по имени)
    func saveTagIfNeeded(name: String) async throws -> Tag
    func deleteTag(_ tag: Tag) async throws
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case notFound
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Запись не найдена"
        case .saveFailed(let e):
            return "Не удалось сохранить: \(e.localizedDescription)"
        case .fetchFailed(let e):
            return "Не удалось загрузить: \(e.localizedDescription)"
        }
    }
}
