//
//  StorageModeSettingsView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 19.04.2026.
//

import SwiftUI

struct StorageModeSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var pendingMode: StorageMode?
    @State private var showConfirmation = false
    @State private var showServerSetup = false

    // Перенос подписок
    @State private var showMigrationAlert = false
    @State private var subscriptionsToMigrate: [Subscription] = []
    @State private var isMigrating = false

    private var currentMode: StorageMode { appState.storageMode }

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        modesSection
                        currentModeInfo
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }

            if isMigrating {
                Color.black.opacity(0.3).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(.white).scaleEffect(1.3)
                    Text("Переносим подписки…")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2))
            }
        }
        // Подтверждение смены на Local
        .alert("Сменить режим?", isPresented: $showConfirmation, presenting: pendingMode) { mode in
            Button("Сменить", role: .destructive) {
                Task { await checkMigrationNeeded(for: mode) }
            }
            Button("Отмена", role: .cancel) { pendingMode = nil }
        } message: { _ in
            Text("Серверные данные будут недоступны до следующего подключения.")
        }
        // Вопрос про перенос подписок
        .alert("Перенести подписки?", isPresented: $showMigrationAlert, presenting: pendingMode) { mode in
            Button("Перенести") {
                Task { await applySwitch(to: mode, migrate: true) }
            }
            Button("Начать чисто", role: .destructive) {
                Task { await applySwitch(to: mode, migrate: false) }
            }
            Button("Отмена", role: .cancel) { pendingMode = nil }
        } message: { _ in
            Text("У вас \(subscriptionsToMigrate.count) подписок. Перенести их в новый режим хранения?")
        }
        // Настройка сервера
        .sheet(isPresented: $showServerSetup, onDismiss: { pendingMode = nil }) {
            if let mode = pendingMode {
                ServerSetupView(mode: mode, onBack: { showServerSetup = false })
                    .environmentObject(appState)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.srTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.srSurface2))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Режим хранения")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.srTextPrimary)
                .kerning(-0.3)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Modes list

    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.srAccent)
                Text("ВЫБЕРИТЕ РЕЖИМ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.srTextSecondary)
                    .kerning(0.5)
            }
            .padding(.leading, 4)

            VStack(spacing: 0) {
                ForEach(Array(StorageMode.allCases.enumerated()), id: \.element) { index, mode in
                    if index > 0 {
                        Divider().background(Color.srBorder).padding(.leading, 70)
                    }
                    StorageModeRow(mode: mode, isCurrent: mode == currentMode) {
                        handleSelect(mode)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
            )
        }
    }

    // MARK: - Info card

    private var currentModeInfo: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.srAccent)
                Text("О РЕЖИМЕ")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.srTextSecondary)
                    .kerning(0.5)
            }
            .padding(.leading, 4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(currentModeDetails, id: \.icon) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14))
                            .foregroundColor(.srAccent)
                            .frame(width: 20)
                        Text(item.text)
                            .font(.system(size: 14))
                            .foregroundColor(.srTextSecondary)
                            .lineSpacing(3)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
            )
        }
    }

    private struct InfoItem {
        let icon: String
        let text: String
    }

    private var currentModeDetails: [InfoItem] {
        switch currentMode {
        case .local:
            return [
                InfoItem(icon: "lock.shield",   text: "Данные хранятся только на этом устройстве"),
                InfoItem(icon: "wifi.slash",     text: "Работает без интернета"),
                InfoItem(icon: "arrow.trianglehead.2.counterclockwise", text: "Синхронизация между устройствами недоступна"),
            ]
        case .shared:
            return [
                InfoItem(icon: "icloud",         text: "Данные синхронизируются через сервер SubRadar"),
                InfoItem(icon: "devices.fill",   text: "Доступно на всех ваших устройствах"),
                InfoItem(icon: "wifi",           text: "Требует подключения к интернету для синхронизации"),
            ]
        case .selfHosted:
            return [
                InfoItem(icon: "server.rack",            text: "Данные на вашем собственном сервере"),
                InfoItem(icon: "shield.lefthalf.filled", text: "Полный контроль над данными"),
                InfoItem(icon: "terminal",               text: "Требует настройки бэкенда SubRadar"),
            ]
        }
    }

    // MARK: - Logic

    private func handleSelect(_ mode: StorageMode) {
        guard mode != currentMode else { return }
        pendingMode = mode
        switch mode {
        case .local:
            showConfirmation = true
        case .shared, .selfHosted:
            showServerSetup = true
        }
    }

    /// Загружаем подписки из текущего хранилища и решаем — показывать алерт о миграции или нет
    private func checkMigrationNeeded(for mode: StorageMode) async {
        let config = UserDefaultsService.shared.configuration ?? .local()
        let currentStorage = StorageServiceFactory.make(for: config)
        let subs = (try? await currentStorage.fetchSubscriptions()) ?? []

        if subs.isEmpty {
            await applySwitch(to: mode, migrate: false)
        } else {
            subscriptionsToMigrate = subs
            showMigrationAlert = true
        }
    }

    /// Применяем смену режима. migrate = true → сохраняем подписки в новое хранилище
    @MainActor
    private func applySwitch(to mode: StorageMode, migrate: Bool) async {
        isMigrating = migrate && !subscriptionsToMigrate.isEmpty

        // Записываем новый конфиг
        switch mode {
        case .local:
            UserDefaultsService.shared.configuration = .local()
        case .shared:
            UserDefaultsService.shared.configuration = .shared()
        case .selfHosted:
            // selfHosted сюда не попадает — он идёт через ServerSetupView
            break
        }

        // Переносим подписки если нужно
        if migrate && !subscriptionsToMigrate.isEmpty {
            let newConfig = UserDefaultsService.shared.configuration ?? .local()
            let newStorage = StorageServiceFactory.make(for: newConfig)
            for sub in subscriptionsToMigrate {
                try? await newStorage.save(sub)
            }
        }

        isMigrating = false
        pendingMode = nil
        dismiss()
    }
}

// MARK: - Storage Mode Row

private struct StorageModeRow: View {
    let mode: StorageMode
    let isCurrent: Bool
    let action: () -> Void

    private var accentColor: Color {
        switch mode {
        case .local:      return Color.srModeLocal
        case .shared:     return Color.srModeShared
        case .selfHosted: return Color.srTeal
        }
    }

    private var iconName: String {
        switch mode {
        case .local:      return "internaldrive"
        case .shared:     return "globe"
        case .selfHosted: return "server.rack"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(isCurrent ? 0.18 : 0.10))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.system(size: 16))
                        .foregroundColor(.srTextPrimary)
                    Text(mode.description)
                        .font(.system(size: 12))
                        .foregroundColor(.srTextSecondary)
                }

                Spacer()

                if isCurrent {
                    Text("Активен")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.srTextTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }
}

#Preview {
    StorageModeSettingsView()
        .environmentObject(AppState())
}
