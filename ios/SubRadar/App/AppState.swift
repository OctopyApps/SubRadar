//
//  AppState.swift
//  SubRadar
//
//  Created by Алексей Розанов on 12.04.2026.
//

import SwiftUI

enum AppScreen {
    case onboarding
    case auth(StorageMode)
    case main
}

// MARK: - ColorSchemePreference

enum ColorSchemePreference: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var displayName: String {
        switch self {
        case .system: return "Как в системе"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen

    // MARK: - Theme

    @Published var colorSchemePreference: ColorSchemePreference {
        didSet { UserDefaults.standard.set(colorSchemePreference.rawValue, forKey: "colorSchemePreference") }
    }

    // MARK: - Currencies

    @Published var currencies: [AppCurrency] {
        didSet { save(currencies, forKey: "currencies") }
    }

    // MARK: - Categories

    @Published var categories: [AppCategory] {
        didSet { save(categories, forKey: "categories") }
    }

    var filterCategories: [AppCategory] { [.all] + categories }

    // MARK: - Notifications

    @Published var notificationSettings: NotificationSettings {
        didSet { save(notificationSettings, forKey: "notificationSettings") }
    }

    /// Статус разрешения — обновляется при запуске и при открытии экрана уведомлений
    @Published var notificationAuthorizationGranted: Bool = false

    private let defaults = UserDefaultsService.shared

    init() {
        if let config = defaults.configuration, config.isAuthenticated {
            currentScreen = .main
        } else {
            currentScreen = .onboarding
        }

        let schemePref = UserDefaults.standard.string(forKey: "colorSchemePreference") ?? "system"
        colorSchemePreference = ColorSchemePreference(rawValue: schemePref) ?? .system

        currencies = Self.load([AppCurrency].self, forKey: "currencies") ?? AppCurrency.defaults
        categories = Self.load([AppCategory].self, forKey: "categories") ?? AppCategory.defaults
        notificationSettings = Self.load(NotificationSettings.self, forKey: "notificationSettings") ?? .default
        selectedIconName = UserDefaults.standard.string(forKey: "selectedIconName")
    }

    // MARK: - Notification permission

    func refreshNotificationStatus() async {
        let status = await NotificationService.shared.authorizationStatus()
        notificationAuthorizationGranted = (status == .authorized || status == .provisional)
    }

    func requestNotificationPermission() async -> Bool {
        let granted = await NotificationService.shared.requestPermission()
        notificationAuthorizationGranted = granted
        return granted
    }

    // MARK: - Currency intents

    func addCurrency(_ currency: AppCurrency) {
        guard !currencies.contains(where: { $0.code == currency.code }) else { return }
        currencies.append(currency)
    }

    func removeCurrency(_ currency: AppCurrency) {
        guard currencies.count > 1 else { return }
        currencies.removeAll { $0.id == currency.id }
    }

    func removeCurrency(at offsets: IndexSet) {
        guard currencies.count - offsets.count >= 1 else { return }
        currencies.remove(atOffsets: offsets)
    }

    // MARK: - Category intents

    func addCategory(_ category: AppCategory) {
        guard !categories.contains(where: { $0.name.lowercased() == category.name.lowercased() }) else { return }
        categories.append(category)
    }

    func removeCategory(_ category: AppCategory) {
        guard categories.count > 1 else { return }
        categories.removeAll { $0.id == category.id }
    }

    func removeCategory(at offsets: IndexSet) {
        guard categories.count - offsets.count >= 1 else { return }
        categories.remove(atOffsets: offsets)
    }

    // MARK: - Lookup helpers

    func currency(forCode code: String) -> AppCurrency {
        currencies.first { $0.code == code }
            ?? AppCurrency.allPredefined.first { $0.code == code }
            ?? AppCurrency(code: code, symbol: code, displayName: code)
    }

    func category(forName name: String) -> AppCategory {
        categories.first { $0.name == name }
            ?? AppCategory.defaults.first { $0.name == name }
            ?? AppCategory(name: name, icon: "ellipsis.circle")
    }

    // MARK: - Storage Mode

    var storageMode: StorageMode {
        defaults.configuration?.storageMode ?? .local
    }

    // MARK: - Auth intents

    func selectMode(_ mode: StorageMode) {
        switch mode {
        case .local:
            defaults.configuration = .local()
            withAnimation(.easeInOut(duration: 0.4)) { currentScreen = .main }
        case .shared, .selfHosted:
            withAnimation(.easeInOut(duration: 0.3)) { currentScreen = .auth(mode) }
        }
    }

    func completeAuth(mode: StorageMode, token: String? = nil, serverConfiguration: ServerConfiguration = .shared()) {
        if let token { KeychainService.shared.save(token) }
        switch mode {
        case .local:      defaults.configuration = .local()
        case .shared:     defaults.configuration = .shared()
        case .selfHosted: defaults.configuration = .selfHosted(serverConfiguration: serverConfiguration)
        }
        withAnimation(.easeInOut(duration: 0.4)) { currentScreen = .main }
    }

    func logout() {
        KeychainService.shared.deleteToken()
        defaults.configuration = nil
        withAnimation(.easeInOut(duration: 0.4)) { currentScreen = .onboarding }
    }

    func resetForDebug() {
        defaults.configuration = nil
        withAnimation(.easeInOut(duration: 0.4)) { currentScreen = .onboarding }
    }

    // MARK: - UserDefaults helpers

    private static func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
    
    // MARK: - Icon

    /// nil = основная иконка
    @Published var selectedIconName: String? {
        didSet { UserDefaults.standard.set(selectedIconName, forKey: "selectedIconName") }
    }

    func setAppIcon(_ iconName: String?) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            if let error {
                print("Icon error: \(error)")
            } else {
                DispatchQueue.main.async {
                    self?.selectedIconName = iconName
                }
            }
        }
    }
}
