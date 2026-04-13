//
//  SubscriptionViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

@MainActor
final class SubscriptionsViewModel: ObservableObject {

    // MARK: Published

    @Published var subscriptions: [Subscription] = Subscription.mocks
    @Published var selectedCategory: SubscriptionCategory = .all
    @Published var isMenuOpen = false

    // MARK: Computed

    var filtered: [Subscription] {
        guard selectedCategory != .all else { return subscriptions }
        return subscriptions.filter { $0.category == selectedCategory }
    }

    var totalMonthly: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyPrice }
    }

    var formattedTotal: String {
        let total = totalMonthly
        if total >= 1000 {
            let thousands = total / 1000
            let fmt = String(
                format: thousands.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f",
                thousands
            )
            return "₽ \(fmt)к / мес"
        }
        return "₽ \(Int(total)) / мес"
    }

    /// Только категории с хотя бы одной подпиской + «Все» первым
    var availableCategories: [SubscriptionCategory] {
        let used = Set(subscriptions.map(\.category))
        return [.all] + SubscriptionCategory.allCases.filter { $0 != .all && used.contains($0) }
    }

    // MARK: Intents

    func selectCategory(_ category: SubscriptionCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedCategory = category
        }
    }

    func openMenu() {
        isMenuOpen = true
    }
}
