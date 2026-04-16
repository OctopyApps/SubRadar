//
//  SettingsView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 16.04.2026.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showAddCurrency = false
    @State private var showAddCategory = false

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        themeSection
                        currenciesSection
                        categoriesSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showAddCurrency) {
            AddCurrencySheet().environmentObject(appState)
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet().environmentObject(appState)
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
            Text("Настройки")
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

    // MARK: - Theme

    private var themeSection: some View {
        SettingsSection(title: "Оформление", icon: "paintbrush") {
            ForEach(Array(ColorSchemePreference.allCases.enumerated()), id: \.element) { index, pref in
                if index > 0 { Divider().background(Color.srBorder).padding(.leading, 56) }
                ThemeRow(preference: pref, isSelected: appState.colorSchemePreference == pref) {
                    withAnimation(.easeInOut(duration: 0.2)) { appState.colorSchemePreference = pref }
                }
            }
        }
    }

    // MARK: - Currencies

    private var currenciesSection: some View {
        SettingsSection(title: "Валюты", icon: "dollarsign.circle", onAdd: { showAddCurrency = true }) {
            ForEach(Array(appState.currencies.enumerated()), id: \.element.id) { index, currency in
                if index > 0 { Divider().background(Color.srBorder).padding(.leading, 56) }
                CurrencyRow(
                    currency: currency,
                    canDelete: appState.currencies.count > 1
                ) {
                    withAnimation { appState.removeCurrency(currency) }
                }
            }
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        SettingsSection(title: "Категории", icon: "square.grid.2x2", onAdd: { showAddCategory = true }) {
            ForEach(Array(appState.categories.enumerated()), id: \.element.id) { index, category in
                if index > 0 { Divider().background(Color.srBorder).padding(.leading, 56) }
                CategoryRow(
                    category: category,
                    canDelete: appState.categories.count > 1
                ) {
                    withAnimation { appState.removeCategory(category) }
                }
            }
        }
    }
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    var onAdd: (() -> Void)? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
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
                Spacer()
                if let onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.srAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 0) { content }
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
                )
        }
    }
}

// MARK: - Theme Row

private struct ThemeRow: View {
    let preference: ColorSchemePreference
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: preference.icon).font(.system(size: 16, weight: .medium)).foregroundColor(.srAccent)
                }
                Text(preference.displayName).font(.system(size: 16)).foregroundColor(.srTextPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)).foregroundColor(.srAccent)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Currency Row

private struct CurrencyRow: View {
    let currency: AppCurrency
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                Text(currency.symbol).font(.system(size: 16, weight: .semibold)).foregroundColor(.srAccent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(currency.displayName).font(.system(size: 16)).foregroundColor(.srTextPrimary)
                Text(currency.code).font(.system(size: 12)).foregroundColor(.srTextSecondary)
            }
            Spacer()
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.srDanger)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: AppCategory
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: category.icon).font(.system(size: 16, weight: .medium)).foregroundColor(.srAccent)
            }
            Text(category.name).font(.system(size: 16)).foregroundColor(.srTextPrimary)
            Spacer()
            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.srDanger)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}

// MARK: - Add Currency Sheet

private struct AddCurrencySheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var available: [AppCurrency] {
        AppCurrency.allPredefined.filter { predefined in
            !appState.currencies.contains(where: { $0.code == predefined.code })
        }
    }

    @State private var customCode = ""
    @State private var customSymbol = ""
    @State private var customName = ""
    @State private var showCustom = false

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
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
                    Text("Добавить валюту")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.srTextPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Predefined
                        if !available.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("ПОПУЛЯРНЫЕ")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.srTextSecondary)
                                    .kerning(0.5)
                                    .padding(.leading, 4)

                                VStack(spacing: 0) {
                                    ForEach(Array(available.enumerated()), id: \.element.id) { index, cur in
                                        if index > 0 { Divider().background(Color.srBorder).padding(.leading, 56) }
                                        Button(action: {
                                            appState.addCurrency(cur)
                                            dismiss()
                                        }) {
                                            HStack(spacing: 14) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                                                    Text(cur.symbol).font(.system(size: 16, weight: .semibold)).foregroundColor(.srAccent)
                                                }
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(cur.displayName).font(.system(size: 16)).foregroundColor(.srTextPrimary)
                                                    Text(cur.code).font(.system(size: 12)).foregroundColor(.srTextSecondary)
                                                }
                                                Spacer()
                                                Image(systemName: "plus").font(.system(size: 14, weight: .medium)).foregroundColor(.srAccent)
                                            }
                                            .padding(.horizontal, 16).padding(.vertical, 13)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
                                )
                            }
                        }

                        // Custom
                        VStack(alignment: .leading, spacing: 10) {
                            Button(action: { withAnimation { showCustom.toggle() } }) {
                                HStack(spacing: 6) {
                                    Image(systemName: showCustom ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.srAccent)
                                    Text("СВОЯ ВАЛЮТА")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.srTextSecondary)
                                        .kerning(0.5)
                                }
                                .padding(.leading, 4)
                            }
                            .buttonStyle(.plain)

                            if showCustom {
                                VStack(spacing: 0) {
                                    HStack(spacing: 12) {
                                        Text("Код").font(.system(size: 14)).foregroundColor(.srTextSecondary).frame(width: 80, alignment: .leading)
                                        TextField("USD", text: $customCode).font(.system(size: 16)).foregroundColor(.srTextPrimary).tint(.srAccent)
                                            .autocorrectionDisabled().textInputAutocapitalization(.characters)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)

                                    Divider().background(Color.srBorder)

                                    HStack(spacing: 12) {
                                        Text("Символ").font(.system(size: 14)).foregroundColor(.srTextSecondary).frame(width: 80, alignment: .leading)
                                        TextField("$", text: $customSymbol).font(.system(size: 16)).foregroundColor(.srTextPrimary).tint(.srAccent)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)

                                    Divider().background(Color.srBorder)

                                    HStack(spacing: 12) {
                                        Text("Название").font(.system(size: 14)).foregroundColor(.srTextSecondary).frame(width: 80, alignment: .leading)
                                        TextField("Доллар", text: $customName).font(.system(size: 16)).foregroundColor(.srTextPrimary).tint(.srAccent)
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
                                )

                                let canAdd = !customCode.trimmingCharacters(in: .whitespaces).isEmpty
                                    && !customSymbol.trimmingCharacters(in: .whitespaces).isEmpty
                                    && !customName.trimmingCharacters(in: .whitespaces).isEmpty

                                Button(action: {
                                    guard canAdd else { return }
                                    let cur = AppCurrency(
                                        code: customCode.trimmingCharacters(in: .whitespaces).uppercased(),
                                        symbol: customSymbol.trimmingCharacters(in: .whitespaces),
                                        displayName: customName.trimmingCharacters(in: .whitespaces)
                                    )
                                    appState.addCurrency(cur)
                                    dismiss()
                                }) {
                                    Text("Добавить")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(canAdd ? .white : .srTextTertiary)
                                        .frame(maxWidth: .infinity).frame(height: 52)
                                        .background(RoundedRectangle(cornerRadius: 14).fill(canAdd ? Color.srAccent : Color.srSurface2))
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAdd)
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Add Category Sheet

private struct AddCategorySheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "tag"

    private let icons = [
        "tag", "star", "heart", "bolt", "flame", "leaf", "globe",
        "car", "airplane", "house", "music.note", "gamecontroller",
        "cart", "bag", "gift", "camera", "newspaper", "tv"
    ]

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
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
                    Text("Добавить категорию")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.srTextPrimary)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Name
                        VStack(alignment: .leading, spacing: 10) {
                            Text("НАЗВАНИЕ")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.srTextSecondary).kerning(0.5).padding(.leading, 4)

                            HStack(spacing: 12) {
                                Text("Имя").font(.system(size: 14)).foregroundColor(.srTextSecondary).frame(width: 80, alignment: .leading)
                                TextField("Транспорт", text: $name).font(.system(size: 16)).foregroundColor(.srTextPrimary).tint(.srAccent)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
                            )
                        }

                        // Icon picker
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ИКОНКА")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.srTextSecondary).kerning(0.5).padding(.leading, 4)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: { selectedIcon = icon }) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedIcon == icon ? Color.srAccent : Color.srSurface2)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(selectedIcon == icon ? Color.clear : Color.srBorder, lineWidth: 1)
                                                )
                                            Image(systemName: icon)
                                                .font(.system(size: 18, weight: .medium))
                                                .foregroundColor(selectedIcon == icon ? .white : .srTextSecondary)
                                        }
                                        .frame(height: 52)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // Add button
                        Button(action: {
                            guard canAdd else { return }
                            let cat = AppCategory(
                                name: name.trimmingCharacters(in: .whitespaces),
                                icon: selectedIcon
                            )
                            appState.addCategory(cat)
                            dismiss()
                        }) {
                            Text("Добавить")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(canAdd ? .white : .srTextTertiary)
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(RoundedRectangle(cornerRadius: 14).fill(canAdd ? Color.srAccent : Color.srSurface2))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAdd)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView().environmentObject(AppState())
}
