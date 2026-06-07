// SupportService.swift
// Voluntary "Support Kubb Coach" tip-jar service. Wraps StoreKit 2 consumable
// purchases. Tips unlock NOTHING functional — the only side effect of a verified
// purchase is the `hasSupported` AppStorage flag, which suppresses the level-10
// prompt and lets the Settings row show a cosmetic "Supporter" treatment.
//
// Wired into the app environment as a `.shared` singleton (matches
// CloudKitSyncService). Views observe via `@Environment(SupportService.self)`.
//
// AppStorage keys (centralized here so views import nothing else):
//   - `support.hasSeenLevel10Prompt` — true after the level-10 sheet has been
//      shown once, regardless of whether the user tipped.
//   - `support.hasSupported`         — true after the first verified tip.
//
// Error/cancel/offline paths all complete silently — never alert the user.

import Foundation
import OSLog
import StoreKit

@MainActor
@Observable
final class SupportService {
    static let shared = SupportService()

    // MARK: - Product IDs (must match App Store Connect + .storekit config)

    static let smallTipID  = "ST-Superman.Kubb-Coach.tip.small"
    static let mediumTipID = "ST-Superman.Kubb-Coach.tip.medium"
    static let largeTipID  = "ST-Superman.Kubb-Coach.tip.large"
    static let xlargeTipID = "ST-Superman.Kubb-Coach.tip.xlarge"

    static let productIDs: [String] = [smallTipID, mediumTipID, largeTipID, xlargeTipID]

    // MARK: - AppStorage keys

    static let hasSeenLevel10PromptKey = "support.hasSeenLevel10Prompt"
    static let hasSupportedKey         = "support.hasSupported"

    // MARK: - Observable state

    /// Products loaded from the App Store, sorted by price ascending. Empty
    /// while loading or if loading failed.
    private(set) var products: [Product] = []

    /// True after `loadProducts()` finishes (regardless of outcome). The sheet
    /// uses this to differentiate "still loading" from "loaded but empty".
    private(set) var didAttemptLoad = false

    /// True if the most recent `loadProducts()` call returned zero products
    /// or threw. The sheet renders a calm "couldn't load right now" state.
    private(set) var loadFailed = false

    /// True while a purchase is in flight (between tap and `purchase()` return).
    /// The buttons debounce on this.
    private(set) var isPurchasing = false

    /// True when the most recent purchase returned `.pending` (Ask-to-Buy /
    /// parental approval). NOT a failure — the user is waiting.
    private(set) var awaitingApproval = false

    /// True after a successful verified purchase in this session. The sheet
    /// uses this to flip to the thank-you state. Reset on sheet close.
    private(set) var didPurchaseThisSession = false

    // MARK: - Internals

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.kubbcoach.app",
        category: "support"
    )
    private var updatesTask: Task<Void, Never>?

    private init() {
        listenForTransactionUpdates()
    }
    // No deinit: singleton lives for the app's lifetime, so the
    // `updatesTask` is never torn down.

    // MARK: - Persistent flags (read-only conveniences for non-View callers)

    var hasSupported: Bool {
        UserDefaults.standard.bool(forKey: Self.hasSupportedKey)
    }

    var hasSeenLevel10Prompt: Bool {
        UserDefaults.standard.bool(forKey: Self.hasSeenLevel10PromptKey)
    }

    // MARK: - Load products

    /// Fetches products from StoreKit. Safe to call multiple times — idempotent
    /// once products are loaded. Silent on failure (sets `loadFailed = true`).
    func loadProducts() async {
        guard products.isEmpty else { return }
        loadFailed = false
        do {
            let fetched = try await Product.products(for: Self.productIDs)
            products = fetched.sorted { $0.price < $1.price }
            loadFailed = products.isEmpty
            logger.info("Loaded \(self.products.count, privacy: .public) support products")
        } catch {
            loadFailed = true
            logger.error("Failed to load support products: \(error.localizedDescription, privacy: .public)")
        }
        didAttemptLoad = true
    }

    // MARK: - Purchase

    /// Initiate a tip purchase. Handles all StoreKit outcomes gracefully:
    /// success → flip `didPurchaseThisSession`, cancel → silent reset, pending
    /// → `awaitingApproval`, error → silent log + reset. Debounced on
    /// `isPurchasing` so double-taps are ignored.
    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        awaitingApproval = false
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    markSupported()
                    didPurchaseThisSession = true
                    logger.info("Verified tip purchased: \(product.id, privacy: .public)")
                case .unverified(_, let error):
                    // Treat as silent failure — don't credit user without verification.
                    logger.error("Unverified tip transaction: \(error.localizedDescription, privacy: .public)")
                }
            case .userCancelled:
                logger.info("User cancelled tip purchase")
            case .pending:
                awaitingApproval = true
                logger.info("Tip purchase pending Ask-to-Buy")
            @unknown default:
                logger.error("Unknown PurchaseResult case for \(product.id, privacy: .public)")
            }
        } catch {
            logger.error("Tip purchase failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reset transient sheet state. Call when the sheet is dismissed so the
    /// next open starts fresh (thank-you state doesn't persist across opens).
    func resetSheetState() {
        didPurchaseThisSession = false
        awaitingApproval = false
    }

    // MARK: - Transaction updates listener

    /// Listen for transactions that completed out-of-band (e.g. an Ask-to-Buy
    /// purchase approved by a parent after the user already dismissed the
    /// sheet). Finishes the transaction and flips the `hasSupported` flag.
    private func listenForTransactionUpdates() {
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await MainActor.run { [weak self] in
                    self?.markSupported()
                    self?.logger.info("Out-of-band tip transaction finished")
                }
            }
        }
    }

    // MARK: - Flag helpers

    private func markSupported() {
        UserDefaults.standard.set(true, forKey: Self.hasSupportedKey)
    }

    // MARK: - Debug helpers

    #if DEBUG
    /// Reset both AppStorage flags so the level-10 prompt can fire again and
    /// the Settings row drops back to its pre-tip styling. Used by
    /// DebugSettingsView for QA loops.
    static func debugResetFlags() {
        UserDefaults.standard.removeObject(forKey: hasSeenLevel10PromptKey)
        UserDefaults.standard.removeObject(forKey: hasSupportedKey)
    }
    #endif
}
