import SwiftUI

struct AuthView: View {
    let mode: StorageMode
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: AuthViewModel

    init(mode: StorageMode) {
        self.mode = mode
        _viewModel = StateObject(wrappedValue: AuthViewModel(mode: mode))
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
                        Text("Вход")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(Color(hex: "#EEEEFF"))
                            .kerning(-0.6)

                        Text(mode == .shared ? "Общий сервер" : "Свой сервер")
                            .font(.system(size: 15))
                            .foregroundColor(Color(hex: "#6666AA"))
                    }
                    .padding(.bottom, 40)

                    // Form
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
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 12)
                    }

                    // Login button
                    Button {
                        viewModel.loginWithEmail(appState: appState)
                    } label: {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Войти")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(hex: "#6C5CE7"))
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                    .disabled(viewModel.isLoading)

                    // Register link
                    HStack(spacing: 4) {
                        Text("Нет аккаунта?")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#44446A"))
                        Button {
                            viewModel.showRegister = true
                        } label: {
                            Text("Зарегистрироваться")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "#A29BFE"))
                        }
                    }
                    .padding(.bottom, 24)

                    // Divider
                    HStack(spacing: 12) {
                        Rectangle()
                            .fill(Color(hex: "#2D2D45"))
                            .frame(height: 1)
                        Text("или")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#44446A"))
                        Rectangle()
                            .fill(Color(hex: "#2D2D45"))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Social buttons
                    VStack(spacing: 12) {
                        SocialAuthButton(
                            label: "Войти через Apple",
                            icon: "apple.logo",
                            isSystemIcon: true
                        ) {
                            viewModel.loginWithGoogle(appState: appState)
                        }

                        SocialAuthButton(
                            label: "Войти через Google",
                            googleLogo: true
                        ) {
                            viewModel.loginWithGoogle(appState: appState)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
        }
        // .sheet живёт здесь — на уровне ZStack, где виден viewModel
        .sheet(isPresented: $viewModel.showRegister) {
            RegisterView(mode: mode)
                .environmentObject(appState)
        }
    }
}

// MARK: - Social Auth Button

private struct SocialAuthButton: View {
    let label: String
    var icon: String = ""
    var isSystemIcon: Bool = false
    var googleLogo: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if googleLogo {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                        Text("G")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(hex: "#4285F4"))
                    }
                } else if isSystemIcon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#DDDDF5"))
                        .frame(width: 20, height: 20)
                }

                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#DDDDF5"))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#13131F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "#2D2D45"), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Preview

#Preview {
    AuthView(mode: .shared)
        .environmentObject(AppState())
}
