//
//  AppCurrency.swift
//  SubRadar
//
//  Created by Алексей Розанов on 17.04.2026.
//

import Foundation

struct AppCurrency: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var code: String      // "RUB", "USD", кастомный — "GBP"
    var symbol: String    // "₽", "$", "£"
    var displayName: String

    init(id: UUID = UUID(), code: String, symbol: String, displayName: String) {
        self.id = id
        self.code = code
        self.symbol = symbol
        self.displayName = displayName
    }

    // MARK: - Defaults

    static let rub = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                                 code: "RUB", symbol: "₽", displayName: "Рубль")
    static let usd = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                                 code: "USD", symbol: "$", displayName: "Доллар")
    static let eur = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                                 code: "EUR", symbol: "€", displayName: "Евро")
    static let gbp = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
                                 code: "GBP", symbol: "£", displayName: "Фунт")
    static let cny = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
                                 code: "CNY", symbol: "¥", displayName: "Юань")
    static let aed = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
                                 code: "AED", symbol: "د.إ", displayName: "Дирхам")
    static let try_ = AppCurrency(id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
                                  code: "TRY", symbol: "₺", displayName: "Лира")

    static let allPredefined: [AppCurrency] = [.rub, .usd, .eur, .gbp, .cny, .aed, .try_]
    static let defaults: [AppCurrency] = [.rub, .usd, .eur]
}
