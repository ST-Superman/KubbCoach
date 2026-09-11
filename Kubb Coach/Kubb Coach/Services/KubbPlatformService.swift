// KubbPlatformService.swift
// Owns the app's connection to the Kubb Platform account + membership entitlement.
//
// Connect flow (web-native, per VIRTUAL_MATCHES_PAYWALL_PLAN.md §6.2): open the
// platform's own sign-in page in an ASWebAuthenticationSession; on success the web
// hand-off page (/connect/app) redirects to `kubbcoach://auth-callback#access_token=…&
// refresh_token=…`, which we parse and hand to the SDK. The SDK persists the session in
// the Keychain and auto-refreshes it — the user stays connected until they sign out.
// We store tokens, never a password.
//
// Entitlement is read from the platform's `my_membership()` RPC, whose `entitled` flag is
// the SAME server-side gate the match write-path enforces (and honors the Beta window), so
// the app's gate never disagrees with what the server allows.

import Foundation
import Supabase
import AuthenticationServices
import OSLog

@MainActor
@Observable
final class KubbPlatformService {
    static let shared = KubbPlatformService()

    private let client = PlatformSupabaseConfig.client
    private let log = Logger(subsystem: "com.sathomps.kubbcoach", category: "KubbPlatform")
    private let presenter = WebAuthPresenter()
    private var authSession: ASWebAuthenticationSession?

    // MARK: - Observable state (drives the gate UI)
    private(set) var isConnected = false
    private(set) var isEntitled = false
    private(set) var expiresAt: Date?
    private(set) var betaFreeUntil: Date?
    private(set) var accountEmail: String?
    private(set) var isBusy = false
    var lastError: String?

    /// Entitled purely because the free Beta window is open (no purchased membership yet).
    var isEntitledViaBeta: Bool {
        guard isEntitled else { return false }
        if let expiresAt, expiresAt > Date() { return false }   // real membership
        return betaFreeUntil.map { $0 > Date() } ?? false
    }

    private init() {}

    // MARK: - Lifecycle

    /// Restore a persisted session on launch, then refresh entitlement.
    func restore() async {
        let session = try? await client.auth.session
        isConnected = (session != nil)
        accountEmail = session?.user.email
        if isConnected { await refresh() }
    }

    /// Present the platform web sign-in and persist the returned session.
    func connect() async {
        guard !isBusy else { return }
        isBusy = true
        lastError = nil
        defer { isBusy = false }

        do {
            let callbackURL = try await presentWebSignIn()
            try await establishSession(from: callbackURL)
            isConnected = true
            accountEmail = client.auth.currentUser?.email
            await refresh()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            // User dismissed the sheet — not an error worth surfacing.
            log.info("Connect cancelled by user")
        } catch {
            log.error("Connect failed: \(error.localizedDescription)")
            lastError = "Couldn’t connect to Kubb Platform. Please try again."
        }
    }

    /// Sign out of the platform account (there's no separate "disconnect"). Clears the
    /// session and re-locks virtual matches. The account + membership window persist on
    /// the platform.
    func signOut() async {
        try? await client.auth.signOut()
        isConnected = false
        isEntitled = false
        expiresAt = nil
        betaFreeUntil = nil
        accountEmail = nil
    }

    /// Re-read membership/entitlement. Safe to call on connect, on foreground, and after play.
    func refresh() async {
        guard isConnected else { return }
        do {
            let rows: [MembershipRow] = try await client
                .rpc("my_membership")
                .execute()
                .value
            let row = rows.first
            isEntitled = row?.entitled ?? false
            expiresAt = row?.expiresAtDate
            betaFreeUntil = row?.betaFreeUntilDate
        } catch {
            log.error("Membership refresh failed: \(error.localizedDescription)")
            // Leave prior state as-is; a transient failure shouldn't flip the gate.
        }
    }

    // MARK: - Web auth

    private func presentWebSignIn() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: PlatformSupabaseConfig.connectURL,
                callbackURLScheme: PlatformSupabaseConfig.callbackScheme
            ) { url, error in
                if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: error ?? PlatformAuthError.noCallback)
                }
            }
            session.presentationContextProvider = presenter
            // Reuse the platform's Safari cookies so an already-signed-in user connects
            // in one tap.
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            if !session.start() {
                continuation.resume(throwing: PlatformAuthError.couldNotStart)
            }
        }
    }

    /// Parse `access_token`/`refresh_token` from the callback fragment and establish the
    /// SDK session (which persists to the Keychain).
    private func establishSession(from url: URL) async throws {
        guard let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment else {
            throw PlatformAuthError.noTokens
        }
        var params: [String: String] = [:]
        for pair in fragment.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard kv.count == 2 else { continue }
            params[kv[0]] = kv[1].removingPercentEncoding ?? kv[1]
        }
        guard let accessToken = params["access_token"],
              let refreshToken = params["refresh_token"] else {
            throw PlatformAuthError.noTokens
        }
        try await client.auth.setSession(accessToken: accessToken, refreshToken: refreshToken)
    }
}

// MARK: - Supporting types

enum PlatformAuthError: LocalizedError {
    case couldNotStart, noCallback, noTokens
    var errorDescription: String? {
        switch self {
        case .couldNotStart: return "Couldn’t open the sign-in page."
        case .noCallback:    return "Sign-in didn’t return to the app."
        case .noTokens:      return "Sign-in didn’t include a session."
        }
    }
}

/// Row shape of the platform `my_membership()` RPC. Timestamps arrive as ISO-8601 strings
/// and are parsed leniently (with/without fractional seconds) to avoid decoder coupling.
struct MembershipRow: Decodable {
    let expiresAt: String?
    let entitled: Bool
    let betaFreeUntil: String?

    enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
        case entitled
        case betaFreeUntil = "beta_free_until"
    }

    var expiresAtDate: Date? { MembershipRow.parse(expiresAt) }
    var betaFreeUntilDate: Date? { MembershipRow.parse(betaFreeUntil) }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return isoFractional.date(from: s) ?? iso.date(from: s)
    }
}

/// Small NSObject that vends the presentation anchor for ASWebAuthenticationSession, so the
/// service itself needn't subclass NSObject.
final class WebAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
            return window ?? ASPresentationAnchor()
        }
    }
}
