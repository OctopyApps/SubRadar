//
//  StorageMode.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import Foundation

enum StorageMode: String, CaseIterable, Codable {
    case local      = "local"
    case shared     = "shared"
    case selfHosted = "selfHosted"

    var title: String {
        switch self {
        case .local:      return "Локальный режим"
        case .shared:     return "Общий сервер"
        case .selfHosted: return "Свой сервер"
        }
    }

    var description: String {
        switch self {
        case .local:      return "Только на устройстве · Без облака"
        case .shared:     return "Синхронизация · Несколько устройств"
        case .selfHosted: return "Self-hosted · Полный контроль"
        }
    }

    var isFeatured: Bool {
        self == .shared
    }
}
