//
//  App.swift
//  SubRadar
//
//  Created by Алексей Розанов on 16.04.2026.
//

import SwiftUI

// MARK: - Gradient helpers
extension LinearGradient {
    static var srAccentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.srAccent, Color.srAccentLight],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static func srButtonGradient(isEnabled: Bool) -> LinearGradient {
        if isEnabled {
            return LinearGradient(
                colors: [Color.srAccent, Color.srAccentLight],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.srSurface2, Color.srSurface2],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Storage Mode accent colors
extension Color {
    static let srModeLocal  = Color(hex: "#7C6EFF")
    static let srModeShared = Color(hex: "#A29BFE")
    // selfHosted использует srTeal (из Assets)
}

// MARK: - Color(hex:)
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
