// MessagesRootView.swift
// Root of the Messages experience — presented as a sheet from the Lodge (bell +
// banner). Owns one NavigationStack + path so the inbox and threads share a stack,
// mirroring VirtualMatchesRootView. Gated on KubbPlatformService.isConnected: not
// connected → the "Connect your Kubb Platform account" prompt, not an empty inbox.
//
// i1: read + reply + in-match chat + announcements + block/report. No 4th tab —
// this is a modal surface reached from the Lodge.

import SwiftUI

/// Destinations pushed on the Messages nav stack.
enum MessageRoute: Hashable {
    case thread(conversationId: String)
}

struct MessagesRootView: View {
    @Environment(KubbPlatformService.self) private var platform
    @Environment(MessagingService.self) private var service
    @Environment(\.dismiss) private var dismiss

    @State private var path: [MessageRoute] = []

    /// When set (e.g. via a `kubbcoach://messages/{id}` deep link), open straight
    /// to this thread once connected.
    var initialConversationId: String?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if platform.isConnected {
                    ConversationListView(path: $path)
                } else {
                    connectPrompt
                }
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.Kubb.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: MessageRoute.self) { route in
                switch route {
                case .thread(let id):
                    MessageThreadView(conversationId: id)
                }
            }
        }
        .task {
            guard platform.isConnected else { return }
            await service.refreshAll()
            if let initialConversationId, path.isEmpty {
                path = [.thread(conversationId: initialConversationId)]
            }
        }
    }

    // MARK: - Not-connected gate

    private var connectPrompt: some View {
        VStack(spacing: 18) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Color.Kubb.matchAccent)
                .padding(.top, 24)
            Text("Connect your Kubb Platform account")
                .font(KubbFont.fraunces(24, weight: .semibold))
                .multilineTextAlignment(.center)
            Text("Messages live on Kubb Platform. Connect your account to chat with players you’ve played or challenged. It’s the same account you use on the website.")
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

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
            .padding(.horizontal, 24)
            Spacer()
        }
    }
}

// MARK: - Inbox list

struct ConversationListView: View {
    @Environment(MessagingService.self) private var service
    @Binding var path: [MessageRoute]

    var body: some View {
        Group {
            if service.conversations.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(service.conversations) { convo in
                        NavigationLink(value: MessageRoute.thread(conversationId: convo.conversationId)) {
                            ConversationRow(convo: convo)
                        }
                        .listRowBackground(Color.Kubb.card)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .refreshable { await service.listMyConversations() }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.Kubb.textTer)
            Text("No conversations yet")
                .font(.headline)
            Text("Message a player you’ve played or challenged from their profile on the website, or from an account match.")
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ConversationRow: View {
    let convo: ConversationSummary

    private var preview: String {
        guard let last = convo.lastMessage else { return "No messages yet" }
        return last.body ?? "Message removed"
    }

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatar(name: convo.displayTitle)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(convo.displayTitle)
                        .font(.system(size: 15, weight: convo.unread > 0 ? .bold : .semibold))
                        .lineLimit(1)
                    Spacer()
                    if let at = convo.lastAt {
                        Text(MessageTime.relative(at))
                            .font(.caption2)
                            .foregroundStyle(Color.Kubb.textTer)
                    }
                }
                HStack {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(convo.unread > 0 ? Color.Kubb.text : Color.Kubb.textSec)
                        .lineLimit(1)
                    Spacer()
                    if convo.unread > 0 {
                        Text("\(convo.unread)")
                            .font(KubbFont.mono(11, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.Kubb.matchAccent, in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Small initials circle used across the messaging UI.
struct InitialsAvatar: View {
    let name: String
    var size: CGFloat = 40

    private var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }

    var body: some View {
        Text(initials)
            .font(KubbFont.mono(size * 0.34, weight: .bold))
            .foregroundStyle(Color.Kubb.matchAccentInk)
            .frame(width: size, height: size)
            .background(Color.Kubb.matchAccent.opacity(0.16), in: Circle())
    }
}

/// Shared lightweight relative-time formatting for message timestamps.
enum MessageTime {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func date(_ s: String) -> Date? {
        iso.date(from: s) ?? isoPlain.date(from: s)
    }

    /// Time-of-day for today, weekday within a week, else a short date.
    static func relative(_ s: String) -> String {
        guard let d = date(s) else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            return d.formatted(date: .omitted, time: .shortened)
        }
        if let days = cal.dateComponents([.day], from: d, to: Date()).day, days < 7 {
            return d.formatted(.dateTime.weekday(.abbreviated))
        }
        return d.formatted(.dateTime.month(.abbreviated).day())
    }

    /// Clock time (h:mm) for a message bubble.
    static func clock(_ s: String) -> String {
        guard let d = date(s) else { return "" }
        return d.formatted(date: .omitted, time: .shortened)
    }
}
