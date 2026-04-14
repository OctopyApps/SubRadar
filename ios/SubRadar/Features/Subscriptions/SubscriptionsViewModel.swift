//
//  SubscriptionsViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

import SwiftUI

@MainActor
final class SubscriptionsViewModel: ObservableObject {

    // MARK: - Published

    @Published var subscriptions: [Subscription] = []
    @Published var selectedCategory: SubscriptionCategory = .all
    @Published var isMenuOpen = false
    @Published var isLoading = false
    @Published var error: StorageError?

    // MARK: - Private

    private let storage: any StorageService

    // MARK: - Init

    init(storage: any StorageService) {
        self.storage = storage
    }

    // MARK: - Computed

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

    var isEmpty: Bool {
        !isLoading && subscriptions.isEmpty
    }

    // MARK: - Intents

    func load() async {
        isLoading = true
        error = nil
        do {
            subscriptions = try await storage.fetchSubscriptions()
        } catch let e as StorageError {
            error = e
        } catch {
            self.error = .fetchFailed(underlying: error)
        }
        isLoading = false
    }

    func add(_ subscription: Subscription) async {
        do {
            try await storage.save(subscription)
            await load()
        } catch let e as StorageError {
            error = e
        } catch {
            self.error = .saveFailed(underlying: error)
        }
    }

    func update(_ subscription: Subscription) async {
        do {
            try await storage.update(subscription)
            await load()
        } catch let e as StorageError {
            error = e
        } catch {
            self.error = .saveFailed(underlying: error)
        }
    }

    func delete(_ subscription: Subscription) async {
        // Оптимистичное удаление — убираем из UI сразу
        subscriptions.removeAll { $0.id == subscription.id }
        do {
            try await storage.delete(subscription)
        } catch let e as StorageError {
            error = e
            // Откатываем если не получилось
            await load()
        } catch {
            self.error = .saveFailed(underlying: error)
            await load()
        }
    }

    func selectCategory(_ category: SubscriptionCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedCategory = category
        }
    }

    func openMenu() {
        isMenuOpen = true
    }
}
