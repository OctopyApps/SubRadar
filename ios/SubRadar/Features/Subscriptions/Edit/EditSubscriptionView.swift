//
//  EditSubscriptionView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 15.04.2026.
//

import SwiftUI

struct EditSubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EditSubscriptionViewModel
    let onSaved: (Subscription) -> Void

    init(subscription: Subscription, storage: any StorageService, onSaved: @escaping (Subscription) -> Void) {
        _viewModel = StateObject(
            wrappedValue: EditSubscriptionViewModel(subscription: subscription, storage: storage)
        )
        self.onSaved = onSaved
    }

    var body: some View {
        SubscriptionFormView(
            viewModel: viewModel,
            title: "Редактировать",
            buttonLabel: "Сохранить изменения"
        ) {
            await viewModel.save(onSuccess: onSaved)
            if viewModel.error == nil { dismiss() }
        }
    }
}
