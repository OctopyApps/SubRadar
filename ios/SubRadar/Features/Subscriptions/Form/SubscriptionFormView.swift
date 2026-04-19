//
//  SubscriptionFormView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 15.04.2026.
//

import SwiftUI
import PhotosUI

struct SubscriptionFormView<ViewModel: SubscriptionFormViewModel>: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ViewModel

    let title: String
    let buttonLabel: String
    let onSave: () async -> Void

    var body: some View {
        ZStack {
            Color.srBackground.ignoresSafeArea()
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
                .safeAreaInset(edge: .bottom, spacing: 0) { saveButton }
            }
        }
        .task { await viewModel.loadTags() }
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { @MainActor in await viewModel.loadPhoto() }
        }
        .alert("Ошибка", isPresented: .constant(viewModel.error != nil), presenting: viewModel.error) { _ in
            Button("OK") { viewModel.error = nil }
        } message: { e in Text(e.localizedDescription) }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.srTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.srSurface2))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.srTextPrimary)
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
                    .fill(Color.srSurface2)
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                            .foregroundColor(Color.srBorder)
                    )
                if let data = viewModel.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.srTextTertiary)
                        Text("Добавить изображение")
                            .font(.system(size: 13))
                            .foregroundColor(.srTextTertiary)
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
                    .foregroundColor(.srTextPrimary)
                    .tint(.srAccent)
            }
        }
    }

    // MARK: - Payment

    private var paymentSection: some View {
        FormCard {
            // СТАЛО
            VStack(alignment: .trailing, spacing: 0) {
                FormField(label: "Сумма", isRequired: true) {
                    TextField("0", text: $viewModel.price)
                        .font(.system(size: 16))
                        .foregroundColor(viewModel.isPriceInvalid ? .srDanger : .srTextPrimary)
                        .tint(.srAccent)
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.price) { _, new in
                            // Оставляем только цифры, одну точку и одну запятую
                            let filtered = new.filter { $0.isNumber || $0 == "." || $0 == "," }
                            if filtered != new { viewModel.price = filtered }
                        }
                }
                if viewModel.isPriceInvalid {
                    Text("Некорректная сумма")
                        .font(.system(size: 12))
                        .foregroundColor(.srDanger)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }
            }

            Divider().background(Color.srBorder)

            FormField(label: "Валюта", isRequired: true) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(appState.currencies) { cur in
                            CurrencyChip(
                                label: "\(cur.symbol) \(cur.code)",
                                isSelected: viewModel.currency.code == cur.code
                            ) { viewModel.currency = cur }
                        }
                    }
                }
            }

            Divider().background(Color.srBorder)

            FormField(label: "Период", isRequired: true) {
                HStack(spacing: 8) {
                    ForEach(BillingPeriod.allCases, id: \.self) { period in
                        PeriodChip(period: period, isSelected: viewModel.billingPeriod == period) {
                            viewModel.billingPeriod = period
                        }
                    }
                    Spacer()
                }
            }

            Divider().background(Color.srBorder)

            FormField(label: "Начало", isRequired: false) {
                DatePicker("", selection: $viewModel.startDate, in: ...Date(), displayedComponents: .date)
                    .labelsHidden()
                    .tint(.srAccent)
            }
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel("Категория")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.categories) { cat in
                        CategoryChip(title: cat.name, isSelected: viewModel.category.id == cat.id) {
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
                        .foregroundColor(.srTextPrimary)
                        .tint(.srAccent)
                        .onChange(of: viewModel.tagInput) { _, _ in viewModel.selectedTag = nil }
                }
            }
            if !viewModel.tagSuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.tagSuggestions) { tag in
                            TagSuggestionChip(name: tag.name) { viewModel.selectTag(tag) }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            if viewModel.showCreateTagPrompt {
                Button(action: { Task { await viewModel.createAndSelectTag() } }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 14)).foregroundColor(.srAccent)
                        Text("Создать тег «\(viewModel.tagInput.trimmingCharacters(in: .whitespaces))»")
                            .font(.system(size: 14)).foregroundColor(.srAccent)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12).fill(Color.srAccent.opacity(0.1))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.srAccent.opacity(0.3), lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
            if let tag = viewModel.selectedTag {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 13)).foregroundColor(.srTeal)
                    Text("Тег: \(tag)").font(.system(size: 13)).foregroundColor(.srTeal)
                }
            }
        }
    }

    // MARK: - URL

    private var urlSection: some View {
        FormCard {
            FormField(label: "Ссылка", isRequired: false) {
                TextField("https://", text: $viewModel.url)
                    .font(.system(size: 16)).foregroundColor(.srTextPrimary).tint(.srAccent)
                    .keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
            }
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button(action: { Task { await onSave() } }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient.srButtonGradient(isEnabled: viewModel.isValid))
                    .frame(height: 56)
                if viewModel.isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(buttonLabel)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(viewModel.isValid ? .white : .srTextTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.isValid || viewModel.isSaving)
        .padding(.horizontal, 20).padding(.bottom, 36)
        .background(Rectangle().fill(Color.srBackground.opacity(0.95)).ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Reusable form components

struct FormCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
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
                Text(label).font(.system(size: 14)).foregroundColor(.srTextSecondary)
                if isRequired { Text("*").font(.system(size: 14)).foregroundColor(.srAccent) }
            }
            .frame(width: 100, alignment: .leading)
            content
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 13, weight: .medium)).foregroundColor(.srTextSecondary).padding(.leading, 4)
    }
}

struct CurrencyChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .srTextSecondary)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.srAccent : Color.srSurface))
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
                .foregroundColor(isSelected ? .white : .srTextSecondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.srAccent : Color.srSurface))
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
                .foregroundColor(isSelected ? .white : .srTextSecondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20).fill(isSelected ? Color.srAccent : Color.srSurface2)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSelected ? Color.clear : Color.srBorder, lineWidth: 1))
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
                Image(systemName: "tag.fill").font(.system(size: 10)).foregroundColor(.srAccentLight)
                Text(name).font(.system(size: 13)).foregroundColor(.srAccentLight)
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10).fill(Color.srAccentLight.opacity(0.1))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.srAccentLight.opacity(0.25), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}
