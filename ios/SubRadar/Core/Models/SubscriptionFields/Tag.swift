//
//  Tag.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

/// Тег — свободный текст, создаётся пользователем.
/// Хранится отдельно чтобы поддерживать автодополнение по всем существующим тегам.
struct Tag: Identifiable, Hashable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}
