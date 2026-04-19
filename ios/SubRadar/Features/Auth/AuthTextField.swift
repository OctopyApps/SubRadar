//
//  AuthTextField.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

struct AuthTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.srTextTertiary)
                .frame(width: 20)

            if isSecure {
                SecureField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.srTextPrimary)
                    .autocorrectionDisabled()
            } else {
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.srTextPrimary)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.srSurface2)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.srBorder, lineWidth: 1)
                )
        )
    }
}
