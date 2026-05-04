//
//  AddSubscriptionViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import SwiftUI

@MainActor
final class AddSubscriptionViewModel: SubscriptionFormViewModel {

    func save(onSuccess: @escaping (Subscription) -> Void) async {
        guard let price = parsedPrice else { return }
        isSaving = true
        error = nil

        let subscription = Subscription(
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
            let saved = try await storage.save(subscription)
            onSuccess(saved)
        } catch let e as StorageError { self.error = e
        } catch { self.error = .saveFailed(underlying: error) }

        isSaving = false
    }
}
