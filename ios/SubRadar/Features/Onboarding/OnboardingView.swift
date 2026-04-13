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
            Color(hex: "#0A0A0F").ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App icon
                AppIconView()
                    .padding(.bottom, 24)
                
                // Title
                Text("SubRadar")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(Color(hex: "#EEEEFF"))
                    .kerning(-0.6)
                    .padding(.bottom, 8)
                
                Text("Выберите, где хранить\nваши данные")
                    .font(.system(size: 15))
                    .foregroundColor(Color(hex: "#6666AA"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.bottom, 44)
                
                // Mode cards
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
                
                // Footer
                Text("Режим можно сменить позже\nв настройках приложения")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#3A3A60"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.top, 28)
                
                Spacer()
            }
        }
    Button("Сбросить (debug)") {
        appState.resetForDebug()
    }
    .font(.system(size: 12))
    .foregroundColor(Color(hex: "#3A3A60"))
    .padding(.top, 8)
    }
}

// MARK: - App Icon

private struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#6C5CE7"), Color(hex: "#A29BFE")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 72, height: 72)

            Image(systemName: "dot.radiowaves.up.forward")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(.white)
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
        case .local:      return Color(hex: "#7C6EFF")
        case .shared:     return Color(hex: "#A29BFE")
        case .selfHosted: return Color(hex: "#2DD4BF")
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
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(accentColor)
                }

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#DDDDF5"))

                    Text(mode.description)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#55558A"))
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(
                        mode.isFeatured ? Color(hex: "#6C5CE7") : Color(hex: "#44446A")
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#13131F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                mode.isFeatured ? Color(hex: "#6C5CE7") : Color(hex: "#2D2D45"),
                                lineWidth: mode.isFeatured ? 2 : 1
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if mode.isFeatured {
                    Text("популярно")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "#EEEEFF"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#6C5CE7"))
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

// MARK: - Color hex extension

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

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}
