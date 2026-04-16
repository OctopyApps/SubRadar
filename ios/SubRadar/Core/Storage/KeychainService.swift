//
//  KeychainService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private init() {}

    private let service = "io.subradar.app"
    private let account = "auth_token"

    // MARK: - Public

    func save(_ token: String) {
        guard let data = token.data(using: .utf8) else { return }
        SecItemDelete(baseQuery() as CFDictionary)
        let query = baseQuery().merging([kSecValueData: data]) { $1 }
        SecItemAdd(query as CFDictionary, nil)
    }

    func token() -> String? {
        let query = baseQuery().merging([
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]) { $1 }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteToken() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    // MARK: - Private

    private func baseQuery() -> [CFString: Any] {
        [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}
