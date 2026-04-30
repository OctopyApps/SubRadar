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

    // MARK: - Codable
    // Поля совпадают с колонками таблицы categories на бэкенде.
    // user_id не храним на клиенте — сервер берёт его из JWT.

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
    }

    // MARK: - Special

    /// Псевдо-категория "Все" — используется только для фильтра, не синхронизируется
    static let all = AppCategory(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000000")!,
        name: "Все",
        icon: "square.grid.2x2"
    )

    // MARK: - Defaults
    // Захардкожены на клиенте. На сервер синхронизируем только то,
    // что пользователь добавил сам (не входит в этот список).

    static let entertainment = AppCategory(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000001")!,
        name: "Развлечения", icon: "play.circle"
    )
    static let work = AppCategory(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000002")!,
        name: "Работа", icon: "briefcase"
    )
    static let health = AppCategory(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000003")!,
        name: "Здоровье", icon: "heart"
    )
    static let education = AppCategory(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000004")!,
        name: "Обучение", icon: "book"
    )
    static let other = AppCategory(
        id: UUID(uuidString: "00000000-0000-0000-0001-000000000005")!,
        name: "Другое", icon: "ellipsis.circle"
    )

    static let defaults: [AppCategory] = [.entertainment, .work, .health, .education, .other]

    // MARK: - Helpers

    /// True если категория из захардкоженного списка (не синхронизируем на сервер)
    var isDefault: Bool {
        AppCategory.defaults.contains(where: { $0.id == self.id })
    }
}
