// JourneyJournalSection.swift
// "Kubb Journal" sub-section inside the Journey tab. Surfaces every session
// that has non-empty notes, reverse-chronologically, with phase filter chips.

import SwiftUI

// MARK: - Journal entry

struct JournalEntry: Identifiable {
    let id: UUID
    let phase: KubbPhase
    let date: Date
    let noteText: String
    let ledgerRow: LedgerRow
}

// MARK: - Phase filter

enum JournalPhaseFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case eightMeter = "8m"
    case fourMeter = "4m"
    case inkasting = "Inkasting"
    case pressureCooker = "Pressure Cooker"

    var id: String { rawValue }

    func matches(_ phase: KubbPhase) -> Bool {
        switch self {
        case .all: return true
        case .eightMeter: return phase == .eightMeter
        case .fourMeter: return phase == .fourMeter
        case .inkasting: return phase == .inkasting
        case .pressureCooker:
            return phase == .pressureCooker
                || phase == .pressureCooker343
                || phase == .pressureCookerInTheRed
        }
    }
}

// MARK: - Journal section view

struct JourneyJournalSection: View {
    let entries: [JournalEntry]
    let onTap: (LedgerRow) -> Void
    @State private var filter: JournalPhaseFilter = .all

    private var visibleEntries: [JournalEntry] {
        entries
            .filter { filter.matches($0.phase) }
            .sorted { $0.date > $1.date }
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy · h:mm a"
        return f
    }

    var body: some View {
        VStack(spacing: KubbSpacing.m) {
            JourneyJournalHeader(num: "04",
                                 title: "Kubb Journal",
                                 sub: "\(visibleEntries.count) entr\(visibleEntries.count == 1 ? "y" : "ies")")
                .padding(.horizontal, KubbSpacing.l)
                .padding(.top, KubbSpacing.l)

            filterChips
                .padding(.horizontal, KubbSpacing.l)

            if visibleEntries.isEmpty {
                emptyState
                    .padding(.horizontal, KubbSpacing.l)
            } else {
                VStack(spacing: KubbSpacing.s) {
                    ForEach(visibleEntries) { entry in
                        Button { onTap(entry.ledgerRow) } label: {
                            JournalEntryCard(entry: entry, dateString: dateFormatter.string(from: entry.date))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, KubbSpacing.l)
            }
        }
        .padding(.bottom, 120)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KubbSpacing.xs) {
                ForEach(JournalPhaseFilter.allCases) { option in
                    Button { filter = option } label: {
                        Text(option.rawValue)
                            .font(KubbFont.inter(11, weight: .bold))
                            .tracking(0.3)
                            .padding(.horizontal, KubbSpacing.m)
                            .padding(.vertical, KubbSpacing.xs2)
                            .background(
                                filter == option
                                    ? Color.Kubb.swedishBlue
                                    : Color.Kubb.card
                            )
                            .foregroundStyle(
                                filter == option ? Color.white : Color.Kubb.text
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.Kubb.sep, lineWidth: filter == option ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: KubbSpacing.s) {
            Image(systemName: "book.closed")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Color.Kubb.textTer)
            Text(filter == .all
                 ? "No notes yet."
                 : "No \(filter.rawValue) notes yet.")
                .font(KubbType.body)
                .foregroundStyle(Color.Kubb.textSec)
            Text("Add a note to a session's recap or detail to see it here.")
                .font(KubbType.bodyS)
                .foregroundStyle(Color.Kubb.textTer)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KubbSpacing.xxl)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
    }
}

// MARK: - Section header (re-implemented locally — JourneyView's is private)

private struct JourneyJournalHeader: View {
    let num: String
    let title: String
    let sub: String

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: KubbSpacing.s) {
            Text(num)
                .font(KubbType.monoXS)
                .tracking(1.2)
                .foregroundStyle(Color.Kubb.swedishBlue)
            Text(title)
                .font(KubbFont.inter(13, weight: .bold))
                .foregroundStyle(Color.Kubb.text)
                .tracking(-0.2)
            Spacer()
            Text(sub)
                .font(KubbType.monoXS)
                .tracking(0.3)
                .foregroundStyle(Color.Kubb.textSec)
        }
    }
}

// MARK: - Entry card

private struct JournalEntryCard: View {
    let entry: JournalEntry
    let dateString: String

    var body: some View {
        HStack(alignment: .top, spacing: KubbSpacing.m) {
            entry.phase.glyph(size: 26)
                .foregroundStyle(Color.Kubb.phase(entry.phase))
                .frame(width: 40, height: 40)
                .background(Color.Kubb.phase(entry.phase).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.phase.fullName)
                        .font(KubbFont.inter(12, weight: .bold))
                        .foregroundStyle(Color.Kubb.text)
                    Spacer()
                    Text(dateString)
                        .font(KubbType.monoXS)
                        .tracking(0.3)
                        .foregroundStyle(Color.Kubb.textSec)
                }
                Text(entry.noteText)
                    .font(KubbType.bodyS)
                    .foregroundStyle(Color.Kubb.text)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(KubbSpacing.m2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml))
        .kubbCardShadow()
    }
}
