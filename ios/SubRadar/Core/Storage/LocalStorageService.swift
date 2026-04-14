//
//  LocalStorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation
import SwiftData

// MARK: - SwiftData Model

/// Персистентная модель для SwiftData.
/// Отдельна от Subscription (domain model) намеренно:
/// domain model — чистый struct без зависимостей на SwiftData.
@Model
final class SubscriptionEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String        // rawValue из SubscriptionCategory
    var price: Double
    var currency: String
    var billingPeriod: String   // rawValue из BillingPeriod
    var color: String
    var iconName: String
    var nextBillingDate: Date
    var createdAt: Date

    init(from subscription: Subscription) {
        self.id             = subscription.id
        self.name           = subscription.name
        self.category       = subscription.category.rawValue
        self.price          = subscription.price
        self.currency       = subscription.currency
        self.billingPeriod  = subscription.billingPeriod.rawValue
        self.color          = subscription.color
        self.iconName       = subscription.iconName
        self.nextBillingDate = subscription.nextBillingDate
        self.createdAt      = Date()
    }

    /// Конвертация обратно в domain model
    func toDomain() -> Subscription? {
        guard
            let cat = SubscriptionCategory(rawValue: category),
            let period = BillingPeriod(rawValue: billingPeriod)
        else { return nil }

        return Subscription(
            id: id,
            name: name,
            category: cat,
            price: price,
            currency: currency,
            billingPeriod: period,
            color: color,
            iconName: iconName,
            nextBillingDate: nextBillingDate
        )
    }
}

// MARK: - LocalStorageService

/// Реализация StorageService поверх SwiftData (локальное хранилище на устройстве).
@MainActor
final class LocalStorageService: StorageService {

    private let container: ModelContainer

    init() {
        let schema = Schema([SubscriptionEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("LocalStorageService: не удалось создать ModelContainer: \(error)")
        }
    }

    // MARK: StorageService

    func fetchSubscriptions() async throws -> [Subscription] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let entities = try context.fetch(descriptor)
            return entities.compactMap { $0.toDomain() }
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    func save(_ subscription: Subscription) async throws {
        let context = container.mainContext
        let entity = SubscriptionEntity(from: subscription)
        context.insert(entity)
        do {
            try context.save()
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }
    }

    func update(_ subscription: Subscription) async throws {
        let context = container.mainContext
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.notFound
        }
        entity.name             = subscription.name
        entity.category         = subscription.category.rawValue
        entity.price            = subscription.price
        entity.currency         = subscription.currency
        entity.billingPeriod    = subscription.billingPeriod.rawValue
        entity.color            = subscription.color
        entity.iconName         = subscription.iconName
        entity.nextBillingDate  = subscription.nextBillingDate
        do {
            try context.save()
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }
    }

    func delete(_ subscription: Subscription) async throws {
        let context = container.mainContext
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.notFound
        }
        context.delete(entity)
        do {
            try context.save()
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }
    }
}
