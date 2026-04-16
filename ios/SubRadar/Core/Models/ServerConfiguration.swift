//
//  ServerConfiguration.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation

struct ServerConfiguration: Codable {
    let baseURL: String

    /// URL эндпоинта авторизации.
    var authURL: URL? { URL(string: baseURL + "/auth") }

    /// Настройки централизованного сервера SubRadar.
    static func shared() -> ServerConfiguration {
        ServerConfiguration(baseURL: "https://api.subradar.io")
    }

    /// Настройки self-hosted сервера пользователя.
    static func selfHosted(host: String, port: Int) -> ServerConfiguration {
        ServerConfiguration(baseURL: "http://\(host):\(port)")
    }
}
