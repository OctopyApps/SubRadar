//
//  AppConfiguration.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation

struct AppConfiguration: Codable {
    let storageMode: StorageMode
    let isAuthenticated: Bool
    let serverConfiguration: ServerConfiguration

    static func local() -> AppConfiguration {
        AppConfiguration(
            storageMode: .local,
            isAuthenticated: true,
            serverConfiguration: .shared()
        )
    }

    static func shared() -> AppConfiguration {
        AppConfiguration(
            storageMode: .shared,
            isAuthenticated: true,
            serverConfiguration: .shared()
        )
    }

    static func selfHosted(serverConfiguration: ServerConfiguration) -> AppConfiguration {
        AppConfiguration(
            storageMode: .selfHosted,
            isAuthenticated: true,
            serverConfiguration: serverConfiguration
        )
    }
}
