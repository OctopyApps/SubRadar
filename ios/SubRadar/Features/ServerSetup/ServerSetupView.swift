//
//  ServerSetupView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

struct ServerSetupView: View {
    let mode: StorageMode
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ServerSetupViewModel
    @FocusState private var focusedField: Field?

    enum Field { case host, port, secret }

    init(mode: StorageMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: ServerSetupViewModel(mode: mode))
    }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Back button
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                appState.currentScreen = .onboarding
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Назад")
                                    .font(.system(size: 16))
                            }
                            .foregroundColor(Color(hex: "#7777AA"))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 60)
                    .padding(.bottom, 40)

                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "#2DD4BF").opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "server.rack")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(Color(hex: "#2DD4BF"))
                        }
                        .padding(.bottom, 8)

                        Text("Свой сервер")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color(hex: "#EEEEFF"))
                            .kerning(-0.6)

                        Text("Введите данные для подключения\nк вашему серверу SubRadar")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#6666AA"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    .padding(.bottom, 40)

                    // Form
                    VStack(spacing: 12) {

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Адрес сервера")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#55558A"))
                                .padding(.leading, 4)

                            AuthTextField(
                                placeholder: "192.168.1.100 или example.com",
                                text: $viewModel.host,
                                icon: "network"
                            )
                            .focused($focusedField, equals: .host)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .port }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Порт")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#55558A"))
                                .padding(.leading, 4)

                            AuthTextField(
                                placeholder: "8080",
                                text: $viewModel.port,
                                icon: "point.3.connected.trianglepath.dotted",
                                keyboardType: .numberPad
                            )
                            .focused($focusedField, equals: .port)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .secret }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Секретный ключ")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "#55558A"))
                                .padding(.leading, 4)

                            AuthTextField(
                                placeholder: "Секретный ключ сервера",
                                text: $viewModel.secret,
                                icon: "key.horizontal",
                                isSecure: true
                            )
                            .focused($focusedField, equals: .secret)
                            .submitLabel(.go)
                            .onSubmit { viewModel.connect(appState: appState) }
                        }
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
                        .foregroundColor(Color(hex: "#FF6B6B"))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 12)
                    }

                    // Connect button
                    Button {
                        focusedField = nil
                        viewModel.connect(appState: appState)
                    } label: {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 14))
                                    Text("Подключиться")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    viewModel.isLoading
                                        ? Color(hex: "#1A8A7A")
                                        : Color(hex: "#2DD4BF")
                                )
                        )
                    }
                    .padding(.horizontal, 24)
                    .disabled(viewModel.isLoading)

                    // Hint
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color(hex: "#2D2D45"))
                            .padding(.vertical, 24)

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#44446A"))
                                .padding(.top, 1)
                            Text("Убедитесь что сервер SubRadar запущен и доступен по указанному адресу. Секретный ключ задаётся при настройке сервера.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#44446A"))
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onTapGesture { focusedField = nil }
    }
}

#Preview {
    ServerSetupView(mode: .selfHosted)
        .environmentObject(AppState())
}
