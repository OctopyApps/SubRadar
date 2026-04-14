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
    var currency: Currency
    var billingPeriod: BillingPeriod
    var color: String        // hex, e.g. "#1DB954"
    var iconName: String     // SF Symbol name
    var startDate: Date
    var nextBillingDate: Date
    var tag: String?         // свободный текст, один тег
    var url: String?         // ссылка на сервис
    var imageData: Data?     // опциональная картинка

    init(
        id: UUID = UUID(),
        name: String,
        category: SubscriptionCategory = .other,
        price: Double,
        currency: Currency = .rub,
        billingPeriod: BillingPeriod = .monthly,
        color: String = "#6C5CE7",
        iconName: String = "creditcard",
        startDate: Date = Date(),
        nextBillingDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
        tag: String? = nil,
        url: String? = nil,
        imageData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.price = price
        self.currency = currency
        self.billingPeriod = billingPeriod
        self.color = color
        self.iconName = iconName
        self.startDate = startDate
        self.nextBillingDate = nextBillingDate
        self.tag = tag
        self.url = url
        self.imageData = imageData
    }

    /// Нормализованная стоимость в месяц (в исходной валюте)
    var monthlyPrice: Double {
        switch billingPeriod {
        case .monthly: return price
        case .yearly:  return price / 12
        case .daily:   return price * 30.44
        }
    }
}

// MARK: - Currency

enum Currency: String, CaseIterable, Codable {
    case rub = "RUB"
    case usd = "USD"
    case eur = "EUR"

    var symbol: String {
        switch self {
        case .rub: return "₽"
        case .usd: return "$"
        case .eur: return "€"
        }
    }

    var displayName: String {
        switch self {
        case .rub: return "Рубль"
        case .usd: return "Доллар"
        case .eur: return "Евро"
        }
    }
}

// MARK: - BillingPeriod

enum BillingPeriod: String, CaseIterable, Codable {
    case monthly = "мес"
    case yearly  = "год"
    case daily   = "день"

    var title: String {
        switch self {
        case .monthly: return "Ежемесячно"
        case .yearly:  return "Ежегодно"
        case .daily:   return "Ежедневно"
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
