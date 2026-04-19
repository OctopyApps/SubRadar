//
//  OnboardingView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                AppIconView()
                    .padding(.bottom, 24)

                Text("SubRadar")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.srTextPrimary)
                    .kerning(-0.6)
                    .padding(.bottom, 8)

                Text("Выберите, где хранить\nваши данные")
                    .font(.system(size: 15))
                    .foregroundColor(.srTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 44)

                VStack(spacing: 12) {
                    ForEach(StorageMode.allCases, id: \.self) { mode in
                        StorageModeCard(
                            mode: mode,
                            isSelected: viewModel.selectedMode == mode
                        ) {
                            viewModel.select(mode, appState: appState)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Text("Режим можно сменить позже\nв настройках приложения")
                    .font(.system(size: 12))
                    .foregroundColor(.srTextTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 28)

                Spacer()
            }
        }
    }
}

// MARK: - App Icon

private struct AppIconView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // Показываем иконку из Assets если она уже добавлена,
        // иначе фоллбэк — градиентный квадрат с SF Symbol
        let assetName = colorScheme == .dark ? "AppIconDM1" : "AppIconLM1"

        if let uiImage = UIImage(named: assetName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient.srAccentGradient)
                    .frame(width: 72, height: 72)
                Image(systemName: "dot.radiowaves.up.forward")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Storage Mode Card

private struct StorageModeCard: View {
    let mode: StorageMode
    let isSelected: Bool
    let action: () -> Void

    @State private var isPressed = false

    private var accentColor: Color {
        switch mode {
        case .local:      return Color.srModeLocal
        case .shared:     return Color.srModeShared
        case .selfHosted: return Color.srTeal
        }
    }

    private var iconName: String {
        switch mode {
        case .local:      return "doc.text"
        case .shared:     return "globe"
        case .selfHosted: return "server.rack"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.srTextPrimary)
                    Text(mode.description)
                        .font(.system(size: 13))
                        .foregroundColor(.srTextSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(mode.isFeatured ? .srAccent : .srTextTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.srSurface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                mode.isFeatured ? Color.srAccent : Color.srBorder,
                                lineWidth: mode.isFeatured ? 2 : 1
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if mode.isFeatured {
                    Text("популярно")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.srAccent)
                        .cornerRadius(6)
                        .padding(.top, 10)
                        .padding(.trailing, 14)
                }
            }
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
