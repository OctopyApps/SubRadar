//
//  SubscriptionsView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

// MARK: - Scroll offset preference

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Main View

struct SubscriptionsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SubscriptionsViewModel

    init() {
        let config = UserDefaultsService.shared.configuration ?? .local()
        let storage = StorageServiceFactory.make(for: config)
        _viewModel = StateObject(wrappedValue: SubscriptionsViewModel(storage: storage))
    }

    @State private var scrollOffset: CGFloat = 0
    private let collapseThreshold: CGFloat = 80

    private var collapseProgress: CGFloat {
        guard scrollOffset < 0 else { return 0 }
        return min(-scrollOffset / collapseThreshold, 1.0)
    }

    private var heroFontSize: CGFloat      { 36 - (36 - 18) * collapseProgress }
    private var heroKerning: CGFloat       { -1.0 + (1.0 - 0.2) * collapseProgress }
    private var subtitleOpacity: CGFloat   { max(0, 1 - collapseProgress * 3) }
    private var heroPaddingTop: CGFloat    { 20 - 10 * collapseProgress }
    private var heroPaddingBottom: CGFloat { 24 - 14 * collapseProgress }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.srBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                    }
                    .frame(height: 0)

                    if viewModel.isLoading {
                        loadingState.padding(.top, 40)
                    } else if viewModel.isEmpty {
                        emptyState.padding(.top, 40)
                    } else {
                        subscriptionCards
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }

                    Spacer().frame(height: 100)
                }
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                    scrollOffset = value
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) { stickyHeader }

            tabBar
        }
        .task {
            await viewModel.load()
            await appState.refreshNotificationStatus()
        }
        .sheet(isPresented: $viewModel.isMenuOpen) {
            MenuSheet().environmentObject(appState)
        }
        .sheet(isPresented: $viewModel.isAddingSubscription) {
            AddSubscriptionView(storage: viewModel.storage) { subscription in
                viewModel.subscriptionAdded(subscription)
            }
            .environmentObject(appState)
        }
        .sheet(item: $viewModel.editingSubscription) { subscription in
            EditSubscriptionView(subscription: subscription, storage: viewModel.storage) { updated in
                viewModel.subscriptionUpdated(updated)
            }
            .environmentObject(appState)
        }
        .alert("Ошибка", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { e in Text(e.localizedDescription) }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            topBar.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 4)
            heroTotal.padding(.top, heroPaddingTop).padding(.bottom, heroPaddingBottom)
            Rectangle().fill(Color.srBorder).frame(height: 1).opacity(collapseProgress)
            categoryFilter.padding(.top, 12).padding(.bottom, 12)
        }
        .background(Color.srBackground.ignoresSafeArea(edges: .top))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("SubRadar")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.srTextPrimary)
                .kerning(-0.4)
            Spacer()
            UserAvatarView(mode: appState.storageMode)
        }
    }

    // MARK: - Hero Total

    private var heroTotal: some View {
        VStack(spacing: 4) {
            if viewModel.activeCurrencyTotals.isEmpty {
                Text("0 / мес")
                    .font(.system(size: heroFontSize, weight: .bold))
                    .foregroundColor(.srTextPrimary)
                    .kerning(heroKerning)
            } else if viewModel.activeCurrencyTotals.count == 1,
                      let entry = viewModel.activeCurrencyTotals.first {
                Text("\(viewModel.formattedTotal(for: entry.currency)) / мес")
                    .font(.system(size: heroFontSize, weight: .bold))
                    .foregroundColor(.srTextPrimary)
                    .kerning(heroKerning)
                    .contentTransition(.numericText())
            } else {
                HStack(spacing: 16) {
                    ForEach(viewModel.activeCurrencyTotals, id: \.currency.code) { entry in
                        VStack(spacing: 2) {
                            Text(viewModel.formattedTotal(for: entry.currency))
                                .font(.system(size: heroFontSize, weight: .bold))
                                .foregroundColor(.srTextPrimary)
                                .kerning(heroKerning)
                                .contentTransition(.numericText())
                            Text(entry.currency.code)
                                .font(.system(size: 11))
                                .foregroundColor(.srTextTertiary)
                                .opacity(subtitleOpacity)
                        }
                        if entry.currency.code != viewModel.activeCurrencyTotals.last?.currency.code {
                            Rectangle().fill(Color.srBorder).frame(width: 1, height: 28).opacity(subtitleOpacity)
                        }
                    }
                }
            }
            Text("\(viewModel.subscriptions.count) активных подписок")
                .font(.system(size: 13))
                .foregroundColor(.srTextSecondary)
                .opacity(subtitleOpacity)
                .frame(height: subtitleOpacity > 0 ? nil : 0)
                .clipped()
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        let available = viewModel.availableCategories(from: appState.categories)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                CategoryPill(title: AppCategory.all.name, isSelected: viewModel.selectedCategory.id == AppCategory.all.id) {
                    viewModel.selectCategory(.all)
                }
                ForEach(available) { cat in
                    CategoryPill(title: cat.name, isSelected: viewModel.selectedCategory.id == cat.id) {
                        viewModel.selectCategory(cat)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Cards

    private var subscriptionCards: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filtered) { sub in
                SubscriptionCard(
                    subscription: sub,
                    onEdit:      { viewModel.openEdit(sub) },
                    onDuplicate: { Task { await viewModel.duplicate(sub) } },
                    onDelete:    { Task { await viewModel.delete(sub) } }
                )
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Color.srAccent).scaleEffect(1.2)
            Text("Загрузка...").font(.system(size: 14)).foregroundColor(.srTextSecondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.srAccent.opacity(0.1)).frame(width: 72, height: 72)
                Image(systemName: "creditcard").font(.system(size: 28, weight: .medium)).foregroundColor(Color.srAccent.opacity(0.6))
            }
            VStack(spacing: 6) {
                Text("Нет подписок").font(.system(size: 18, weight: .semibold)).foregroundColor(.srTextPrimary)
                Text("Нажмите + чтобы добавить первую").font(.system(size: 14)).foregroundColor(.srTextSecondary)
            }
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(alignment: .center) {
            TabBarButton(iconName: "calendar", label: "Календарь") {}
            Spacer()
            AddButton { viewModel.openAddSubscription() }
            Spacer()
            TabBarButton(iconName: "line.3.horizontal", label: "Меню") { viewModel.openMenu() }
        }
        .padding(.horizontal, 40).padding(.top, 16).padding(.bottom, 28)
        .background(
            Rectangle().fill(Color.srSurface)
                .overlay(Rectangle().fill(Color.srBorder).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - User Avatar

private struct UserAvatarView: View {
    let mode: StorageMode

    private var accentColor: Color {
        switch mode {
        case .local:      return .srModeLocal
        case .shared:     return .srModeShared
        case .selfHosted: return .srTeal
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(accentColor.opacity(0.15)).frame(width: 36, height: 36)
                .overlay(Circle().stroke(accentColor.opacity(0.3), lineWidth: 1))
            switch mode {
            case .shared:
                Image(systemName: "person.fill").font(.system(size: 16, weight: .medium)).foregroundColor(accentColor)
            case .local:
                Text("L").font(.system(size: 15, weight: .semibold)).foregroundColor(accentColor).kerning(-0.3)
            case .selfHosted:
                Text("S").font(.system(size: 15, weight: .semibold)).foregroundColor(accentColor).kerning(-0.3)
            }
        }
    }
}

// MARK: - Category Pill

private struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .srTextSecondary)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20).fill(isSelected ? Color.srAccent : Color.srSurface2)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.clear : Color.srBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let subscription: Subscription
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    @State private var isPressed = false

    private var daysUntilBilling: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: subscription.nextBillingDate).day ?? 0
    }
    private var billingLabel: String {
        switch daysUntilBilling {
        case 0: return "сегодня"
        case 1: return "завтра"
        case let d: return "через \(d) дн."
        }
    }
    private var billingLabelColor: Color {
        switch daysUntilBilling {
        case 0...2: return .srDanger
        case 3...5: return .srWarning
        default:    return .srTextSecondary
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = subscription.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill()
                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 13))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(Color(hex: subscription.color).opacity(0.15)).frame(width: 48, height: 48)
                Image(systemName: subscription.iconName).font(.system(size: 20, weight: .medium)).foregroundColor(Color(hex: subscription.color))
            }
        }
    }

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                iconView
                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name).font(.system(size: 16, weight: .medium)).foregroundColor(.srTextPrimary)
                    HStack(spacing: 6) {
                        Text(billingLabel).font(.system(size: 12)).foregroundColor(billingLabelColor)
                        if let tag = subscription.tag {
                            Text("· \(tag)").font(.system(size: 12)).foregroundColor(.srTextTertiary)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(subscription.currency.symbol) \(Int(subscription.price))")
                        .font(.system(size: 16, weight: .semibold)).foregroundColor(.srTextPrimary)
                    Text("/ \(subscription.billingPeriod.rawValue)")
                        .font(.system(size: 12)).foregroundColor(.srTextTertiary)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18).fill(Color.srSurface2)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.srBorder, lineWidth: 1))
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
        .contextMenu {
            Button(action: onEdit) { Label("Изменить", systemImage: "pencil") }
            Button(action: onDuplicate) { Label("Дублировать", systemImage: "plus.square.on.square") }
            Divider()
            Button(role: .destructive, action: onDelete) { Label("Удалить", systemImage: "trash") }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) { Label("Удалить", systemImage: "trash") }
        }
    }
}

// MARK: - Tab Bar Components

private struct TabBarButton: View {
    let iconName: String
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName).font(.system(size: 20, weight: .medium)).foregroundColor(.srTextSecondary)
                Text(label).font(.system(size: 10)).foregroundColor(.srTextTertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AddButton: View {
    let action: () -> Void
    @State private var isPressed = false
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(LinearGradient.srAccentGradient).frame(width: 56, height: 56)
                    .shadow(color: Color.srAccent.opacity(0.5), radius: 12, y: 4)
                Image(systemName: "plus").font(.system(size: 22, weight: .medium)).foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
    }
}

// MARK: - Menu Sheet

struct MenuSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var showSettings = false
    @State private var showNotifications = false

    var body: some View {
        ZStack {
            Color.srSurface.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 2).fill(Color.srBorder).frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity).padding(.top, 12).padding(.bottom, 28)
                Text("Меню").font(.system(size: 22, weight: .semibold)).foregroundColor(.srTextPrimary)
                    .kerning(-0.5).padding(.horizontal, 24).padding(.bottom, 24)
                VStack(spacing: 4) {
                    MenuRow(icon: "gear",                        label: "Настройки")        { showSettings = true }
                    MenuRow(icon: "bell",                        label: "Уведомления")       { showNotifications = true }
                    MenuRow(icon: "arrow.triangle.2.circlepath", label: "Режим хранения")    {}
                    MenuRow(icon: "questionmark.circle",         label: "Помощь")            {}
                }
                .padding(.horizontal, 16)
                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.srSurface)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(appState)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView(subscriptions: [])
                .environmentObject(appState)
        }
    }
}

private struct MenuRow: View {
    let icon: String
    let label: String
    let action: () -> Void
    @State private var isPressed = false
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(Color.srAccent.opacity(0.12)).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundColor(.srAccent)
                }
                Text(label).font(.system(size: 16, weight: .regular)).foregroundColor(.srTextPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium)).foregroundColor(.srTextTertiary)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14).fill(isPressed ? Color.srSurface2 : Color.clear))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }.onEnded { _ in isPressed = false })
    }
}

#Preview {
    SubscriptionsView().environmentObject(AppState())
}
