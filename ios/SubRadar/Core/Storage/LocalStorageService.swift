//
//  LocalStorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation
import SwiftData

// MARK: - SwiftData: SubscriptionEntity

@Model
final class SubscriptionEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var category: String
    var price: Double
    var currency: String
    var billingPeriod: String
    var color: String
    var iconName: String
    var startDate: Date
    var nextBillingDate: Date
    var createdAt: Date
    var tag: String?
    var url: String?
    @Attribute(.externalStorage) var imageData: Data?   // большие блобы хранятся отдельно

    init(from s: Subscription) {
        self.id              = s.id
        self.name            = s.name
        self.category        = s.category.rawValue
        self.price           = s.price
        self.currency        = s.currency.rawValue
        self.billingPeriod   = s.billingPeriod.rawValue
        self.color           = s.color
        self.iconName        = s.iconName
        self.startDate       = s.startDate
        self.nextBillingDate = s.nextBillingDate
        self.createdAt       = Date()
        self.tag             = s.tag
        self.url             = s.url
        self.imageData       = s.imageData
    }

    func update(from s: Subscription) {
        name            = s.name
        category        = s.category.rawValue
        price           = s.price
        currency        = s.currency.rawValue
        billingPeriod   = s.billingPeriod.rawValue
        color           = s.color
        iconName        = s.iconName
        startDate       = s.startDate
        nextBillingDate = s.nextBillingDate
        tag             = s.tag
        url             = s.url
        imageData       = s.imageData
    }

    func toDomain() -> Subscription? {
        guard
            let cat    = SubscriptionCategory(rawValue: category),
            let period = BillingPeriod(rawValue: billingPeriod),
            let cur    = Currency(rawValue: currency)
        else { return nil }

        return Subscription(
            id:              id,
            name:            name,
            category:        cat,
            price:           price,
            currency:        cur,
            billingPeriod:   period,
            color:           color,
            iconName:        iconName,
            startDate:       startDate,
            nextBillingDate: nextBillingDate,
            tag:             tag,
            url:             url,
            imageData:       imageData
        )
    }
}

// MARK: - SwiftData: TagEntity

@Model
final class TagEntity {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var createdAt: Date

    init(from tag: Tag) {
        self.id        = tag.id
        self.name      = tag.name
        self.createdAt = Date()
    }

    func toDomain() -> Tag {
        Tag(id: id, name: name)
    }
}

// MARK: - LocalStorageService

@MainActor
final class LocalStorageService: StorageService {

    private let container: ModelContainer

    init() {
        let schema = Schema([SubscriptionEntity.self, TagEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            container = c
            return
        }

        // Схема изменилась и автомиграция невозможна — удаляем стор и пересоздаём.
        // В продакшне здесь должен быть MigrationPlan. Пока мы в разработке — это приемлемо.
        Self.destroyStore(config: config)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("LocalStorageService: не удалось создать ModelContainer даже после сброса: \(error)")
        }
    }

    private static func destroyStore(config: ModelConfiguration) {
        let url = config.url
        let fm = FileManager.default
        // SwiftData создаёт несколько файлов (.sqlite, .sqlite-shm, .sqlite-wal)
        for suffix in ["", "-shm", "-wal"] {
            let file = suffix.isEmpty ? url : URL(fileURLWithPath: url.path + String(suffix))
            try? fm.removeItem(at: file)
        }
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Subscriptions

    func fetchSubscriptions() async throws -> [Subscription] {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor).compactMap { $0.toDomain() }
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    func save(_ subscription: Subscription) async throws {
        context.insert(SubscriptionEntity(from: subscription))
        try saveContext()
        // Сохраняем тег автоматически если указан
        if let tag = subscription.tag {
            _ = try await saveTagIfNeeded(name: tag)
        }
    }

    func update(_ subscription: Subscription) async throws {
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.notFound
        }
        entity.update(from: subscription)
        try saveContext()
        if let tag = subscription.tag {
            _ = try await saveTagIfNeeded(name: tag)
        }
    }

    func delete(_ subscription: Subscription) async throws {
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.notFound
        }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Tags

    func fetchTags() async throws -> [Tag] {
        let descriptor = FetchDescriptor<TagEntity>(
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            return try context.fetch(descriptor).map { $0.toDomain() }
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    func saveTagIfNeeded(name: String) async throws -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.name == trimmed }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing.toDomain()
        }
        let tag = Tag(name: trimmed)
        let entity = TagEntity(from: tag)
        context.insert(entity)
        try saveContext()
        return tag
    }

    func deleteTag(_ tag: Tag) async throws {
        let id = tag.id
        let descriptor = FetchDescriptor<TagEntity>(
            predicate: #Predicate { $0.id == id }
        )
        guard let entity = try context.fetch(descriptor).first else {
            throw StorageError.notFound
        }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Private

    private func saveContext() throws {
        do {
            try context.save()
        } catch {
            throw StorageError.saveFailed(underlying: error)
        }
    }
}
