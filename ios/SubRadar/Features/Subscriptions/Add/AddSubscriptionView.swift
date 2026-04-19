//
//  AddSubscriptionView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AddSubscriptionViewModel
    let onSaved: (Subscription) -> Void

    init(storage: any StorageService, onSaved: @escaping (Subscription) -> Void) {
        _viewModel = StateObject(wrappedValue: AddSubscriptionViewModel(storage: storage))
        self.onSaved = onSaved
    }

    var body: some View {
        SubscriptionFormView(
            viewModel: viewModel,
            title: "Новая подписка",
            buttonLabel: "Сохранить"
        ) {
            await viewModel.save(onSuccess: onSaved)
            if viewModel.error == nil { dismiss() }
        }
    }
}
