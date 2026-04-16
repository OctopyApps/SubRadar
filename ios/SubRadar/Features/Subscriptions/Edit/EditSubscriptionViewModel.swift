//
//  EditSubscriptionViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 15.04.2026.
//

import SwiftUI

@MainActor
final class EditSubscriptionViewModel: SubscriptionFormViewModel {

    private let original: Subscription

    init(subscription: Subscription, storage: any StorageService) {
        self.original = subscription
        super.init(storage: storage)

        // Заполняем форму текущими значениями
        name          = subscription.name
        price         = String(Int(subscription.price) == Int(subscription.price)
                            ? (subscription.price.truncatingRemainder(dividingBy: 1) == 0
                                ? String(format: "%.0f", subscription.price)
                                : String(subscription.price))
                            : String(subscription.price))
        currency      = subscription.currency
        billingPeriod = subscription.billingPeriod
        category      = subscription.category
        startDate     = subscription.startDate
        url           = subscription.url ?? ""
        imageData     = subscription.imageData
        if let tag = subscription.tag {
            tagInput     = tag
            selectedTag  = tag
        }
    }

    func save(onSuccess: @escaping (Subscription) -> Void) async {
        guard let price = parsedPrice else { return }
        isSaving = true
        error = nil

        let updated = Subscription(
            id:              original.id,      // сохраняем тот же id
            name:            name.trimmingCharacters(in: .whitespaces),
            category:        category,
            price:           price,
            currency:        currency,
            billingPeriod:   billingPeriod,
            startDate:       startDate,
            nextBillingDate: computeNextBillingDate(),
            tag:             finalTag,
            url:             finalUrl,
            imageData:       imageData
        )

        do {
            try await storage.update(updated)
            onSuccess(updated)
        } catch let e as StorageError { self.error = e
        } catch { self.error = .saveFailed(underlying: error) }

        isSaving = false
    }
}
