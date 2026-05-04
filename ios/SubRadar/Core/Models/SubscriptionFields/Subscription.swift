//
//  Subscription.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation

// MARK: - Subscription

struct Subscription: Identifiable, Codable {
    let id: UUID
    var name: String
    var category: AppCategory
    var price: Double
    var currency: AppCurrency
    var billingPeriod: BillingPeriod
    var color: String
    var iconName: String
    var startDate: Date
    var nextBillingDate: Date
    var tag: String?
    var url: String?
    var imageData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        category: AppCategory = .other,
        price: Double,
        currency: AppCurrency = .rub,
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

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case price
        case currency
        case billingPeriod   = "billing_period"
        case color
        case iconName        = "icon_name"
        case startDate       = "start_date"
        case nextBillingDate = "next_billing_date"
        case tag
        case url
        case imageData       = "image_data"
    }

    // Бэкенд хранит category и currency как строки (имя и код).
    // Декодируем строку и резолвим в объект через дефолты.
    // Если совпадения нет — создаём заглушку чтобы не терять данные.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id             = try c.decode(UUID.self,         forKey: .id)
        name           = try c.decode(String.self,       forKey: .name)
        price          = try c.decode(Double.self,       forKey: .price)
        color          = try c.decode(String.self,       forKey: .color)
        iconName       = try c.decode(String.self,       forKey: .iconName)
        startDate      = try c.decode(Date.self,         forKey: .startDate)
        nextBillingDate = try c.decode(Date.self,        forKey: .nextBillingDate)
        tag            = try c.decodeIfPresent(String.self, forKey: .tag)
        url            = try c.decodeIfPresent(String.self, forKey: .url)
        imageData      = try c.decodeIfPresent(Data.self,   forKey: .imageData)

        let periodRaw  = try c.decode(String.self, forKey: .billingPeriod)
        billingPeriod  = BillingPeriod(rawValue: periodRaw) ?? .monthly

        // category — строка с именем категории на бэкенде
        let categoryName = try c.decode(String.self, forKey: .category)
        category = AppCategory.defaults.first { $0.name == categoryName }
            ?? AppCategory(name: categoryName, icon: "ellipsis.circle")

        // currency — строка с кодом валюты на бэкенде
        let currencyCode = try c.decode(String.self, forKey: .currency)
        currency = AppCurrency.allPredefined.first { $0.code == currencyCode }
            ?? AppCurrency(code: currencyCode, symbol: currencyCode, displayName: currencyCode)
    }

    // MARK: - Computed

    var monthlyPrice: Double {
        switch billingPeriod {
        case .monthly: return price
        case .yearly:  return price / 12
        case .daily:   return price * 30.44
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
