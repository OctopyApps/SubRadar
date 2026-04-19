//
//  AppCategory.swift
//  SubRadar
//
//  Created by Алексей Розанов on 17.04.2026.
//

import Foundation

struct AppCategory: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var icon: String      // SF Symbol

    init(id: UUID = UUID(), name: String, icon: String) {
        self.id = id
        self.name = name
        self.icon = icon
    }

    // MARK: - Special

    /// Псевдо-категория "Все" — используется только для фильтра, не хранится
    static let all = AppCategory(id: UUID(uuidString: "00000000-0000-0000-0001-000000000000")!,
                                 name: "Все", icon: "square.grid.2x2")

    // MARK: - Defaults

    static let entertainment = AppCategory(id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
                                           name: "Развлечения", icon: "play.circle")
    static let work          = AppCategory(id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
                                           name: "Работа", icon: "briefcase")
    static let health        = AppCategory(id: UUID(uuidString: "00000000-0000-0000-0001-000000000003")!,
                                           name: "Здоровье", icon: "heart")
    static let education     = AppCategory(id: UUID(uuidString: "00000000-0000-0000-0001-000000000004")!,
                                           name: "Обучение", icon: "book")
    static let other         = AppCategory(id: UUID(uuidString: "00000000-0000-0000-0001-000000000005")!,
                                           name: "Другое", icon: "ellipsis.circle")

    static let defaults: [AppCategory] = [.entertainment, .work, .health, .education, .other]
}
