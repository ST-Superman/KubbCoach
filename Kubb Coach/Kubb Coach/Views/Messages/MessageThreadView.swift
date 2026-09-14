// MessageThreadView.swift
// One conversation thread: bubbles (mine right / others left), a sticky composer via
// safeAreaInset(edge:.bottom) (like MatchPlayView's action bar), live updates over the
// `conv:<id>` broadcast, mark-read on open, and per-message block/report on others'
// messages. Server-authoritative — sends are optimistic then reconciled by the service.

import SwiftUI

struct MessageThreadView: View {
    @Environment(MessagingService.self) private var service
    let conversationId: String

    @State private var draft = ""
    @State private var reportTarget: ThreadMessage?
    @State private var reportReason = ""
    @State private var blockTarget: ThreadMessage?

    private var summary: ConversationSummary? {
        service.conversations.first { $0.conversationId == conversationId }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if service.threadMessages.isEmpty {
                        Text("No messages yet — say hello.")
                            .font(.subheadline)
                            .foregroundStyle(Color.Kubb.textSec)
                            .padding(.top, 40)
                    }
                    ForEach(service.threadMessages) { message in
                        MessageBubble(
                            message: message,
                            isMine: message.senderPlayerId == service.myPlayerId,
                            showSender: (summary?.type ?? "dm") != "dm",
                            onReport: { reportTarget = message; reportReason = "" },
                            onBlock: { blockTarget = message }
                        )
                        .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(bottomAnchor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .onChange(of: service.threadMessages.count) {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(bottomAnchor, anchor: .bottom)
                }
            }
            .onAppear { proxy.scrollTo(bottomAnchor, anchor: .bottom) }
        }
        .navigationTitle(summary?.displayTitle ?? "Messages")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { composer }
        .task {
            await service.conversationMessages(conversationId)
            await service.markRead(conversationId)
            await service.subscribeToConversation(conversationId)
        }
        .onDisappear {
            Task { await service.unsubscribe() }
        }
        // Report: a short reason, sent to the admin moderation queue.
        .alert("Report message", isPresented: reportPresented) {
            TextField("What’s wrong?", text: $reportReason)
            Button("Report", role: .destructive) {
                if let t = reportTarget {
                    Task { _ = await service.reportMessage(t.id, reason: reportReason) }
                }
                reportTarget = nil
            }
            Button("Cancel", role: .cancel) { reportTarget = nil }
        } message: {
            Text("Reports go to the Kubb Portal moderators.")
        }
        // Block: hide this sender's messages and refuse their sends.
        .confirmationDialog(
            blockTarget.map { "Block \($0.senderDisplayName ?? "this player")?" } ?? "Block player?",
            isPresented: blockPresented,
            titleVisibility: .visible
        ) {
            Button("Block", role: .destructive) {
                if let t = blockTarget {
                    Task {
                        if await service.blockPlayer(t.senderPlayerId) {
                            await service.conversationMessages(conversationId)
                        }
                    }
                }
                blockTarget = nil
            }
            Button("Cancel", role: .cancel) { blockTarget = nil }
        } message: {
            Text("You won’t see their messages, and they can’t message you.")
        }
    }

    private let bottomAnchor = "THREAD_BOTTOM"

    private var reportPresented: Binding<Bool> {
        Binding(get: { reportTarget != nil }, set: { if !$0 { reportTarget = nil } })
    }
    private var blockPresented: Binding<Bool> {
        Binding(get: { blockTarget != nil }, set: { if !$0 { blockTarget = nil } })
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.Kubb.paper2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                let body = draft
                draft = ""
                Task { await service.sendMessage(conversationId: conversationId, body: body) }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(canSend ? Color.Kubb.matchAccent : Color.Kubb.textTer)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct MessageBubble: View {
    let message: ThreadMessage
    let isMine: Bool
    let showSender: Bool
    let onReport: () -> Void
    let onBlock: () -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 2) {
                if showSender && !isMine {
                    Text(message.senderDisplayName ?? "Player")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.Kubb.textSec)
                }
                if message.deleted {
                    Text("Message removed")
                        .font(.subheadline).italic()
                        .foregroundStyle(isMine ? Color.white.opacity(0.7) : Color.Kubb.textTer)
                } else {
                    Text(message.body ?? "")
                        .font(.subheadline)
                        .foregroundStyle(isMine ? .white : Color.Kubb.text)
                }
                Text(MessageTime.clock(message.createdAt))
                    .font(.system(size: 10))
                    .foregroundStyle(isMine ? Color.white.opacity(0.7) : Color.Kubb.textTer)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isMine ? Color.Kubb.matchAccent : Color.Kubb.card,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .contextMenu {
                if !isMine {
                    Button { onReport() } label: { Label("Report message", systemImage: "flag") }
                    Button(role: .destructive) { onBlock() } label: { Label("Block sender", systemImage: "hand.raised") }
                }
            }
            if !isMine { Spacer(minLength: 40) }
        }
    }
}
