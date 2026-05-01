//
//  StorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

/// Единый интерфейс для работы с данными.
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

    // MARK: Categories
    // Только пользовательские категории — дефолты захардкожены на клиенте.

    func fetchCategories() async throws -> [AppCategory]
    func saveCategory(_ category: AppCategory) async throws -> AppCategory
    func deleteCategory(_ category: AppCategory) async throws

    // MARK: Currencies
    // Только пользовательские валюты — дефолты захардкожены на клиенте.

    func fetchCurrencies() async throws -> [AppCurrency]
    func saveCurrency(_ currency: AppCurrency) async throws -> AppCurrency
    func deleteCurrency(_ currency: AppCurrency) async throws

    // MARK: Migration

    /// Удаляет все данные пользователя из хранилища.
    /// Вызывается при смене режима когда пользователь выбирает "Начать чисто".
    func clearAll() async throws
}

// MARK: - Errors

enum StorageError: LocalizedError {
    case notFound
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    /// Удалённое хранилище ещё не реализовано — бэкенд в разработке.
    case notImplemented

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Запись не найдена"
        case .saveFailed(let e):
            return "Не удалось сохранить: \(e.localizedDescription)"
        case .fetchFailed(let e):
            return "Не удалось загрузить: \(e.localizedDescription)"
        case .notImplemented:
            return "Функция недоступна: синхронизация с сервером ещё не реализована"
        }
    }
}
