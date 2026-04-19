//
//  CalendarViewModel.swift
//  SubRadar
//
//  Created by Алексей Розанов on 19.04.2026.
//

import Foundation

// MARK: - Period mode

enum CalendarPeriodMode: String, CaseIterable {
    case week  = "Неделя"
    case month = "Месяц"
    case year  = "Год"
}

// MARK: - Payment entry (одна дата оплаты одной подписки)

struct PaymentEntry: Identifiable {
    let id = UUID()
    let subscription: Subscription
    let date: Date
}

// MARK: - ViewModel

@MainActor
final class CalendarViewModel: ObservableObject {

    // MARK: State

    @Published var periodMode: CalendarPeriodMode = .month
    @Published var referenceDate: Date = Date()       // «якорь» — любой день текущего периода
    @Published var selectedDay: Date? = nil           // выбранный день (nil = весь период)
    @Published var subscriptions: [Subscription] = []
    @Published var isLoading = false

    // MARK: - Computed: период

    var periodStart: Date {
        let cal = Calendar.current
        switch periodMode {
        case .week:
            return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate))!
        case .month:
            return cal.date(from: cal.dateComponents([.year, .month], from: referenceDate))!
        case .year:
            return cal.date(from: cal.dateComponents([.year], from: referenceDate))!
        }
    }

    var periodEnd: Date {
        let cal = Calendar.current
        switch periodMode {
        case .week:
            return cal.date(byAdding: .day, value: 7, to: periodStart)!
        case .month:
            return cal.date(byAdding: .month, value: 1, to: periodStart)!
        case .year:
            return cal.date(byAdding: .year, value: 1, to: periodStart)!
        }
    }

    // MARK: - Computed: навигация

    var periodTitle: String {
        let cal = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        switch periodMode {
        case .week:
            let end = cal.date(byAdding: .day, value: 6, to: periodStart)!
            formatter.dateFormat = "d MMM"
            let startStr = formatter.string(from: periodStart)
            formatter.dateFormat = "d MMM yyyy"
            let endStr = formatter.string(from: end)
            return "\(startStr) – \(endStr)"
        case .month:
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: referenceDate).capitalized
        case .year:
            formatter.dateFormat = "yyyy"
            return formatter.string(from: referenceDate)
        }
    }

    func goBack() {
        let cal = Calendar.current
        switch periodMode {
        case .week:  referenceDate = cal.date(byAdding: .weekOfYear, value: -1, to: referenceDate)!
        case .month: referenceDate = cal.date(byAdding: .month,      value: -1, to: referenceDate)!
        case .year:  referenceDate = cal.date(byAdding: .year,        value: -1, to: referenceDate)!
        }
        selectedDay = nil
    }

    func goForward() {
        let cal = Calendar.current
        switch periodMode {
        case .week:  referenceDate = cal.date(byAdding: .weekOfYear, value: 1, to: referenceDate)!
        case .month: referenceDate = cal.date(byAdding: .month,      value: 1, to: referenceDate)!
        case .year:  referenceDate = cal.date(byAdding: .year,       value: 1, to: referenceDate)!
        }
        selectedDay = nil
    }

    // MARK: - Payment entries

    /// Все даты оплат в текущем периоде
    var allPayments: [PaymentEntry] {
        subscriptions.flatMap { paymentDates(for: $0, in: periodStart..<periodEnd) }
            .sorted { $0.date < $1.date }
    }

    /// Даты оплат отфильтрованные по выбранному дню (или все если день не выбран)
    var filteredPayments: [PaymentEntry] {
        guard let day = selectedDay else { return allPayments }
        let cal = Calendar.current
        return allPayments.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    /// Дни в текущем периоде у которых есть хотя бы одна оплата
    var daysWithPayments: Set<DateComponents> {
        let cal = Calendar.current
        return Set(allPayments.map { cal.dateComponents([.year, .month, .day], from: $0.date) })
    }

    /// Для годового вида: сколько платежей в каждом месяце
    var paymentsByMonth: [(month: Date, count: Int)] {
        let cal = Calendar.current
        let year = cal.component(.year, from: referenceDate)
        return (1...12).compactMap { month -> (Date, Int)? in
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.day = 1
            guard let monthStart = cal.date(from: comps),
                  let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)
            else { return nil }
            let count = subscriptions
                .flatMap { paymentDates(for: $0, in: monthStart..<monthEnd) }
                .count
            return (monthStart, count)
        }
    }

    // MARK: - Select day

    func toggleDay(_ date: Date) {
        let cal = Calendar.current
        if let selected = selectedDay, cal.isDate(selected, inSameDayAs: date) {
            selectedDay = nil
        } else {
            selectedDay = date
        }
    }

    func selectMonth(_ date: Date) {
        referenceDate = date
        periodMode = .month
        selectedDay = nil
    }

    // MARK: - Load

    func load(storage: any StorageService) async {
        isLoading = true
        subscriptions = (try? await storage.fetchSubscriptions()) ?? []
        isLoading = false
    }

    // MARK: - Private: генерация дат оплат

    private func paymentDates(for sub: Subscription, in range: Range<Date>) -> [PaymentEntry] {
        var dates: [PaymentEntry] = []
        let cal = Calendar.current

        // Находим первую дату оплаты которая >= начала диапазона
        var current = sub.nextBillingDate

        // Если nextBillingDate уже позже конца периода — идём назад
        while current >= range.upperBound {
            current = stepBack(current, period: sub.billingPeriod, cal: cal)
        }

        // Если nextBillingDate раньше начала периода — идём вперёд
        while current < range.lowerBound {
            current = stepForward(current, period: sub.billingPeriod, cal: cal)
        }

        // Собираем все даты в диапазоне
        while current < range.upperBound {
            if current >= range.lowerBound {
                dates.append(PaymentEntry(subscription: sub, date: current))
            }
            let next = stepForward(current, period: sub.billingPeriod, cal: cal)
            // Защита от бесконечного цикла для дневных подписок
            guard next > current else { break }
            current = next
        }

        return dates
    }

    private func stepForward(_ date: Date, period: BillingPeriod, cal: Calendar) -> Date {
        switch period {
        case .monthly: return cal.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:  return cal.date(byAdding: .year,  value: 1, to: date) ?? date
        case .daily:   return cal.date(byAdding: .day,   value: 1, to: date) ?? date
        }
    }

    private func stepBack(_ date: Date, period: BillingPeriod, cal: Calendar) -> Date {
        switch period {
        case .monthly: return cal.date(byAdding: .month, value: -1, to: date) ?? date
        case .yearly:  return cal.date(byAdding: .year,  value: -1, to: date) ?? date
        case .daily:   return cal.date(byAdding: .day,   value: -1, to: date) ?? date
        }
    }
}
