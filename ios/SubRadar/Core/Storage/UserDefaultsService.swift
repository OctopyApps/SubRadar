//
//  UserDefaultsService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import Foundation

final class UserDefaultsService {
    static let shared = UserDefaultsService()
    private init() {}

    private let configurationKey = "app_configuration"

    var configuration: AppConfiguration? {
        get {
            guard let data = UserDefaults.standard.data(forKey: configurationKey),
                  let config = try? JSONDecoder().decode(AppConfiguration.self, from: data)
            else { return nil }
            return config
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: configurationKey)
        }
    }

    var hasConfiguration: Bool {
        configuration != nil
    }
}   
