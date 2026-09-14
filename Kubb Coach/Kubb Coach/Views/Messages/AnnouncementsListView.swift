// AnnouncementsListView.swift
// The Lodge announcements list (read via list_announcements — promo mute honored
// server-side). Presented as a sheet from the announcement banner. Marks everything
// read on open so the banner + any indicator clear.

import SwiftUI

struct AnnouncementsListView: View {
    @Environment(MessagingService.self) private var service
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if service.announcements.isEmpty {
                    VStack(spacing: 8) {
                        Spacer()
                        Image(systemName: "megaphone")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.Kubb.textTer)
                        Text("No announcements")
                            .font(.headline)
                        Text("Nothing to share right now.")
                            .font(.subheadline)
                            .foregroundStyle(Color.Kubb.textSec)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(service.announcements) { announcement in
                            AnnouncementRow(announcement: announcement)
                                .listRowBackground(Color.Kubb.card)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationTitle("Announcements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await service.listAnnouncements()
            for announcement in service.announcements where !(announcement.read ?? false) {
                await service.markAnnouncementRead(announcement.id)
            }
        }
    }
}

private struct AnnouncementRow: View {
    let announcement: Announcement

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(announcement.isCritical ? "IMPORTANT" : "ANNOUNCEMENT")
                    .font(KubbFont.mono(9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(announcement.isCritical ? Color.Kubb.miss : Color.Kubb.textSec)
                Spacer()
                if let at = announcement.publishedAt {
                    Text(MessageTime.relative(at))
                        .font(.caption2)
                        .foregroundStyle(Color.Kubb.textTer)
                }
            }
            Text(announcement.title)
                .font(.headline)
            Text(announcement.body)
                .font(.subheadline)
                .foregroundStyle(Color.Kubb.textSec)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}
