//
//  StorageServiceFactory.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

/// Создаёт нужную реализацию StorageService в зависимости от конфигурации приложения.
/// ViewModel и View не знают про конкретные классы — только про протокол.
@MainActor
enum StorageServiceFactory {
    static func make(for configuration: AppConfiguration) -> any StorageService {
        switch configuration.storageMode {
        case .local:
            return LocalStorageService()
        case .shared, .selfHosted:
            return RemoteStorageService(serverConfiguration: configuration.serverConfiguration)
        }
    }
}
