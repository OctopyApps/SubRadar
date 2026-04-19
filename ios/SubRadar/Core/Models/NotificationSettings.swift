//
//  NotificationSettings.swift
//  SubRadar
//
//  Created by Алексей Розанов on 17.04.2026.
//

import Foundation

// MARK: - NotificationLeadTime

enum NotificationLeadTime: String, CaseIterable, Codable, Identifiable {
    case sameDay  = "same_day"
    case dayBefore = "day_before"
    case threeDays = "three_days"
    case weekBefore = "week_before"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sameDay:    return "В день списания"
        case .dayBefore:  return "За 1 день"
        case .threeDays:  return "За 3 дня"
        case .weekBefore: return "За 7 дней"
        }
    }

    var icon: String {
        switch self {
        case .sameDay:    return "bell.fill"
        case .dayBefore:  return "bell"
        case .threeDays:  return "calendar"
        case .weekBefore: return "calendar.badge.clock"
        }
    }

    /// Количество дней до списания
    var daysBefore: Int {
        switch self {
        case .sameDay:    return 0
        case .dayBefore:  return 1
        case .threeDays:  return 3
        case .weekBefore: return 7
        }
    }
}

// MARK: - NotificationSettings

struct NotificationSettings: Codable, Equatable {
    var isEnabled: Bool
    var leadTimes: Set<NotificationLeadTime>
    var notificationHour: Int    // 0–23
    var notificationMinute: Int  // 0–59

    static let `default` = NotificationSettings(
        isEnabled: false,
        leadTimes: [.dayBefore],
        notificationHour: 10,
        notificationMinute: 0
    )

    var timeDisplayString: String {
        String(format: "%02d:%02d", notificationHour, notificationMinute)
    }
}

// MARK: - Codable for Set<NotificationLeadTime>
// Set<Codable> уже поддерживается, но нужен Hashable

extension NotificationLeadTime: Hashable {}
