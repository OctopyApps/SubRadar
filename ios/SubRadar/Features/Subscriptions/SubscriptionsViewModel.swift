//
//  SubscriptionsViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 13.04.2026.
//

//
//  SubscriptionsViewModel.swift
//  SubRadar
//

import SwiftUI

@MainActor
final class SubscriptionsViewModel: ObservableObject {

    // MARK: - Published

    @Published var subscriptions: [Subscription] = []
    @Published var selectedCategory: AppCategory = .all
    @Published var isMenuOpen = false
    @Published var isAddingSubscription = false
    @Published var editingSubscription: Subscription? = nil
    @Published var isLoading = false
    @Published var error: StorageError?

    let storage: any StorageService

    init(storage: any StorageService) {
        self.storage = storage
    }

    // MARK: - Computed: filtering

    var filtered: [Subscription] {
        guard selectedCategory.id != AppCategory.all.id else { return subscriptions }
        return subscriptions.filter { $0.category.id == selectedCategory.id }
    }

    /// Только категории у которых есть хотя бы одна подписка
    func availableCategories(from appCategories: [AppCategory]) -> [AppCategory] {
        let usedIds = Set(subscriptions.map(\.category.id))
        let used = appCategories.filter { usedIds.contains($0.id) }
        return used.isEmpty ? appCategories : used
    }

    var isEmpty: Bool { !isLoading && subscriptions.isEmpty }

    // MARK: - Computed: totals per currency

    var activeCurrencyTotals: [(currency: AppCurrency, total: Double)] {
        var totals: [String: (AppCurrency, Double)] = [:]
        for sub in subscriptions {
            let code = sub.currency.code
            if let existing = totals[code] {
                totals[code] = (existing.0, existing.1 + sub.monthlyPrice)
            } else {
                totals[code] = (sub.currency, sub.monthlyPrice)
            }
        }
        return totals.values
            .filter { $0.1 > 0 }
            .sorted { $0.0.code < $1.0.code }
    }

    func formattedTotal(for currency: AppCurrency) -> String {
        guard let entry = activeCurrencyTotals.first(where: { $0.currency.code == currency.code }) else {
            return "\(currency.symbol) 0"
        }
        let total = entry.total
        if total >= 1000 {
            let thousands = total / 1000
            let fmt = String(
                format: thousands.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f",
                thousands
            )
            return "\(currency.symbol) \(fmt)к"
        }
        return "\(currency.symbol) \(Int(total))"
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

    func subscriptionAdded(_ subscription: Subscription) {
        subscriptions.insert(subscription, at: 0)
    }

    func delete(_ subscription: Subscription) async {
        subscriptions.removeAll { $0.id == subscription.id }
        do {
            try await storage.delete(subscription)
        } catch let e as StorageError {
            error = e
            await load()
        } catch {
            self.error = .saveFailed(underlying: error)
            await load()
        }
    }

    func selectCategory(_ category: AppCategory) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedCategory = category
        }
    }

    func subscriptionUpdated(_ subscription: Subscription) {
        if let idx = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[idx] = subscription
        }
    }

    func duplicate(_ subscription: Subscription) async {
        let copy = Subscription(
            name:            subscription.name + " (копия)",
            category:        subscription.category,
            price:           subscription.price,
            currency:        subscription.currency,
            billingPeriod:   subscription.billingPeriod,
            startDate:       subscription.startDate,
            nextBillingDate: subscription.nextBillingDate,
            tag:             subscription.tag,
            url:             subscription.url,
            imageData:       subscription.imageData
        )
        do {
            try await storage.save(copy)
            subscriptions.insert(copy, at: 0)
        } catch let e as StorageError { error = e
        } catch {}
    }

    func openEdit(_ subscription: Subscription) { editingSubscription = subscription }
    func openMenu() { isMenuOpen = true }
    func openAddSubscription() { isAddingSubscription = true }
}
