//
//  URLSessionFactory.swift
//  SubRadar
//
//  Created by Алексей Розанов on 01.05.2026.
//

import Foundation

// MARK: - URLSessionFactory

enum URLSessionFactory {

    /// Стандартная сессия для общего сервера — HTTPS, ATS включён
    static let shared: URLSession = .shared

    /// Сессия для self-hosted — разрешает HTTP, нужна когда пользователь
    /// разворачивает бэкенд локально без SSL сертификата
    static let selfHosted: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        return URLSession(
            configuration: config,
            delegate: AllowHTTPDelegate.shared,
            delegateQueue: nil
        )
    }()

    /// Выбирает нужную сессию по режиму хранения
    static func session(for mode: StorageMode) -> URLSession {
        switch mode {
        case .selfHosted: return selfHosted
        case .shared, .local: return shared
        }
    }
}

// MARK: - AllowHTTPDelegate
// NSURLAuthenticationMethodServerTrust позволяет обойти ATS для HTTP.
// Используется ТОЛЬКО для self-hosted — пользователь осознанно выбрал свой сервер.

private final class AllowHTTPDelegate: NSObject, URLSessionDelegate {

    static let shared = AllowHTTPDelegate()

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // Принимаем self-signed сертификаты и HTTP для self-hosted серверов
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
