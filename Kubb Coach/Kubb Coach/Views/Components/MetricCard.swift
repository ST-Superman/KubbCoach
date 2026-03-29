//
//  MetricCard.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/24/26.
//  Extracted from StatisticsView.swift for reusability
//

import SwiftUI

// MARK: - Record Info Model

struct RecordInfo {
    let title: String
    let description: String
    let calculation: String
    var relatedSession: SessionDisplayItem? = nil
}

// MARK: - Metric Card Component

/// Reusable card component for displaying metrics with icon, value, and title
/// Used across Statistics, Inkasting Analysis, and other metric displays
struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var info: RecordInfo? = nil

    @State private var showingInfo = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                if info != nil {
                    Button {
                        showingInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More information about \(title)")
                    .accessibilityHint("Double tap to view details")
                }
            }
            .frame(height: info != nil ? 16 : 0)
            .padding(.horizontal, 8)

            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
        .sheet(isPresented: $showingInfo) {
            if let info = info {
                RecordInfoSheet(info: info)
            }
        }
    }
}

// MARK: - Record Info Sheet

struct RecordInfoSheet: View {
    let info: RecordInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What is this?")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(info.description)
                            .font(.body)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("How it's calculated")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Text(info.calculation)
                            .font(.body)
                    }

                    if let session = info.relatedSession {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("View this session")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            if let localSession = session.localSession {
                                NavigationLink {
                                    SessionDetailView(session: localSession)
                                } label: {
                                    SessionLinkCard(session: session)
                                }
                                .buttonStyle(.plain)
                            } else if let cloudSession = session.cloudSession {
                                NavigationLink {
                                    CloudSessionDetailView(session: cloudSession)
                                } label: {
                                    SessionLinkCard(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(info.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Session Link Card

struct SessionLinkCard: View {
    let session: SessionDisplayItem

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.createdAt, format: .dateTime.month().day().year())
                    .font(.headline)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                        Text("\(session.roundCount) rounds")
                            .font(.caption)
                    }

                    HStack(spacing: 4) {
                        Image(session.phase.icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(String(format: "%.1f%%", session.accuracy))
                            .font(.caption)
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview("Metric Card") {
    VStack(spacing: 16) {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "Cluster Area",
                value: "25.3 in²",
                icon: "circle.dotted",
                color: .blue
            )

            MetricCard(
                title: "Outliers",
                value: "2/5",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            )

            MetricCard(
                title: "Avg Distance",
                value: "8.5 in",
                icon: "arrow.left.and.right",
                color: .green
            )

            MetricCard(
                title: "Max Outlier",
                value: "15.2 in",
                icon: "arrow.up.right",
                color: .red,
                info: RecordInfo(
                    title: "Max Outlier Distance",
                    description: "The maximum distance of any outlier kubb from the cluster center.",
                    calculation: "Measured as the straight-line distance from the cluster center to the farthest outlier kubb."
                )
            )
        }
    }
    .padding()
    .background(Color(.systemGray6))
}
