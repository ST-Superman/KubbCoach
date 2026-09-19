// MessagingService.swift
// The app's client for Kubb Platform messaging (DMs, groups, in-match chat, and
// announcements). Sibling to KubbPlatformService + VirtualMatchService — all three
// talk to `PlatformSupabaseConfig.client` (the real-account project). Gated on
// `KubbPlatformService.shared.isConnected`: not connected → the UI shows the
// "Connect your Kubb Platform account" prompt, not an empty inbox.
//
// The SERVER is authoritative. Every read/write goes through a SECURITY DEFINER RPC
// keyed on auth.uid() — the SAME functions the web app calls — so there is no
// iOS-specific server code. Params are sent as [String: AnyJSON].
//
// i1 scope: read + reply + in-match chat + announcements + block/report. Live thread
// updates + the unread badge come from Realtime broadcast on `conv:<id>`; there is NO
// APNs remote push in i1 (deferred to i2).

import Foundation
import Supabase
import Realtime
import OSLog

@MainActor
@Observable
final class MessagingService {

    /// Shared instance — the Lodge bell/banner, inbox, and threads read one source
    /// of truth (same pattern as VirtualMatchService.shared), injected app-wide.
    static let shared = MessagingService()

    private let client = PlatformSupabaseConfig.client
    private let log = Logger(subsystem: "com.sathomps.kubbcoach", category: "Messaging")

    // MARK: - Observable state

    /// Inbox rows (`list_my_conversations`), newest activity first.
    var conversations: [ConversationSummary] = []

    /// Messages for the thread currently open (`conversation_messages`), oldest first.
    var threadMessages: [ThreadMessage] = []

    /// Published announcements the caller should see (`list_announcements`).
    var announcements: [Announcement] = []

    /// The caller's messaging preferences (`my_message_prefs`).
    var prefs: MessagePrefs?

    /// The caller's own players.id — used to align "me" vs "them" message bubbles.
    private(set) var myPlayerId: String?

    var isBusy = false
    var lastError: String?

    /// Deep-link intent (`kubbcoach://messages/{id}`): the Lodge observes these to
    /// present the inbox (and jump to a thread). Race-free vs. a transient notification.
    var wantsPresentInbox = false
    var pendingConversationId: String?

    /// Total unread across all conversations — drives the Lodge bell/banner badge.
    var unreadCount: Int {
        conversations.reduce(0) { $0 + $1.unread }
    }

    /// The most recent unread announcement, for the dismissible Lodge banner.
    var topUnreadAnnouncement: Announcement? {
        announcements.first { !($0.read ?? false) }
    }

    // MARK: - Aggregate refresh

    /// Load everything the Lodge + settings need (inbox, announcements, prefs, own
    /// player id). No-op when not connected. Safe on appear / foreground.
    func refreshAll() async {
        guard client.auth.currentUser != nil else { return }
        if myPlayerId == nil { await loadMyPlayerId() }
        await listMyConversations()
        await listAnnouncements()
    }

    /// Clear all state on disconnect so a signed-out user never sees stale data.
    func reset() {
        conversations = []
        threadMessages = []
        announcements = []
        prefs = nil
        myPlayerId = nil
        lastError = nil
    }

    // MARK: - Reads

    private func loadMyPlayerId() async {
        guard let uid = client.auth.currentUser?.id.uuidString.lowercased() else { return }
        do {
            let rows: [PlayerIdRow] = try await client
                .from("players").select("id").eq("user_id", value: uid).limit(1)
                .execute().value
            myPlayerId = rows.first?.id
        } catch {
            log.error("loadMyPlayerId failed: \(error.localizedDescription)")
        }
    }

    /// Refresh the inbox. Safe to call on appear.
    func listMyConversations() async {
        await run("listMyConversations") {
            self.conversations = try await self.client
                .rpc("list_my_conversations")
                .execute()
                .value
        }
    }

    /// Load a thread's messages (oldest first) into `threadMessages`.
    func conversationMessages(_ conversationId: String) async {
        await run("conversationMessages") {
            self.threadMessages = try await self.client
                .rpc("conversation_messages", params: ["p_conversation_id": AnyJSON.string(conversationId)])
                .execute()
                .value
        }
    }

    /// Published announcements (promo mute honored server-side), with read flags.
    func listAnnouncements() async {
        await run("listAnnouncements") {
            self.announcements = try await self.client
                .rpc("list_announcements")
                .execute()
                .value
        }
    }

    /// Read (and lazily provision) the caller's messaging prefs.
    func loadMessagePrefs() async {
        await run("myMessagePrefs") {
            self.prefs = try await self.client
                .rpc("my_message_prefs")
                .execute()
                .value
        }
    }

    // MARK: - Writes

    /// Send a message. Optimistically appends it (client-generated id = idempotency
    /// key, like turns), then reconciles from the server. Reverts on failure.
    func sendMessage(conversationId: String, body: String) async {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let clientId = UUID().uuidString
        let optimistic = ThreadMessage(
            id: clientId,
            senderPlayerId: myPlayerId ?? "",
            senderDisplayName: "You",
            senderHandle: nil,
            body: trimmed,
            deleted: false,
            createdAt: ISO8601DateFormatter().string(from: Date()))
        threadMessages.append(optimistic)

        let ok = await run("sendMessage") {
            _ = try await self.client
                .rpc("send_message", params: [
                    "p_conversation_id": AnyJSON.string(conversationId),
                    "p_body": AnyJSON.string(trimmed),
                    "p_client_id": AnyJSON.string(clientId),
                ])
                .execute()
        }
        if ok {
            await conversationMessages(conversationId)   // reconcile with canonical rows
        } else {
            threadMessages.removeAll { $0.id == clientId }  // revert optimistic
        }
    }

    /// Mark a conversation read (clears its unread contribution to the badge).
    func markRead(_ conversationId: String) async {
        _ = await run("markRead") {
            _ = try await self.client
                .rpc("mark_read", params: ["p_conversation_id": AnyJSON.string(conversationId)])
                .execute()
        }
        // Reflect locally so the badge updates without a full inbox refetch.
        if let i = conversations.firstIndex(where: { $0.conversationId == conversationId }) {
            conversations[i].unread = 0
        }
    }

    /// Block a player: their messages hide for the caller and their sends are refused.
    func blockPlayer(_ playerId: String) async -> Bool {
        await run("blockPlayer") {
            _ = try await self.client
                .rpc("block_player", params: ["p_player": AnyJSON.string(playerId)])
                .execute()
        }
    }

    /// Report a message to the admin moderation queue.
    func reportMessage(_ messageId: String, reason: String) async -> Bool {
        await run("reportMessage") {
            _ = try await self.client
                .rpc("report_message", params: [
                    "p_message_id": AnyJSON.string(messageId),
                    "p_reason": AnyJSON.string(reason),
                ])
                .execute()
        }
    }

    /// Mark an announcement read (dismiss the Lodge banner for it).
    func markAnnouncementRead(_ announcementId: String) async {
        _ = await run("markAnnouncementRead") {
            _ = try await self.client
                .rpc("mark_announcement_read", params: ["p_announcement_id": AnyJSON.string(announcementId)])
                .execute()
        }
        if let i = announcements.firstIndex(where: { $0.id == announcementId }) {
            announcements[i].read = true
        }
    }

    /// Update messaging prefs; only non-nil fields change (server coalesces the rest).
    @discardableResult
    func setMessagePrefs(
        dmPolicy: String? = nil,
        announcementPromo: Bool? = nil,
        dmEmailCadence: String? = nil,
        dmPush: Bool? = nil
    ) async -> Bool {
        var params: [String: AnyJSON] = [:]
        if let dmPolicy { params["p_dm_policy"] = .string(dmPolicy) }
        if let announcementPromo { params["p_announcement_promo"] = .bool(announcementPromo) }
        if let dmEmailCadence { params["p_dm_email_cadence"] = .string(dmEmailCadence) }
        if let dmPush { params["p_dm_push"] = .bool(dmPush) }
        return await run("setMessagePrefs") {
            self.prefs = try await self.client
                .rpc("set_message_prefs", params: params)
                .execute()
                .value
        }
    }

    /// Open (or fetch) the 1:1 DM with a player; returns the conversation id.
    /// Enforces `can_dm` server-side.
    func startOrGetDM(targetPlayerId: String) async -> String? {
        var conversationId: String?
        _ = await run("startOrGetDM") {
            let id: String = try await self.client
                .rpc("start_or_get_dm", params: ["p_target_player": AnyJSON.string(targetPlayerId)])
                .execute()
                .value
            conversationId = id
        }
        return conversationId
    }

    /// Open (or fetch) the match's chat conversation; returns its id. Participant-only.
    func startOrGetMatchConversation(matchId: String) async -> String? {
        var conversationId: String?
        _ = await run("startOrGetMatchConversation") {
            let id: String = try await self.client
                .rpc("start_or_get_match_conversation", params: ["p_match_id": AnyJSON.string(matchId)])
                .execute()
                .value
            conversationId = id
        }
        return conversationId
    }

    // MARK: - Remote push (APNs, i2)

    /// Register this device's APNs token with the platform so it can receive message
    /// push. Called from the AppDelegate token callback. No-op when not connected.
    func registerDeviceToken(_ token: String) async {
        guard client.auth.currentUser != nil else { return }
        _ = await run("registerDeviceToken") {
            _ = try await self.client
                .rpc("register_device_token", params: [
                    "p_token": AnyJSON.string(token),
                    "p_platform": AnyJSON.string("ios"),
                    // The app is entitled aps-environment=production; a debug build on a
                    // device may still mint a sandbox token — the server stores whatever we
                    // send and the sender picks the matching APNs host.
                    "p_environment": AnyJSON.string(Self.apnsEnvironment),
                ])
                .execute()
        }
    }

    /// Remove this device's token (on sign-out or when the user turns push off).
    func unregisterDeviceToken(_ token: String) async {
        _ = await run("unregisterDeviceToken") {
            _ = try await self.client
                .rpc("unregister_device_token", params: ["p_token": AnyJSON.string(token)])
                .execute()
        }
    }

    /// "sandbox" for Debug builds (Xcode-installed), "production" otherwise (TestFlight /
    /// App Store). The APNs token environment follows the build's provisioning.
    static var apnsEnvironment: String {
        #if DEBUG
        return "sandbox"
        #else
        return "production"
        #endif
    }

    // MARK: - Realtime (open thread)

    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var refetchTask: Task<Void, Never>?

    /// Subscribe to a conversation's broadcast topic `conv:<id>` (event `message`).
    /// Each inbound message schedules a debounced refetch of the thread + mark-read.
    /// Tears down any prior channel first (mirrors VirtualMatchService.subscribeToMatch).
    func subscribeToConversation(_ conversationId: String) async {
        await unsubscribe()
        let channel = client.channel("conv:\(conversationId)")
        realtimeChannel = channel
        let stream = channel.broadcastStream(event: "message")
        try? await channel.subscribeWithError()
        realtimeTask = Task { [weak self] in
            for await _ in stream {
                self?.scheduleRefetch(conversationId)
            }
        }
        log.info("Subscribed to conv:\(conversationId)")
    }

    private func scheduleRefetch(_ conversationId: String) {
        refetchTask?.cancel()
        refetchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await self?.conversationMessages(conversationId)
            await self?.markRead(conversationId)
        }
    }

    /// Stop live updates and remove the channel. Safe when not subscribed.
    func unsubscribe() async {
        realtimeTask?.cancel(); realtimeTask = nil
        refetchTask?.cancel(); refetchTask = nil
        if let channel = realtimeChannel {
            await client.removeChannel(channel)
            realtimeChannel = nil
        }
    }

    // MARK: - Error plumbing

    @discardableResult
    private func run(_ context: String, _ body: () async throws -> Void) async -> Bool {
        isBusy = true
        lastError = nil
        defer { isBusy = false }
        do {
            try await body()
            return true
        } catch {
            let raw = (error as? PostgrestError)?.message ?? error.localizedDescription
            log.error("\(context) failed: \(raw)")
            lastError = Self.friendlyMessage(for: raw)
            return false
        }
    }

    private static func friendlyMessage(for raw: String) -> String {
        switch raw {
        case "blocked":         return "You can’t message this player."
        case "rate_limited":    return "Slow down a moment — too many messages."
        case "dm_not_allowed":  return "You can only message players you’ve played or challenged."
        case "not_a_member":    return "You’re not part of this conversation."
        case "not_a_participant": return "Only players in this match can use match chat."
        case "body_range":      return "Message must be between 1 and 4000 characters."
        default:                return "Something went wrong. Please try again."
        }
    }
}

// MARK: - Models (shapes of the messaging RPC returns)

struct ConversationSummary: Decodable, Identifiable {
    let conversationId: String
    let type: String            // "dm" | "group" | "match"
    let title: String?
    let matchId: String?
    let muted: Bool
    let other: ConversationOther?
    let lastMessage: LastMessage?
    let lastAt: String?
    var unread: Int

    var id: String { conversationId }

    /// Display name for the inbox row.
    var displayTitle: String {
        switch type {
        case "dm":    return other?.displayName ?? "Player"
        case "match": return "Match chat"
        default:      return title ?? "Group"
        }
    }

    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case type, title, muted, other, unread
        case matchId = "match_id"
        case lastMessage = "last_message"
        case lastAt = "last_at"
    }
}

struct ConversationOther: Decodable {
    let playerId: String
    let displayName: String
    let handle: String?
    let avatarUrl: String?
    enum CodingKeys: String, CodingKey {
        case playerId = "player_id"
        case displayName = "display_name"
        case handle
        case avatarUrl = "avatar_url"
    }
}

struct LastMessage: Decodable {
    let body: String?           // nil when the last message was deleted
    let createdAt: String
    let senderPlayerId: String
    enum CodingKeys: String, CodingKey {
        case body
        case createdAt = "created_at"
        case senderPlayerId = "sender_player_id"
    }
}

struct ThreadMessage: Decodable, Identifiable {
    let id: String
    let senderPlayerId: String
    let senderDisplayName: String?
    let senderHandle: String?
    let body: String?           // nil when deleted
    let deleted: Bool
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, body, deleted
        case senderPlayerId = "sender_player_id"
        case senderDisplayName = "sender_display_name"
        case senderHandle = "sender_handle"
        case createdAt = "created_at"
    }
}

struct Announcement: Decodable, Identifiable {
    let id: String
    let title: String
    let body: String
    let severity: String        // "promo" | "critical"
    let publishedAt: String?
    var read: Bool?
    var isCritical: Bool { severity == "critical" }
    enum CodingKeys: String, CodingKey {
        case id, title, body, severity, read
        case publishedAt = "published_at"
    }
}

struct MessagePrefs: Decodable {
    let dmPolicy: String        // "eligible" | "none"
    let dmEmails: Bool
    let allowGroupAdd: Bool
    let announcementPromo: Bool
    let dmEmailCadence: String  // "in_app" | "daily" | "weekly"
    let dmPush: Bool            // APNs push for new messages
    enum CodingKeys: String, CodingKey {
        case dmPolicy = "dm_policy"
        case dmEmails = "dm_emails"
        case allowGroupAdd = "allow_group_add"
        case announcementPromo = "announcement_promo"
        case dmEmailCadence = "dm_email_cadence"
        case dmPush = "dm_push"
    }
}

private struct PlayerIdRow: Decodable { let id: String }
