// SupportSheet.swift
// The voluntary tip-jar sheet. Presented from the Settings row and from the
// one-time level-10 prompt. Buys NOTHING functional — see SupportService.swift.
//
// States:
//   - loading           — products haven't returned yet
//   - failed            — load returned zero or errored; calm placeholder
//   - tiers             — normal state: four buttons
//   - awaiting approval — Ask-to-Buy in flight
//   - thank-you         — after a successful tip in this session

import SwiftUI
import StoreKit

struct SupportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SupportService.self) private var support

    /// Source of the open. Drives the intro copy — the level-10 prompt gets a
    /// warmer, slightly longer message; the Settings entry gets the shorter one.
    enum Source {
        case settings
        case levelTenPrompt
    }

    let source: Source

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    body(for: source)
                    contentForState
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationTitle("Support Kubb Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.Kubb.text)
                }
            }
            .task {
                await support.loadProducts()
            }
            .onDisappear {
                support.resetSheetState()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.Kubb.swedishGold.opacity(0.14))
                    .frame(width: 72, height: 72)
                Image(systemName: "heart.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.Kubb.swedishGold)
            }
            Text("A small thank-you keeps the app moving.")
                .font(KubbFont.fraunces(20, weight: .medium, italic: true))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Intro copy

    @ViewBuilder
    private func body(for source: Source) -> some View {
        let text: String = {
            switch source {
            case .settings:
                return "Kubb Coach is free and always will be. If you'd like to chip in toward future updates, every tip helps — but nothing in the app changes either way."
            case .levelTenPrompt:
                return "I started this project as a way to learn how to develop an app and to track my Kubb progression. I genuinely love playing kubb and getting others excited about this game. That's why the app is free of charge and will never have a price. If you're willing to support Kubb Coach, I'd be very grateful — thanks for using the app, and for playing kubb. Hope to see you on the pitch one day."
            }
        }()
        Text(text)
            .font(KubbFont.inter(15))
            .foregroundStyle(Color.Kubb.textSec)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - State router

    @ViewBuilder
    private var contentForState: some View {
        if support.didPurchaseThisSession {
            thankYouState
        } else if support.awaitingApproval {
            awaitingApprovalState
        } else if !support.didAttemptLoad {
            loadingState
        } else if support.loadFailed || support.products.isEmpty {
            failedState
        } else {
            tierButtons
        }
    }

    // MARK: - Tier buttons

    private var tierButtons: some View {
        VStack(spacing: 10) {
            ForEach(support.products, id: \.id) { product in
                tierButton(for: product)
            }
        }
    }

    private func tierButton(for product: Product) -> some View {
        Button {
            Task { await support.purchase(product) }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.Kubb.swedishGold)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)

                Text(product.displayName)
                    .font(KubbFont.inter(15, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)

                Spacer(minLength: 8)

                Text(product.displayPrice)
                    .font(KubbFont.mono(14, weight: .bold))
                    .foregroundStyle(Color.Kubb.text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 56)
            .background(Color.Kubb.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .kubbCardShadow()
            .overlay {
                if support.isPurchasing {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.Kubb.paper.opacity(0.4))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(support.isPurchasing)
    }

    // MARK: - Other states

    private var loadingState: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Loading…")
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var failedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.Kubb.textSec)
            Text("Couldn't load tip options right now.")
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
            Button("Try again") {
                Task { await support.loadProducts() }
            }
            .font(KubbFont.mono(12, weight: .bold))
            .foregroundStyle(Color.Kubb.swedishBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var awaitingApprovalState: some View {
        VStack(spacing: 10) {
            Image(systemName: "hourglass")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.Kubb.swedishGold)
            Text("Waiting for approval")
                .font(KubbFont.fraunces(18, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
            Text("Your purchase is pending approval. We'll finish it up automatically when it's approved.")
                .font(KubbFont.inter(13))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var thankYouState: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.Kubb.swedishGold.opacity(0.18))
                    .frame(width: 72, height: 72)
                Image(systemName: "heart.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.Kubb.swedishGold)
            }
            Text("Thank you.")
                .font(KubbFont.fraunces(22, weight: .medium))
                .foregroundStyle(Color.Kubb.text)
            Text("It genuinely means a lot. Hope to see you on the pitch.")
                .font(KubbFont.inter(14))
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Done") { dismiss() }
                .font(KubbFont.mono(12, weight: .bold))
                .foregroundStyle(Color.Kubb.swedishBlue)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

#Preview {
    SupportSheet(source: .settings)
        .environment(SupportService.shared)
}
