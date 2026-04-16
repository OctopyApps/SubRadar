//
//  SubscriptionFormView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 15.04.2026.
//

import SwiftUI
import PhotosUI

/// Общая форма для добавления и редактирования подписки.
/// Принимает конкретную ViewModel (Add или Edit) через протокол ObservableObject.
struct SubscriptionFormView<ViewModel: SubscriptionFormViewModel>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ViewModel

    let title: String
    let buttonLabel: String
    let onSave: () async -> Void

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        photoSection
                        requiredSection
                        paymentSection
                        categorySection
                        tagSection
                        urlSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    saveButton
                }
            }
        }
        .task { await viewModel.loadTags() }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { @MainActor in await viewModel.loadPhoto() }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { e in
            Text(e.localizedDescription)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(hex: "#55558A"))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(hex: "#13131F")))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(hex: "#EEEEFF"))
                .kerning(-0.3)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Photo

    private var photoSection: some View {
        PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#13131F"))
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .foregroundColor(Color(hex: "#2D2D45"))
                    )

                if let data = viewModel.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(Color(hex: "#44446A"))
                        Text("Добавить изображение")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#44446A"))
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Required

    private var requiredSection: some View {
        FormCard {
            FormField(label: "Название", isRequired: true) {
                TextField("Например: Netflix", text: $viewModel.name)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#EEEEFF"))
                    .tint(Color(hex: "#6C5CE7"))
            }
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        FormCard {
            FormField(label: "Сумма", isRequired: true) {
                TextField("0", text: $viewModel.price)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#EEEEFF"))
                    .tint(Color(hex: "#6C5CE7"))
                    .keyboardType(.decimalPad)
            }

            Divider().background(Color(hex: "#1E1E35"))

            FormField(label: "Валюта", isRequired: true) {
                HStack(spacing: 8) {
                    ForEach(Currency.allCases, id: \.self) { cur in
                        CurrencyChip(currency: cur, isSelected: viewModel.currency == cur) {
                            viewModel.currency = cur
                        }
                    }
                    Spacer()
                }
            }

            Divider().background(Color(hex: "#1E1E35"))

            FormField(label: "Периодичность", isRequired: true) {
                HStack(spacing: 8) {
                    ForEach(BillingPeriod.allCases, id: \.self) { period in
                        PeriodChip(period: period, isSelected: viewModel.billingPeriod == period) {
                            viewModel.billingPeriod = period
                        }
                    }
                    Spacer()
                }
            }

            Divider().background(Color(hex: "#1E1E35"))

            FormField(label: "Начало", isRequired: false) {
                DatePicker(
                    "",
                    selection: $viewModel.startDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .labelsHidden()
                .tint(Color(hex: "#6C5CE7"))
                .colorScheme(.dark)
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Категория")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SubscriptionCategory.allCases.filter { $0 != .all }, id: \.self) { cat in
                        CategoryChip(title: cat.rawValue, isSelected: viewModel.category == cat) {
                            viewModel.category = cat
                        }
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    // MARK: - Tag

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Тег")

            FormCard {
                FormField(label: "Введите тег", isRequired: false) {
                    TextField("Личное, Бизнес…", text: $viewModel.tagInput)
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#EEEEFF"))
                        .tint(Color(hex: "#6C5CE7"))
                        .onChange(of: viewModel.tagInput) { _, _ in
                            viewModel.selectedTag = nil
                        }
                }
            }

            if !viewModel.tagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.tagSuggestions) { tag in
                            TagSuggestionChip(name: tag.name) {
                                viewModel.selectTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }

            if viewModel.showCreateTagPrompt {
                Button(action: {
                    Task { await viewModel.createAndSelectTag() }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#6C5CE7"))
                        Text("Создать тег «\(viewModel.tagInput.trimmingCharacters(in: .whitespaces))»")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#6C5CE7"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#6C5CE7").opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#6C5CE7").opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            if let tag = viewModel.selectedTag {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#2DD4BF"))
                    Text("Тег: \(tag)")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#2DD4BF"))
                }
            }
        }
    }

    // MARK: - URL

    private var urlSection: some View {
        FormCard {
            FormField(label: "Ссылка", isRequired: false) {
                TextField("https://", text: $viewModel.url)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#EEEEFF"))
                    .tint(Color(hex: "#6C5CE7"))
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: {
            Task { await onSave() }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        viewModel.isValid
                        ? LinearGradient(
                            colors: [Color(hex: "#6C5CE7"), Color(hex: "#8B7FF5")],
                            startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(
                            colors: [Color(hex: "#2D2D45"), Color(hex: "#2D2D45")],
                            startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(height: 56)

                if viewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(viewModel.isValid ? .white : Color(hex: "#44446A"))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isValid || viewModel.isSaving)
        .padding(.horizontal, 20)
        .padding(.bottom, 36)
        .background(
            Rectangle()
                .fill(Color(hex: "#0A0A0F").opacity(0.95))
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

// MARK: - Form components

struct FormCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#13131F"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#2D2D45"), lineWidth: 1)
                    )
            )
    }
}

struct FormField<Content: View>: View {
    let label: String
    let isRequired: Bool
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#55558A"))
                if isRequired {
                    Text("*")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#6C5CE7"))
                }
            }
            .frame(width: 100, alignment: .leading)
            content
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(hex: "#55558A"))
            .padding(.leading, 4)
    }
}

struct CurrencyChip: View {
    let currency: Currency
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(currency.symbol) \(currency.rawValue)")
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(hex: "#EEEEFF") : Color(hex: "#55558A"))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "#6C5CE7") : Color(hex: "#1A1A2E"))
                )
        }
        .buttonStyle(.plain)
    }
}

struct PeriodChip: View {
    let period: BillingPeriod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(period.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(hex: "#EEEEFF") : Color(hex: "#55558A"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? Color(hex: "#6C5CE7") : Color(hex: "#1A1A2E"))
                )
        }
        .buttonStyle(.plain)
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Color(hex: "#EEEEFF") : Color(hex: "#55558A"))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(hex: "#6C5CE7") : Color(hex: "#13131F"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.clear : Color(hex: "#2D2D45"), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

struct TagSuggestionChip: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "tag.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#A29BFE"))
                Text(name)
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#A29BFE"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#A29BFE").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(hex: "#A29BFE").opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
