//
//  RegisterView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

struct RegisterView: View {
    let mode: StorageMode
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: RegisterViewModel
    @Environment(\.dismiss) private var dismiss

    init(mode: StorageMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: RegisterViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Header
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Назад")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(.srTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    VStack(spacing: 8) {
                        Text("Регистрация")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.srTextPrimary)
                            .kerning(-0.6)

                        Text(mode == .shared ? "Общий сервер" : "Свой сервер")
                            .font(.system(size: 15))
                            .foregroundColor(.srTextSecondary)
                    }
                    .padding(.bottom, 40)

                    // Fields
                    VStack(spacing: 12) {
                        AuthTextField(
                            placeholder: "Email",
                            text: $viewModel.email,
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        AuthTextField(
                            placeholder: "Пароль",
                            text: $viewModel.password,
                            icon: "lock",
                            isSecure: true
                        )
                        AuthTextField(
                            placeholder: "Повторите пароль",
                            text: $viewModel.passwordConfirm,
                            icon: "lock.fill",
                            isSecure: true
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Password hint
                    HStack {
                        Text("Минимум 8 символов")
                            .font(.system(size: 12))
                            .foregroundColor(.srTextTertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Error
                    if let error = viewModel.errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 13))
                            Text(error)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.srDanger)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    }

                    // Register button
                    Button {
                        viewModel.register(appState: appState)
                    } label: {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Создать аккаунт")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(viewModel.isLoading ? Color.srAccentDark : Color.srAccent)
                        )
                    }
                    .padding(.horizontal, 24)
                    .disabled(viewModel.isLoading)

                    // Terms note
                    Text("Регистрируясь, вы соглашаетесь с условиями использования сервиса")
                        .font(.system(size: 11))
                        .foregroundColor(.srTextTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    RegisterView(mode: .shared)
        .environmentObject(AppState())
}
