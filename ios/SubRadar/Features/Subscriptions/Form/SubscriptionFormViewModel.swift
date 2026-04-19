//
//  SubscriptionFormViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 15.04.2026.
//

import SwiftUI
import PhotosUI

@MainActor
class SubscriptionFormViewModel: ObservableObject {

    // MARK: - Form fields

    @Published var name: String = ""
    @Published var price: String = ""
    @Published var currency: AppCurrency = .rub
    @Published var billingPeriod: BillingPeriod = .monthly
    @Published var category: AppCategory = .other
    @Published var startDate: Date = Date()
    @Published var url: String = ""
    @Published var tagInput: String = ""
    @Published var selectedTag: String? = nil
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
        !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedPrice != nil
    }

    var parsedPrice: Double? {
        let trimmed = price.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        if let n = formatter.number(from: trimmed) { return n.doubleValue }
        // Fallback: принимаем "." как разделитель независимо от локали
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.number(from: trimmed)?.doubleValue
    }

    // MARK: - Storage

    let storage: any StorageService

    init(storage: any StorageService) {
        self.storage = storage
    }

    // MARK: - Intents

    func loadTags() async {
        do { allTags = try await storage.fetchTags() } catch {}
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
        } catch let e as StorageError { error = e
        } catch {}
        isCreatingNewTag = false
    }

    func loadPhoto() async {
        guard let item = selectedPhotoItem else { return }
        do { imageData = try await item.loadTransferable(type: Data.self) } catch {}
    }

    // MARK: - Helpers

    func computeNextBillingDate() -> Date {
        let cal = Calendar.current
        switch billingPeriod {
        case .monthly: return cal.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .yearly:  return cal.date(byAdding: .year,  value: 1, to: startDate) ?? startDate
        case .daily:   return cal.date(byAdding: .day,   value: 1, to: startDate) ?? startDate
        }
    }

    var finalTag: String? {
        selectedTag ?? (tagInput.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil : tagInput.trimmingCharacters(in: .whitespaces))
    }

    var finalUrl: String? {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }
}
