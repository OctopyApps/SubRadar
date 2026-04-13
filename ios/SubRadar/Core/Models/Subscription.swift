//
//  Subscription.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation

// MARK: - Subscription

struct Subscription: Identifiable {
    let id: UUID
    var name: String
    var category: SubscriptionCategory
    var price: Double
    var currency: String
    var billingPeriod: BillingPeriod
    var color: String        // hex, e.g. "#1DB954"
    var iconName: String     // SF Symbol name
    var nextBillingDate: Date

    init(
        id: UUID = UUID(),
        name: String,
        category: SubscriptionCategory,
        price: Double,
        currency: String = "₽",
        billingPeriod: BillingPeriod,
        color: String,
        iconName: String,
        nextBillingDate: Date
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.price = price
        self.currency = currency
        self.billingPeriod = billingPeriod
        self.color = color
        self.iconName = iconName
        self.nextBillingDate = nextBillingDate
    }

    /// Нормализованная стоимость в месяц
    var monthlyPrice: Double {
        switch billingPeriod {
        case .monthly: return price
        case .yearly:  return price / 12
        case .weekly:  return price * 4.33
        }
    }
}

// MARK: - BillingPeriod

enum BillingPeriod: String, CaseIterable, Codable {
    case monthly = "мес"
    case yearly  = "год"
    case weekly  = "нед"

    var title: String {
        switch self {
        case .monthly: return "Ежемесячно"
        case .yearly:  return "Ежегодно"
        case .weekly:  return "Еженедельно"
        }
    }
}

// MARK: - SubscriptionCategory

enum SubscriptionCategory: String, CaseIterable, Codable {
    case all           = "Все"
    case entertainment = "Развлечения"
    case work          = "Работа"
    case health        = "Здоровье"
    case education     = "Обучение"
    case other         = "Другое"
}

// MARK: - Mock data

extension Subscription {
    static let mocks: [Subscription] = [
        Subscription(
            name: "Spotify",
            category: .entertainment,
            price: 299,
            billingPeriod: .monthly,
            color: "#1DB954",
            iconName: "music.note",
            nextBillingDate: Date().addingTimeInterval(86400 * 5)
        ),
        Subscription(
            name: "Netflix",
            category: .entertainment,
            price: 990,
            billingPeriod: .monthly,
            color: "#E50914",
            iconName: "play.rectangle",
            nextBillingDate: Date().addingTimeInterval(86400 * 12)
        ),
        Subscription(
            name: "Notion",
            category: .work,
            price: 1200,
            billingPeriod: .monthly,
            color: "#FFFFFF",
            iconName: "doc.text",
            nextBillingDate: Date().addingTimeInterval(86400 * 3)
        ),
        Subscription(
            name: "iCloud+",
            category: .other,
            price: 149,
            billingPeriod: .monthly,
            color: "#3478F6",
            iconName: "icloud",
            nextBillingDate: Date().addingTimeInterval(86400 * 20)
        ),
    ]
}
