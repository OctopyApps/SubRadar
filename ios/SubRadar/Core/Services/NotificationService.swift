//
//  NotificationService.swift
//  SubRadar
//
//  Created by Алексей Розанов on 17.04.2026.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {

    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    func rescheduleAll(subscriptions: [Subscription], settings: NotificationSettings) async {
        center.removeAllPendingNotificationRequests()

        guard settings.isEnabled else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        for subscription in subscriptions {
            for leadTime in settings.leadTimes {
                await schedule(subscription: subscription, leadTime: leadTime, settings: settings)
            }
        }
    }

    private func schedule(
        subscription: Subscription,
        leadTime: NotificationLeadTime,
        settings: NotificationSettings
    ) async {
        guard let triggerDate = triggerDate(
            for: subscription.nextBillingDate,
            daysBefore: leadTime.daysBefore,
            hour: settings.notificationHour,
            minute: settings.notificationMinute
        ), triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Списание: \(subscription.name)"
        content.body = notificationBody(subscription: subscription, leadTime: leadTime)
        content.sound = .default

        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: triggerDate
        )
        components.second = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(subscription.id.uuidString)-\(leadTime.rawValue)",
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    // MARK: - Helpers

    private func triggerDate(for billingDate: Date, daysBefore: Int, hour: Int, minute: Int) -> Date? {
        let cal = Calendar.current
        guard let base = cal.date(byAdding: .day, value: -daysBefore, to: billingDate) else { return nil }
        var components = cal.dateComponents([.year, .month, .day], from: base)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return cal.date(from: components)
    }

    private func notificationBody(subscription: Subscription, leadTime: NotificationLeadTime) -> String {
        let amount = "\(subscription.currency.symbol) \(Int(subscription.price))"
        switch leadTime {
        case .sameDay:    return "Сегодня спишется \(amount) за \(subscription.name)"
        case .dayBefore:  return "Завтра спишется \(amount) за \(subscription.name)"
        case .threeDays:  return "Через 3 дня спишется \(amount) за \(subscription.name)"
        case .weekBefore: return "Через 7 дней спишется \(amount) за \(subscription.name)"
        }
    }
}
