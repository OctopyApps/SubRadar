//
//  StorageServiceFactory.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

/// Создаёт нужную реализацию StorageService в зависимости от режима хранения.
/// ViewModel и View не знают про конкретные классы — только про протокол.
@MainActor
enum StorageServiceFactory {
    static func make(for mode: StorageMode) -> any StorageService {
        switch mode {
        case .local:
            return LocalStorageService()
        case .shared, .selfHosted:
            // TODO: вернуть RemoteStorageService когда будет готов бэкенд
            // Пока fallback на локальное хранилище чтобы не крашиться
            return LocalStorageService()
        }
    }
}
