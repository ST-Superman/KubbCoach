// KubbPlatformAccountView.swift
// The Kubb Platform account screen in Settings: shows WHICH account is linked
// (avatar / display name / @handle / email / membership) so the user can tell
// which Kubb Portal account the app is using, and lets them Connect / Disconnect.
//
// Connect + disconnect both go through KubbPlatformService (ASWebAuthenticationSession
// for connect; signOut() clears the session, unregisters the push token, and resets
// messaging). Reads reactively from the shared service so the view flips between the
// connected card and the connect prompt automatically.

import SwiftUI

struct KubbPlatformAccountView: View {
    @Environment(KubbPlatformService.self) private var platform
    @State private var showDisconnectConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                InlineNavHeader("The Kubb Platform account this app is linked to for messages and online matches.")

                if platform.isConnected {
                    connectedCard
                    disconnectButton
                } else {
                    notConnected
                }

                if let err = platform.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Color.Kubb.miss)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Kubb Platform")
        .navigationBarTitleDisplayMode(.inline)
        .task { await platform.refresh() }
    }

    // MARK: - Connected

    private var connectedCard: some View {
        VStack(spacing: 14) {
            avatar
            VStack(spacing: 3) {
                Text(platform.accountProfile?.displayName ?? "Kubb Platform player")
                    .font(KubbFont.fraunces(24, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                    .multilineTextAlignment(.center)
                if let handle = platform.accountProfile?.handle {
                    Text("@\(handle)")
                        .font(KubbFont.mono(13, weight: .medium))
                        .foregroundStyle(Color.Kubb.matchAccentInk)
                }
                if let email = platform.accountEmail {
                    Text(email)
                        .font(KubbFont.inter(13))
                        .foregroundStyle(Color.Kubb.textSec)
                }
            }
            membershipPill
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.Kubb.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .kubbCardShadow()
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var avatar: some View {
        let initials = platform.accountProfile?.initials ?? "?"
        ZStack {
            Circle().fill(Color.Kubb.matchAccent.opacity(0.15))
            if let urlStr = platform.accountProfile?.avatarUrl,
               let url = URL(string: urlStr) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Text(initials)
                        .font(KubbFont.fraunces(28, weight: .semibold))
                        .foregroundStyle(Color.Kubb.matchAccent)
                }
                .clipShape(Circle())
            } else {
                Text(initials)
                    .font(KubbFont.fraunces(28, weight: .semibold))
                    .foregroundStyle(Color.Kubb.matchAccent)
            }
        }
        .frame(width: 76, height: 76)
    }

    private var membershipPill: some View {
        let (text, tint) = membershipStatus
        return Text(text)
            .font(KubbFont.mono(10, weight: .bold))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var membershipStatus: (String, Color) {
        if !platform.isEntitled { return ("No active membership", Color.Kubb.textSec) }
        if platform.isEntitledViaBeta { return ("Free during Beta", Color.Kubb.swedishGold) }
        if let exp = platform.expiresAt {
            return ("Member · until \(exp.formatted(date: .abbreviated, time: .omitted))",
                    Color.Kubb.forestGreen)
        }
        return ("Member", Color.Kubb.forestGreen)
    }

    private var disconnectButton: some View {
        Button(role: .destructive) {
            showDisconnectConfirm = true
        } label: {
            Text("Disconnect account")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.Kubb.miss)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.Kubb.miss.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.horizontal, 16)
        .confirmationDialog("Disconnect from Kubb Platform?",
                            isPresented: $showDisconnectConfirm, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                Task { await platform.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This device will stop receiving messages and match updates until you reconnect. Your account, matches, and history stay safe on Kubb Platform.")
        }
    }

    // MARK: - Not connected

    private var notConnected: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.Kubb.matchAccent)
                    .padding(.top, 12)
                Text("Not connected")
                    .font(KubbFont.fraunces(24, weight: .semibold))
                Text("Connect your Kubb Platform account to send messages and play online matches. It's the same account you use on the website.")
                    .font(.subheadline)
                    .foregroundStyle(Color.Kubb.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Button {
                Task { await platform.connect() }
            } label: {
                HStack(spacing: 8) {
                    if platform.isBusy { ProgressView().tint(.white) }
                    Text(platform.isBusy ? "Connecting…" : "Connect to Kubb Platform")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.Kubb.matchAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            }
            .disabled(platform.isBusy)
            .padding(.horizontal, 16)
        }
    }
}
