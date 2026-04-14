//
//  AddSubscriptionViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 14.04.2026.
//

import SwiftUI
import PhotosUI

@MainActor
final class AddSubscriptionViewModel: ObservableObject {

    // MARK: - Form fields

    @Published var name: String = ""
    @Published var price: String = ""
    @Published var currency: Currency = .rub
    @Published var billingPeriod: BillingPeriod = .monthly
    @Published var category: SubscriptionCategory = .other
    @Published var url: String = ""
    @Published var tagInput: String = ""
    @Published var selectedTag: String? = nil

    // Фото
    @Published var startDate: Date = Date()
    @Published var selectedPhotoItem: PhotosPickerItem? = nil
    @Published var imageData: Data? = nil

    // MARK: - Tag autocomplete

    @Published var allTags: [Tag] = []
    @Published var isCreatingNewTag = false

    var tagSuggestions: [Tag] {
        let q = tagInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return allTags.filter { $0.name.lowercased().contains(q) }
    }

    var showCreateTagPrompt: Bool {
        let q = tagInput.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return false }
        return !allTags.contains(where: { $0.name.lowercased() == q.lowercased() })
    }

    // MARK: - State

    @Published var isSaving = false
    @Published var error: StorageError?

    // MARK: - Validation

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        parsedPrice != nil
    }

    var parsedPrice: Double? {
        let cleaned = price.replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    // MARK: - Private

    private let storage: any StorageService

    // MARK: - Init

    init(storage: any StorageService) {
        self.storage = storage
    }

    // MARK: - Intents

    func loadTags() async {
        do {
            allTags = try await storage.fetchTags()
        } catch {
            // некритично — автодополнение просто не работает
        }
    }

    func selectTag(_ tag: Tag) {
        selectedTag = tag.name
        tagInput = tag.name
    }

    func createAndSelectTag() async {
        let name = tagInput.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isCreatingNewTag = true
        do {
            let tag = try await storage.saveTagIfNeeded(name: name)
            allTags.append(tag)
            allTags.sort { $0.name < $1.name }
            selectedTag = tag.name
        } catch let e as StorageError {
            error = e
        } catch {}
        isCreatingNewTag = false
    }

    func loadPhoto() async {
        guard let item = selectedPhotoItem else { return }
        do {
            imageData = try await item.loadTransferable(type: Data.self)
        } catch {
            // фото не загрузилось — просто игнорируем
        }
    }

    func save(onSuccess: @escaping (Subscription) -> Void) async {
        guard let price = parsedPrice else { return }
        isSaving = true
        error = nil

        // Финальный тег — то что выбрано или введено
        let finalTag = selectedTag ?? (tagInput.trimmingCharacters(in: .whitespaces).isEmpty ? nil : tagInput.trimmingCharacters(in: .whitespaces))

        // Следующая дата списания = startDate + один период
        let nextBilling: Date
        let cal = Calendar.current
        switch billingPeriod {
        case .monthly: nextBilling = cal.date(byAdding: .month,  value: 1, to: startDate) ?? startDate
        case .yearly:  nextBilling = cal.date(byAdding: .year,   value: 1, to: startDate) ?? startDate
        case .daily:   nextBilling = cal.date(byAdding: .day,    value: 1, to: startDate) ?? startDate
        }

        let subscription = Subscription(
            name:            name.trimmingCharacters(in: .whitespaces),
            category:        category,
            price:           price,
            currency:        currency,
            billingPeriod:   billingPeriod,
            startDate:       startDate,
            nextBillingDate: nextBilling,
            tag:             finalTag,
            url:             url.trimmingCharacters(in: .whitespaces).isEmpty ? nil : url.trimmingCharacters(in: .whitespaces),
            imageData:       imageData
        )

        do {
            try await storage.save(subscription)
            onSuccess(subscription)
        } catch let e as StorageError {
            self.error = e
        } catch {
            self.error = .saveFailed(underlying: error)
        }
        isSaving = false
    }
}
