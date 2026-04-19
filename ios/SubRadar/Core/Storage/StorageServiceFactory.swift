//
//  StorageServiceFactory.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import Foundation

enum StorageServiceFactory {
    @MainActor
    static func make(for config: AppConfiguration, appState: AppState? = nil) -> any StorageService {
        switch config.storageMode {
        case .local:
            return LocalStorageService(appState: appState)
        case .shared, .selfHosted:
            return RemoteStorageService(serverConfiguration: config.serverConfiguration)
        }
    }
}
