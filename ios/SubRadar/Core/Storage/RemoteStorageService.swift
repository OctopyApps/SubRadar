//
//  RemoteStorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation

/// Заглушка удалённого хранилища для режимов .shared и .selfHosted.
///
/// Чтения возвращают пустые данные, записи бросают `.notImplemented`.
/// Когда бэкенд будет готов — заменить тела методов на реальные HTTP-запросы,
/// используя `serverConfiguration.baseURL` и `authToken` для авторизации.
@MainActor
final class RemoteStorageService: StorageService {

    private let serverConfiguration: ServerConfiguration

    /// Токен читается из Keychain при каждом запросе — всегда актуален.
    private var authToken: String? { KeychainService.shared.token() }

    init(serverConfiguration: ServerConfiguration) {
        self.serverConfiguration = serverConfiguration
    }

    // MARK: - Subscriptions

    func fetchSubscriptions() async throws -> [Subscription] {
        // TODO: GET \(serverConfiguration.baseURL)/subscriptions
        return []
    }

    func save(_ subscription: Subscription) async throws {
        // TODO: POST \(serverConfiguration.baseURL)/subscriptions
        throw StorageError.notImplemented
    }

    func update(_ subscription: Subscription) async throws {
        // TODO: PUT \(serverConfiguration.baseURL)/subscriptions/\(subscription.id)
        throw StorageError.notImplemented
    }

    func delete(_ subscription: Subscription) async throws {
        // TODO: DELETE \(serverConfiguration.baseURL)/subscriptions/\(subscription.id)
        throw StorageError.notImplemented
    }

    // MARK: - Tags

    func fetchTags() async throws -> [Tag] {
        // TODO: GET \(serverConfiguration.baseURL)/tags
        return []
    }

    func saveTagIfNeeded(name: String) async throws -> Tag {
        // TODO: POST \(serverConfiguration.baseURL)/tags
        throw StorageError.notImplemented
    }

    func deleteTag(_ tag: Tag) async throws {
        // TODO: DELETE \(serverConfiguration.baseURL)/tags/\(tag.id)
        throw StorageError.notImplemented
    }
}
