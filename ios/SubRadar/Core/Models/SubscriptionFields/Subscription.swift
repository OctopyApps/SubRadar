//
//  Subscription.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//
//
//  Subscription.swift
//  SubRadar
//

import Foundation

// MARK: - Subscription

struct Subscription: Identifiable {
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
