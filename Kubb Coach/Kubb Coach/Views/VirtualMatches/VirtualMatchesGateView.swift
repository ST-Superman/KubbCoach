// VirtualMatchesGateView.swift
// The in-app entry point for Kubb Platform virtual matches. In B1 this is the
// connect + entitlement GATE; actual match play (Phase C1) slots in behind the
// unlocked state.
//
// Apple reader-app compliance (VIRTUAL_MATCHES_PAYWALL_PLAN.md §4): the app stays
// SILENT about buying — no price, no "Subscribe/Renew", no checkout link. It may
// show that the feature needs a membership, show current status once connected, and
// carry a single INFORMATIONAL link to the platform home page (not checkout).

import SwiftUI

struct VirtualMatchesGateView: View {
    @Environment(KubbPlatformService.self) private var platform

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()
    private func fmt(_ date: Date) -> String { Self.dateFormat.string(from: date) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                header

                if !platform.isConnected {
                    notConnected
                } else if !platform.isEntitled {
                    connectedNoMembership
                } else {
                    unlocked
                }

                if let err = platform.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Color.Kubb.miss)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 60)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Virtual Matches")
        .navigationBarTitleDisplayMode(.inline)
        .task { await platform.refresh() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.Kubb.swedishBlue)
                .padding(.top, 12)
            Text("Virtual Matches")
                .font(.system(.title, design: .serif).weight(.semibold))
            Text("Play scored 1v1 matches against other players online, through your Kubb Platform account.")
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
    }

    // MARK: - State: not connected

    private var notConnected: some View {
        VStack(spacing: 16) {
            infoCard(
                icon: "link",
                tint: Color.Kubb.swedishBlue,
                title: "Connect your Kubb Platform account",
                body: "Virtual matches live on Kubb Platform. Connect your account to play. It's the same account you use on the website."
            )

            connectButton(title: "Connect to Kubb Platform")

            Link(destination: URL(string: "https://kubbportal.com")!) {
                Text("About Kubb Platform")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.Kubb.swedishBlue)
            }
        }
    }

    // MARK: - State: connected, no active membership

    private var connectedNoMembership: some View {
        VStack(spacing: 16) {
            infoCard(
                icon: "lock.fill",
                tint: Color.Kubb.swedishGold,
                title: "No active membership",
                body: "This Kubb Platform account doesn't have an active membership, so virtual matches are locked."
            )
            if let email = platform.accountEmail {
                connectedFooter(email: email)
            }
        }
    }

    // MARK: - State: unlocked

    private var unlocked: some View {
        VStack(spacing: 16) {
            infoCard(
                icon: "checkmark.seal.fill",
                tint: Color.Kubb.forestGreen,
                title: platform.isEntitledViaBeta ? "You're in the Beta" : "Membership active",
                body: membershipStatusLine
            )

            // Phase C1 slots the match client in here.
            VStack(spacing: 8) {
                Image(systemName: "figure.disc.sports")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textSec)
                Text("Match play is coming soon")
                    .font(.headline)
                Text("Your account is ready. Creating and playing virtual matches lands in an upcoming update.")
                    .font(.footnote)
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .padding(.horizontal, 20)
            .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)

            if let email = platform.accountEmail {
                connectedFooter(email: email)
            }
        }
    }

    private var membershipStatusLine: String {
        if platform.isEntitledViaBeta {
            if let beta = platform.betaFreeUntil {
                return "Virtual matches are free for everyone during the Beta, through \(fmt(beta))."
            }
            return "Virtual matches are free for everyone during the Beta."
        }
        if let expires = platform.expiresAt {
            return "Membership active until \(fmt(expires))."
        }
        return "Your membership is active."
    }

    // MARK: - Pieces

    private func infoCard(icon: String, tint: Color, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(Color.Kubb.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
    }

    private func connectButton(title: String) -> some View {
        Button {
            Task { await platform.connect() }
        } label: {
            HStack(spacing: 8) {
                if platform.isBusy { ProgressView().tint(.white) }
                Text(platform.isBusy ? "Connecting…" : title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.Kubb.swedishBlue, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
        }
        .disabled(platform.isBusy)
        .padding(.horizontal, 16)
    }

    private func connectedFooter(email: String) -> some View {
        VStack(spacing: 10) {
            Text("Connected as \(email)")
                .font(.footnote)
                .foregroundStyle(Color.Kubb.textSec)
            Button(role: .destructive) {
                Task { await platform.signOut() }
            } label: {
                Text("Sign out of Kubb Platform")
                    .font(.footnote.weight(.semibold))
            }
        }
        .padding(.top, 4)
    }
}
