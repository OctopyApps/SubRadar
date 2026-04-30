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
    var category: String        // AppCategory.name
    var price: Double
    var currency: String        // AppCurrency.code
    var billingPeriod: String
    var color: String
    var iconName: String
    var startDate: Date
    var nextBillingDate: Date
    var createdAt: Date
    var tag: String?
    var url: String?
    @Attribute(.externalStorage) var imageData: Data?

    init(from s: Subscription) {
        self.id              = s.id
        self.name            = s.name
        self.category        = s.category.name
        self.price           = s.price
        self.currency        = s.currency.code
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
        category        = s.category.name
        price           = s.price
        currency        = s.currency.code
        billingPeriod   = s.billingPeriod.rawValue
        color           = s.color
        iconName        = s.iconName
        startDate       = s.startDate
        nextBillingDate = s.nextBillingDate
        tag             = s.tag
        url             = s.url
        imageData       = s.imageData
    }

    /// Передаём уже разрешённые значения, чтобы не касаться @MainActor внутри
    func toDomain(
        resolvedCurrency: AppCurrency,
        resolvedCategory: AppCategory
    ) -> Subscription? {
        guard let period = BillingPeriod(rawValue: billingPeriod) else { return nil }
        return Subscription(
            id:              id,
            name:            name,
            category:        resolvedCategory,
            price:           price,
            currency:        resolvedCurrency,
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
    private weak var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState

        let schema = Schema([SubscriptionEntity.self, TagEntity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        if let c = try? ModelContainer(for: schema, configurations: [config]) {
            container = c
            return
        }

        Self.destroyStore(config: config)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("LocalStorageService: не удалось создать ModelContainer: \(error)")
        }
    }

    private static func destroyStore(config: ModelConfiguration) {
        let url = config.url
        for suffix in ["", "-shm", "-wal"] {
            let file = suffix.isEmpty ? url : URL(fileURLWithPath: url.path + String(suffix))
            try? FileManager.default.removeItem(at: file)
        }
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Lookup helpers (синхронные, вызываются на MainActor)

    private func resolveCurrency(code: String) -> AppCurrency {
        if let appState {
            return appState.currency(forCode: code)
        }
        return AppCurrency.allPredefined.first { $0.code == code }
            ?? AppCurrency(code: code, symbol: code, displayName: code)
    }

    private func resolveCategory(name: String) -> AppCategory {
        if let appState {
            return appState.category(forName: name)
        }
        return AppCategory.defaults.first { $0.name == name }
            ?? AppCategory(name: name, icon: "ellipsis.circle")
    }

    // MARK: - Subscriptions

    func fetchSubscriptions() async throws -> [Subscription] {
        let descriptor = FetchDescriptor<SubscriptionEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        do {
            let entities = try context.fetch(descriptor)
            return entities.compactMap { entity in
                entity.toDomain(
                    resolvedCurrency: resolveCurrency(code: entity.currency),
                    resolvedCategory: resolveCategory(name: entity.category)
                )
            }
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    func save(_ subscription: Subscription) async throws {
        context.insert(SubscriptionEntity(from: subscription))
        try saveContext()
        if let tag = subscription.tag {
            _ = try await saveTagIfNeeded(name: tag)
        }
    }

    func update(_ subscription: Subscription) async throws {
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try context.fetch(descriptor).first else { throw StorageError.notFound }
        entity.update(from: subscription)
        try saveContext()
        if let tag = subscription.tag {
            _ = try await saveTagIfNeeded(name: tag)
        }
    }

    func delete(_ subscription: Subscription) async throws {
        let id = subscription.id
        let descriptor = FetchDescriptor<SubscriptionEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try context.fetch(descriptor).first else { throw StorageError.notFound }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Tags

    func fetchTags() async throws -> [Tag] {
        let descriptor = FetchDescriptor<TagEntity>(sortBy: [SortDescriptor(\.name)])
        do {
            return try context.fetch(descriptor).map { $0.toDomain() }
        } catch {
            throw StorageError.fetchFailed(underlying: error)
        }
    }

    func saveTagIfNeeded(name: String) async throws -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<TagEntity>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try context.fetch(descriptor).first { return existing.toDomain() }
        let tag = Tag(name: trimmed)
        context.insert(TagEntity(from: tag))
        try saveContext()
        return tag
    }

    func deleteTag(_ tag: Tag) async throws {
        let id = tag.id
        let descriptor = FetchDescriptor<TagEntity>(predicate: #Predicate { $0.id == id })
        guard let entity = try context.fetch(descriptor).first else { throw StorageError.notFound }
        context.delete(entity)
        try saveContext()
    }

    // MARK: - Categories
    // В локальном режиме категории живут в AppState (UserDefaults).
    // StorageService-методы просто проксируют туда — единый интерфейс для всех режимов.

    func fetchCategories() async throws -> [AppCategory] {
        // Возвращаем только пользовательские — дефолты AppState добавляет сам при мерже
        return appState?.categories.filter { !$0.isDefault } ?? []
    }

    func saveCategory(_ category: AppCategory) async throws -> AppCategory {
        guard let appState else { return category }
        appState.addCategory(category)
        return category
    }

    func deleteCategory(_ category: AppCategory) async throws {
        guard !category.isDefault else { return }
        appState?.removeCategory(category)
    }

    // MARK: - Currencies
    // Аналогично категориям — живут в AppState (UserDefaults).

    func fetchCurrencies() async throws -> [AppCurrency] {
        // Возвращаем только пользовательские — дефолты AppState добавляет сам при мерже
        return appState?.currencies.filter { !$0.isDefault } ?? []
    }

    func saveCurrency(_ currency: AppCurrency) async throws -> AppCurrency {
        guard let appState else { return currency }
        appState.addCurrency(currency)
        return currency
    }

    func deleteCurrency(_ currency: AppCurrency) async throws {
        guard !currency.isDefault else { return }
        appState?.removeCurrency(currency)
    }

    // MARK: - Private

    private func saveContext() throws {
        do { try context.save() } catch { throw StorageError.saveFailed(underlying: error) }
    }
}
