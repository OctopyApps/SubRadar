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
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Main View

struct SubscriptionsView: View {
    @EnvironmentObject private var appState: AppState

    // ViewModel создаётся с нужным сервисом через фабрику
    @StateObject private var viewModel: SubscriptionsViewModel

    init() {
        // StateObject с кастомным init — стандартный паттерн для внедрения зависимостей
        let storage = StorageServiceFactory.make(for: UserDefaultsService.shared.configuration?.storageMode ?? .local)
        _viewModel = StateObject(wrappedValue: SubscriptionsViewModel(storage: storage))
    }

    @State private var scrollOffset: CGFloat = 0

    private let collapseThreshold: CGFloat = 80

    private var collapseProgress: CGFloat {
        guard scrollOffset < 0 else { return 0 }
        return min(-scrollOffset / collapseThreshold, 1.0)
    }

    private var heroFontSize: CGFloat   { 48 - (48 - 22) * collapseProgress }
    private var heroKerning: CGFloat    { -1.5 + (1.5 - 0.3) * collapseProgress }
    private var subtitleOpacity: CGFloat { max(0, 1 - collapseProgress * 3) }
    private var heroPaddingTop: CGFloat    { 28 - 18 * collapseProgress }
    private var heroPaddingBottom: CGFloat { 32 - 20 * collapseProgress }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ScrollOffsetKey.self,
                                value: geo.frame(in: .named("scroll")).minY
                            )
                    }
                    .frame(height: 0)

                    // Контент в зависимости от состояния
                    if viewModel.isLoading {
                        loadingState
                            .padding(.top, 40)
                    } else if viewModel.isEmpty {
                        emptyState
                            .padding(.top, 40)
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
            .safeAreaInset(edge: .top, spacing: 0) {
                stickyHeader
            }

            tabBar
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isMenuOpen) {
            MenuSheet()
                .environmentObject(appState)
        }
        .alert("Ошибка", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Sticky Header

    private var stickyHeader: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 4)

            heroTotal
                .padding(.top, heroPaddingTop)
                .padding(.bottom, heroPaddingBottom)

            Rectangle()
                .fill(Color(hex: "#1E1E35"))
                .frame(height: 1)
                .opacity(collapseProgress)

            categoryFilter
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
        .background(
            Color(hex: "#0A0A0F")
                .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: Top Bar

    private var topBar: some View {
        HStack {
            Text("SubRadar")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "#EEEEFF"))
                .kerning(-0.4)

            Spacer()

            UserAvatarView(mode: appState.storageMode)
        }
    }

    // MARK: Hero Total

    private var heroTotal: some View {
        VStack(spacing: 6) {
            Text(viewModel.formattedTotal)
                .font(.system(size: heroFontSize, weight: .bold))
                .foregroundColor(Color(hex: "#EEEEFF"))
                .kerning(heroKerning)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)

            Text("\(viewModel.subscriptions.count) активных подписок")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#55558A"))
                .opacity(subtitleOpacity)
                .frame(height: subtitleOpacity > 0 ? nil : 0)
                .clipped()
        }
    }

    // MARK: Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableCategories, id: \.self) { cat in
                    CategoryPill(
                        title: cat.rawValue,
                        isSelected: viewModel.selectedCategory == cat
                    ) {
                        viewModel.selectCategory(cat)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: Subscription Cards

    private var subscriptionCards: some View {
        LazyVStack(spacing: 12) {
            ForEach(viewModel.filtered) { sub in
                SubscriptionCard(subscription: sub) {
                    Task { await viewModel.delete(sub) }
                }
            }
        }
    }

    // MARK: Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(Color(hex: "#6C5CE7"))
                .scaleEffect(1.2)
            Text("Загрузка...")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#55558A"))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#6C5CE7").opacity(0.1))
                    .frame(width: 72, height: 72)

                Image(systemName: "creditcard")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color(hex: "#6C5CE7").opacity(0.6))
            }

            VStack(spacing: 6) {
                Text("Нет подписок")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(hex: "#DDDDF5"))

                Text("Нажмите + чтобы добавить первую")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#55558A"))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: Tab Bar

    private var tabBar: some View {
        HStack(alignment: .center) {
            TabBarButton(iconName: "calendar", label: "Календарь") {
                // TODO: navigate to calendar
            }

            Spacer()

            AddButton {
                // TODO: open AddSubscriptionView sheet
            }

            Spacer()

            TabBarButton(iconName: "line.3.horizontal", label: "Меню") {
                viewModel.openMenu()
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)
        .padding(.bottom, 28)
        .background(
            Rectangle()
                .fill(Color(hex: "#0D0D18"))
                .overlay(
                    Rectangle()
                        .fill(Color(hex: "#1E1E35"))
                        .frame(height: 1),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - User Avatar

private struct UserAvatarView: View {
    let mode: StorageMode

    private var label: String {
        switch mode {
        case .local:      return "L"
        case .shared:     return ""
        case .selfHosted: return "S"
        }
    }

    private var accentColor: Color {
        switch mode {
        case .local:      return Color(hex: "#7C6EFF")
        case .shared:     return Color(hex: "#A29BFE")
        case .selfHosted: return Color(hex: "#2DD4BF")
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle().stroke(accentColor.opacity(0.3), lineWidth: 1)
                )

            if mode == .shared {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(accentColor)
            } else {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accentColor)
                    .kerning(-0.3)
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
                .foregroundColor(isSelected ? Color(hex: "#EEEEFF") : Color(hex: "#55558A"))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(hex: "#6C5CE7") : Color(hex: "#13131F"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isSelected ? Color.clear : Color(hex: "#2D2D45"),
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Subscription Card

private struct SubscriptionCard: View {
    let subscription: Subscription
    let onDelete: () -> Void
    @State private var isPressed = false

    private var daysUntilBilling: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: subscription.nextBillingDate).day ?? 0
    }

    private var billingLabel: String {
        switch daysUntilBilling {
        case 0:      return "сегодня"
        case 1:      return "завтра"
        case let d:  return "через \(d) дн."
        }
    }

    private var billingLabelColor: Color {
        switch daysUntilBilling {
        case 0...2:  return Color(hex: "#FF6B6B")
        case 3...5:  return Color(hex: "#FFB347")
        default:     return Color(hex: "#55558A")
        }
    }

    var body: some View {
        Button(action: {
            // TODO: navigate to subscription detail
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color(hex: subscription.color).opacity(0.15))
                        .frame(width: 48, height: 48)

                    Image(systemName: subscription.iconName)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: subscription.color))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(subscription.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#DDDDF5"))

                    Text(billingLabel)
                        .font(.system(size: 12))
                        .foregroundColor(billingLabelColor)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(subscription.currency) \(Int(subscription.price))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#DDDDF5"))

                    Text("/ \(subscription.billingPeriod.rawValue)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#44446A"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#13131F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color(hex: "#2D2D45"), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Tab Bar Buttons

private struct TabBarButton: View {
    let iconName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(Color(hex: "#55558A"))

                Text(label)
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#3A3A60"))
            }
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
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#6C5CE7"), Color(hex: "#8B7FF5")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(hex: "#6C5CE7").opacity(0.5), radius: 12, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Menu Sheet

struct MenuSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#0D0D18").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(hex: "#2D2D45"))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 28)

                Text("Меню")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(Color(hex: "#EEEEFF"))
                    .kerning(-0.5)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                VStack(spacing: 4) {
                    MenuRow(icon: "gear", label: "Настройки") {}
                    MenuRow(icon: "bell", label: "Уведомления") {}
                    MenuRow(icon: "arrow.triangle.2.circlepath", label: "Режим хранения") {}
                    MenuRow(icon: "questionmark.circle", label: "Помощь") {}
                }
                .padding(.horizontal, 16)

                Spacer()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(hex: "#0D0D18"))
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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: "#6C5CE7").opacity(0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#7C6EFF"))
                }

                Text(label)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(Color(hex: "#DDDDF5"))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "#44446A"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isPressed ? Color(hex: "#16162A") : Color.clear)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
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

// MARK: - Preview

#Preview {
    SubscriptionsView()
        .environmentObject(AppState())
}
