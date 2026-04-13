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
    let authToken: String?
    let serverURL: String?

    static func local() -> AppConfiguration {
        AppConfiguration(
            storageMode: .local,
            isAuthenticated: true,
            authToken: nil,
            serverURL: nil
        )
    }

    static func shared(token: String?) -> AppConfiguration {
        AppConfiguration(
            storageMode: .shared,
            isAuthenticated: true,
            authToken: token,
            serverURL: nil
        )
    }

    static func selfHosted(token: String?, serverURL: String?) -> AppConfiguration {
        AppConfiguration(
            storageMode: .selfHosted,
            isAuthenticated: true,
            authToken: token,
            serverURL: serverURL
        )
    }
}
