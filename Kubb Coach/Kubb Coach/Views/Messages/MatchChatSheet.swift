// MatchChatSheet.swift
// In-match chat, presented as a sheet from MatchPlayView (account-vs-account matches
// only). Resolves the match's `type='match'` conversation via
// start_or_get_match_conversation, then hands off to the shared MessageThreadView —
// its own `conv:<id>` topic, separate from the match's `match:<id>` state topic.

import SwiftUI

struct MatchChatSheet: View {
    @Environment(MessagingService.self) private var service
    @Environment(\.dismiss) private var dismiss
    let matchId: String

    @State private var conversationId: String?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let conversationId {
                    MessageThreadView(conversationId: conversationId)
                } else if failed {
                    ContentUnavailableView("Couldn’t open match chat", systemImage: "bubble.left.and.bubble.right")
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            if let id = await service.startOrGetMatchConversation(matchId: matchId) {
                // Pull the conversation into the inbox list so the thread header can
                // label it "Match chat".
                await service.listMyConversations()
                conversationId = id
            } else {
                failed = true
            }
        }
    }
}
