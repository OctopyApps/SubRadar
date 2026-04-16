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
    @Published var isAddingSubscription = false
    @Published var editingSubscription: Subscription? = nil
    @Published var isLoading = false
    @Published var error: StorageError?

    // MARK: - Storage (пробрасываем в AddSubscriptionView)

    let storage: any StorageService

    // MARK: - Init

    init(storage: any StorageService) {
        self.storage = storage
    }

    // MARK: - Computed: filtering

    var filtered: [Subscription] {
        guard selectedCategory != .all else { return subscriptions }
        return subscriptions.filter { $0.category == selectedCategory }
    }

    var availableCategories: [SubscriptionCategory] {
        let used = Set(subscriptions.map(\.category))
        return [.all] + SubscriptionCategory.allCases.filter { $0 != .all && used.contains($0) }
    }

    var isEmpty: Bool { !isLoading && subscriptions.isEmpty }

    // MARK: - Computed: totals per currency

    /// Суммы в месяц только по тем валютам у которых есть хотя бы одна подписка
    var activeCurrencyTotals: [(currency: Currency, total: Double)] {
        var totals: [Currency: Double] = [:]
        for sub in subscriptions {
            totals[sub.currency, default: 0] += sub.monthlyPrice
        }
        // Сортируем в порядке Currency.allCases для стабильного отображения
        return Currency.allCases
            .compactMap { cur -> (Currency, Double)? in
                guard let total = totals[cur], total > 0 else { return nil }
                return (cur, total)
            }
    }

    func formattedTotal(for currency: Currency) -> String {
        guard let entry = activeCurrencyTotals.first(where: { $0.currency == currency }) else {
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

    func selectCategory(_ category: SubscriptionCategory) {
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
        var copy = subscription
        copy = Subscription(
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
