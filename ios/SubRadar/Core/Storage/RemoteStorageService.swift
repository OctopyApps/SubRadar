//
//  RemoteStorageService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation

@MainActor
final class RemoteStorageService: StorageService {

    private let api: APIClient

    init(serverConfiguration: ServerConfiguration) {
        self.api = APIClient(
            baseURL: serverConfiguration.baseURL,
            tokenProvider: { KeychainService.shared.token() }
        )
    }

    // MARK: - Subscriptions

    func fetchSubscriptions() async throws -> [Subscription] {
        do {
            return try await api.get("/subscriptions")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func save(_ subscription: Subscription) async throws {
        do {
            let body = SubscriptionRequest(from: subscription)
            let _: Subscription = try await api.post("/subscriptions", body: body)
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func update(_ subscription: Subscription) async throws {
        do {
            let body = SubscriptionRequest(from: subscription)
            let _: Subscription = try await api.put("/subscriptions/\(subscription.id)", body: body)
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func delete(_ subscription: Subscription) async throws {
        do {
            try await api.delete("/subscriptions/\(subscription.id)")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    // MARK: - Tags

    func fetchTags() async throws -> [Tag] {
        do {
            return try await api.get("/tags")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func saveTagIfNeeded(name: String) async throws -> Tag {
        do {
            struct TagBody: Encodable { let name: String }
            return try await api.post("/tags", body: TagBody(name: name))
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func deleteTag(_ tag: Tag) async throws {
        do {
            try await api.delete("/tags/\(tag.id)")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [AppCategory] {
        do {
            return try await api.get("/categories")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func saveCategory(_ category: AppCategory) async throws -> AppCategory {
        do {
            struct CategoryBody: Encodable { let name: String; let icon: String }
            return try await api.post("/categories", body: CategoryBody(name: category.name, icon: category.icon))
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func deleteCategory(_ category: AppCategory) async throws {
        do {
            try await api.delete("/categories/\(category.id)")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    // MARK: - Currencies

    func fetchCurrencies() async throws -> [AppCurrency] {
        do {
            return try await api.get("/currencies")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func saveCurrency(_ currency: AppCurrency) async throws -> AppCurrency {
        do {
            struct CurrencyBody: Encodable {
                let code: String
                let symbol: String
                let display_name: String
            }
            return try await api.post("/currencies", body: CurrencyBody(
                code: currency.code,
                symbol: currency.symbol,
                display_name: currency.displayName
            ))
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }

    func deleteCurrency(_ currency: AppCurrency) async throws {
        do {
            try await api.delete("/currencies/\(currency.id)")
        } catch let e as APIError {
            throw e.toStorageError()
        }
    }
}

// MARK: - SubscriptionRequest
// Тело запроса при создании/обновлении подписки.
// id не отправляем при создании — бэкенд генерит сам.
// При обновлении id идёт в URL, не в теле.

private struct SubscriptionRequest: Encodable {
    let name: String
    let category: String
    let price: Double
    let currency: String
    let billing_period: String
    let color: String
    let icon_name: String
    let start_date: Date
    let next_billing_date: Date
    let tag: String?
    let url: String?
    let image_data: Data?

    init(from s: Subscription) {
        self.name             = s.name
        self.category         = s.category.name
        self.price            = s.price
        self.currency         = s.currency.code
        self.billing_period   = s.billingPeriod.rawValue
        self.color            = s.color
        self.icon_name        = s.iconName
        self.start_date       = s.startDate
        self.next_billing_date = s.nextBillingDate
        self.tag              = s.tag
        self.url              = s.url
        self.image_data       = s.imageData
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name,               forKey: .name)
        try container.encode(category,           forKey: .category)
        try container.encode(price,              forKey: .price)
        try container.encode(currency,           forKey: .currency)
        try container.encode(billing_period,     forKey: .billing_period)
        try container.encode(color,              forKey: .color)
        try container.encode(icon_name,          forKey: .icon_name)
        try container.encode(start_date,         forKey: .start_date)
        try container.encode(next_billing_date,  forKey: .next_billing_date)
        try container.encodeIfPresent(tag,        forKey: .tag)
        try container.encodeIfPresent(url,        forKey: .url)
        try container.encodeIfPresent(image_data, forKey: .image_data)
    }

    enum CodingKeys: String, CodingKey {
        case name, category, price, currency, color, tag, url
        case billing_period   = "billing_period"
        case icon_name        = "icon_name"
        case start_date       = "start_date"
        case next_billing_date = "next_billing_date"
        case image_data       = "image_data"
    }
}
