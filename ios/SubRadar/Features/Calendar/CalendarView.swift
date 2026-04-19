//
//  CalendarView.swift
//  SubRadar
//
//  Created by Алексей Розанов on 19.04.2026.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CalendarViewModel()
    @Environment(\.dismiss) private var dismiss

    private var storage: any StorageService {
        let config = UserDefaultsService.shared.configuration ?? .local()
        return StorageServiceFactory.make(for: config)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.srBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                periodPicker
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                navigationBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                Divider().background(Color.srBorder)

                if viewModel.isLoading {
                    Spacer()
                    ProgressView().tint(.srAccent)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            switch viewModel.periodMode {
                            case .week:  weekGrid
                            case .month: monthGrid
                            case .year:  yearGrid
                            }

                            Divider()
                                .background(Color.srBorder)
                                .padding(.vertical, 20)

                            paymentsList
                                .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .task {
            await viewModel.load(storage: storage)
        }
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
            Text("Календарь")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.srTextPrimary)
                .kerning(-0.3)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Period picker

    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(CalendarPeriodMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.periodMode = mode
                        viewModel.selectedDay = nil
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: viewModel.periodMode == mode ? .semibold : .regular))
                        .foregroundColor(viewModel.periodMode == mode ? .white : .srTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(viewModel.periodMode == mode ? Color.srAccent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.srSurface2)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.srBorder, lineWidth: 1))
        )
    }

    // MARK: - Navigation bar (← Апрель 2026 →)

    private var navigationBar: some View {
        HStack {
            Button(action: { withAnimation { viewModel.goBack() } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.srTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.srSurface2))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.periodTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.srTextPrimary)
                .kerning(-0.3)
                .animation(.none, value: viewModel.periodTitle)

            Spacer()

            Button(action: { withAnimation { viewModel.goForward() } }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.srTextSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.srSurface2))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Week grid

    private var weekGrid: some View {
        let cal = Calendar.current
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: viewModel.periodStart) }

        return HStack(spacing: 8) {
            ForEach(days, id: \.self) { day in
                DayCell(
                    day: day,
                    isSelected: viewModel.selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false,
                    isToday: cal.isDateInToday(day),
                    isInPeriod: true,
                    hasPayments: viewModel.daysWithPayments.contains(cal.dateComponents([.year, .month, .day], from: day))
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDay(day) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        let cal = Calendar.current
        let days = monthDays(for: viewModel.referenceDate, cal: cal)
        let monthStart = viewModel.periodStart
        let monthEnd = viewModel.periodEnd

        return VStack(spacing: 0) {
            // Заголовки дней недели
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.srTextTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .padding(.top, 16)

            // Сетка дней
            let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let inMonth = day >= monthStart && day < monthEnd
                    let hasPayments = inMonth && viewModel.daysWithPayments.contains(
                        cal.dateComponents([.year, .month, .day], from: day)
                    )
                    let isSelected = viewModel.selectedDay.map { cal.isDate($0, inSameDayAs: day) } ?? false

                    DayCell(
                        day: day,
                        isSelected: isSelected,
                        isToday: cal.isDateInToday(day),
                        isInPeriod: inMonth,
                        hasPayments: hasPayments
                    ) {
                        guard inMonth else { return }
                        withAnimation(.easeInOut(duration: 0.15)) { viewModel.toggleDay(day) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Year grid

    private var yearGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.paymentsByMonth, id: \.month) { item in
                MonthYearCell(month: item.month, paymentCount: item.count) {
                    withAnimation { viewModel.selectMonth(item.month) }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Payments list

    private var paymentsList: some View {
        let payments = viewModel.filteredPayments
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"

        return VStack(alignment: .leading, spacing: 16) {
            // Заголовок списка
            HStack(spacing: 6) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.srAccent)
                Text(listTitle.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.srTextSecondary)
                    .kerning(0.5)
                Spacer()
                if viewModel.selectedDay != nil {
                    Button(action: { withAnimation { viewModel.selectedDay = nil } }) {
                        Text("Сбросить")
                            .font(.system(size: 12))
                            .foregroundColor(.srAccent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if payments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundColor(.srTextTertiary)
                    Text("Нет оплат в этом периоде")
                        .font(.system(size: 14))
                        .foregroundColor(.srTextTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(payments.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().background(Color.srBorder).padding(.leading, 68)
                        }
                        PaymentRow(entry: entry)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 16).fill(Color.srSurface2)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.srBorder, lineWidth: 1))
                )
            }
        }
    }

    private var listTitle: String {
        if let day = viewModel.selectedDay {
            let f = DateFormatter()
            f.locale = Locale(identifier: "ru_RU")
            f.dateFormat = "d MMMM"
            return f.string(from: day)
        }
        return "Оплаты периода"
    }

    // MARK: - Helpers

    private var weekdayHeaders: [String] {
        let symbols = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
        return symbols
    }

    /// Возвращает все дни для сетки месяца (включая «хвосты» предыдущего и следующего)
    private func monthDays(for date: Date, cal: Calendar) -> [Date] {
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let weekday = cal.component(.weekday, from: monthStart) // 1=вс, 2=пн…
        // Смещение: делаем понедельник первым днём
        let offset = (weekday + 5) % 7
        let gridStart = cal.date(byAdding: .day, value: -offset, to: monthStart)!

        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: gridStart) }
    }
}

// MARK: - DayCell

private struct DayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let isInPeriod: Bool
    let hasPayments: Bool
    let action: () -> Void

    private var dayNumber: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: day)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.system(size: 15, weight: isSelected || isToday ? .semibold : .regular))
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.srAccent : (isToday ? Color.srAccent.opacity(0.15) : Color.clear))
                    )

                // Точка — есть платёж
                Circle()
                    .fill(isSelected ? Color.white : Color.srAccent)
                    .frame(width: 4, height: 4)
                    .opacity(hasPayments ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isInPeriod)
    }

    private var textColor: Color {
        if isSelected { return .white }
        if !isInPeriod { return .srTextTertiary }
        if isToday { return .srAccent }
        return .srTextPrimary
    }
}

// MARK: - MonthYearCell

private struct MonthYearCell: View {
    let month: Date
    let paymentCount: Int
    let action: () -> Void

    private var monthName: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL"
        return f.string(from: month).capitalized
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(monthName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.srTextPrimary)

                if paymentCount > 0 {
                    Text("\(paymentCount) оплат\(paymentCountSuffix)")
                        .font(.system(size: 12))
                        .foregroundColor(.srAccent)
                } else {
                    Text("нет оплат")
                        .font(.system(size: 12))
                        .foregroundColor(.srTextTertiary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.srSurface2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(paymentCount > 0 ? Color.srAccent.opacity(0.3) : Color.srBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var paymentCountSuffix: String {
        let n = paymentCount % 10
        let n100 = paymentCount % 100
        if n100 >= 11 && n100 <= 19 { return "" }
        switch n {
        case 1: return "а"
        case 2, 3, 4: return "и"
        default: return ""
        }
    }
}

// MARK: - PaymentRow

private struct PaymentRow: View {
    let entry: PaymentEntry

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Иконка
            ZStack {
                if let data = entry.subscription.imageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable().scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: entry.subscription.color).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.subscription.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: entry.subscription.color))
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.subscription.name)
                    .font(.system(size: 15))
                    .foregroundColor(.srTextPrimary)
                Text(dateString)
                    .font(.system(size: 12))
                    .foregroundColor(.srTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.subscription.currency.symbol) \(formatPrice(entry.subscription.price))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.srTextPrimary)
                Text(entry.subscription.billingPeriod.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(.srTextTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func formatPrice(_ price: Double) -> String {
        if price.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(price))
        }
        return String(format: "%.2f", price)
    }
}

#Preview {
    CalendarView().environmentObject(AppState())
}
