//
//  NotificationsView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 17.04.2026.
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let subscriptions: [Subscription]

    @State private var timePickerExpanded = false

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if !appState.notificationAuthorizationGranted {
                            permissionBanner
                        }
                        masterToggleSection
                        if appState.notificationSettings.isEnabled && appState.notificationAuthorizationGranted {
                            leadTimeSection
                            timeSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
        }
        .task { await appState.refreshNotificationStatus() }
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
            Text("Уведомления")
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

    // MARK: - Permission Banner

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.srWarning.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "bell.slash")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.srWarning)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Уведомления отключены")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.srTextPrimary)
                    Text("Разрешите уведомления чтобы получать напоминания о списаниях")
                        .font(.system(size: 13))
                        .foregroundColor(.srTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Button(action: {
                    Task {
                        let granted = await appState.requestNotificationPermission()
                        if !granted, let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        } else if granted {
                            await reschedule()
                        }
                    }
                }) {
                    Text("Разрешить")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.srAccent))
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }) {
                    Text("Настройки iOS")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.srAccent)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.srAccent.opacity(0.1))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.srAccent.opacity(0.3), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.srSurface2)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srWarning.opacity(0.4), lineWidth: 1))
        )
    }

    // MARK: - Master Toggle

    private var masterToggleSection: some View {
        NotifSection(title: "Напоминания", icon: "bell") {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: appState.notificationSettings.isEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.srAccent)
                }
                Text("Уведомлять о списаниях")
                    .font(.system(size: 16))
                    .foregroundColor(.srTextPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { appState.notificationSettings.isEnabled },
                    set: { newValue in
                        if newValue && !appState.notificationAuthorizationGranted {
                            Task {
                                let granted = await appState.requestNotificationPermission()
                                if granted {
                                    appState.notificationSettings.isEnabled = true
                                    await reschedule()
                                }
                            }
                        } else {
                            appState.notificationSettings.isEnabled = newValue
                            Task { await reschedule() }
                        }
                    }
                ))
                .labelsHidden()
                .tint(.srAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }

    // MARK: - Lead Time

    private var leadTimeSection: some View {
        NotifSection(title: "Когда уведомлять", icon: "clock") {
            ForEach(Array(NotificationLeadTime.allCases.enumerated()), id: \.element) { index, leadTime in
                if index > 0 { Divider().background(Color.srBorder).padding(.leading, 56) }

                let isSelected = appState.notificationSettings.leadTimes.contains(leadTime)

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        if isSelected {
                            guard appState.notificationSettings.leadTimes.count > 1 else { return }
                            appState.notificationSettings.leadTimes.remove(leadTime)
                        } else {
                            appState.notificationSettings.leadTimes.insert(leadTime)
                        }
                        Task { await reschedule() }
                    }
                }) {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                            Image(systemName: leadTime.icon)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.srAccent)
                        }
                        Text(leadTime.displayName)
                            .font(.system(size: 16))
                            .foregroundColor(.srTextPrimary)
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isSelected ? Color.srAccent : Color.srSurface)
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.clear : Color.srBorder, lineWidth: 1.5))
                                .frame(width: 22, height: 22)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Time

    private var timeSection: some View {
        NotifSection(title: "Время уведомления", icon: "clock.fill") {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    timePickerExpanded.toggle()
                }
            }) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                        Image(systemName: "clock")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.srAccent)
                    }
                    Text("Время")
                        .font(.system(size: 16))
                        .foregroundColor(.srTextPrimary)
                    Spacer()
                    Text(appState.notificationSettings.timeDisplayString)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.srAccent)
                    Image(systemName: timePickerExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.srTextTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            if timePickerExpanded {
                Divider().background(Color.srBorder)

                HStack(spacing: 0) {
                    Picker("Часы", selection: Binding(
                        get: { appState.notificationSettings.notificationHour },
                        set: { appState.notificationSettings.notificationHour = $0; Task { await reschedule() } }
                    )) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()

                    Text(":")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.srTextPrimary)

                    Picker("Минуты", selection: Binding(
                        get: { appState.notificationSettings.notificationMinute },
                        set: { appState.notificationSettings.notificationMinute = $0; Task { await reschedule() } }
                    )) {
                        ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { minute in
                            Text(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .frame(height: 160)
                .padding(.horizontal, 8)
            }
        }
    }

    // MARK: - Helpers

    private func reschedule() async {
        await NotificationService.shared.rescheduleAll(
            subscriptions: subscriptions,
            settings: appState.notificationSettings
        )
    }
}

// MARK: - NotifSection

private struct NotifSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.srAccent)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.srTextSecondary)
                    .kerning(0.5)
            }
            .padding(.leading, 4)

            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
                )
        }
    }
}

#Preview {
    NotificationsView(subscriptions: [])
        .environmentObject(AppState())
}
