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
    // Содержит дефолты + пользовательские. Пользовательские синхронизируются с сервером.

    @Published var currencies: [AppCurrency] {
        didSet { saveCustomCurrencies() }
    }

    // MARK: - Categories
    // Содержит дефолты + пользовательские. Пользовательские синхронизируются с сервером.

    @Published var categories: [AppCategory] {
        didSet { saveCustomCategories() }
    }

    var filterCategories: [AppCategory] { [.all] + categories }

    // MARK: - Notifications

    @Published var notificationSettings: NotificationSettings {
        didSet { save(notificationSettings, forKey: "notificationSettings") }
    }

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

        // Загружаем: дефолты + сохранённые пользовательские
        let customCurrencies = Self.load([AppCurrency].self, forKey: "custom_currencies") ?? []
        currencies = Self.merged(defaults: AppCurrency.defaults, custom: customCurrencies)

        let customCategories = Self.load([AppCategory].self, forKey: "custom_categories") ?? []
        categories = Self.merged(defaults: AppCategory.defaults, custom: customCategories)

        notificationSettings = Self.load(NotificationSettings.self, forKey: "notificationSettings") ?? .default
        selectedIconName = UserDefaults.standard.string(forKey: "selectedIconName")
    }

    // MARK: - Merge helpers

    /// Мерджит дефолты и пользовательские — дефолты всегда первые, дубли по id исключены.
    private static func merged<T: Identifiable>(defaults: [T], custom: [T]) -> [T] where T.ID == UUID {
        let defaultIDs = Set(defaults.map(\.id))
        let onlyCustom = custom.filter { !defaultIDs.contains($0.id) }
        return defaults + onlyCustom
    }

    /// Загружает пользовательские категории с сервера и мерджит с дефолтами.
    func syncCategories(from storage: any StorageService) async {
        guard let serverCategories = try? await storage.fetchCategories() else { return }
        let customCategories = serverCategories.filter { !$0.isDefault }
        let defaultIDs = Set(AppCategory.defaults.map(\.id))
        let merged = AppCategory.defaults + customCategories.filter { !defaultIDs.contains($0.id) }
        categories = merged
        saveCustomCategories()
    }

    /// Загружает пользовательские валюты с сервера и мерджит с дефолтами.
    func syncCurrencies(from storage: any StorageService) async {
        guard let serverCurrencies = try? await storage.fetchCurrencies() else { return }
        let customCurrencies = serverCurrencies.filter { !$0.isDefault }
        let defaultIDs = Set(AppCurrency.defaults.map(\.id))
        let merged = AppCurrency.defaults + customCurrencies.filter { !defaultIDs.contains($0.id) }
        currencies = merged
        saveCustomCurrencies()
    }

    // MARK: - Сохранение (только пользовательские, без дефолтов)

    private func saveCustomCurrencies() {
        let custom = currencies.filter { !$0.isDefault }
        save(custom, forKey: "custom_currencies")
    }

    private func saveCustomCategories() {
        let custom = categories.filter { !$0.isDefault }
        save(custom, forKey: "custom_categories")
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
        guard !currency.isDefault, currencies.count > 1 else { return }
        currencies.removeAll { $0.id == currency.id }
    }

    func removeCurrency(at offsets: IndexSet) {
        // Не даём удалить дефолтные через свайп
        let toRemove = offsets.compactMap { currencies.indices.contains($0) ? currencies[$0] : nil }
        guard toRemove.allSatisfy({ !$0.isDefault }) else { return }
        guard currencies.count - offsets.count >= 1 else { return }
        currencies.remove(atOffsets: offsets)
    }

    // MARK: - Category intents

    func addCategory(_ category: AppCategory) {
        guard !categories.contains(where: { $0.name.lowercased() == category.name.lowercased() }) else { return }
        categories.append(category)
    }

    func removeCategory(_ category: AppCategory) {
        guard !category.isDefault, categories.count > 1 else { return }
        categories.removeAll { $0.id == category.id }
    }

    func removeCategory(at offsets: IndexSet) {
        let toRemove = offsets.compactMap { categories.indices.contains($0) ? categories[$0] : nil }
        guard toRemove.allSatisfy({ !$0.isDefault }) else { return }
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
