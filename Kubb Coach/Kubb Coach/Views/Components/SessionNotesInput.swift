//
//  SessionNotesInput.swift
//  Kubb Coach
//
//  Created by Claude Code on 3/23/26.
//

import SwiftUI

/// Input component for adding optional notes to a training session
struct SessionNotesInput: View {
    @Binding var notes: String
    @FocusState private var isFocused: Bool

    private let maxCharacters = 500

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Session Notes", systemImage: "note.text")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Optional")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))

                // Placeholder text
                if notes.isEmpty {
                    Text("Add notes about this session (e.g., weather conditions, how you felt, equipment used...)")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }

                // Text editor
                TextEditor(text: $notes)
                    .focused($isFocused)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(height: 100)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                    .onChange(of: notes) { _, newValue in
                        // Enforce character limit
                        if newValue.count > maxCharacters {
                            notes = String(newValue.prefix(maxCharacters))
                        }
                    }
            }
            .frame(height: 100)

            // Character count
            HStack {
                Spacer()
                Text("\(notes.count)/\(maxCharacters)")
                    .font(.caption)
                    .foregroundStyle(notes.count >= maxCharacters ? .red : .secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview("Empty") {
    SessionNotesInput(notes: .constant(""))
        .padding()
}

#Preview("With Text") {
    SessionNotesInput(notes: .constant("Great session today! Wind was strong but managed to maintain accuracy."))
        .padding()
}

#Preview("Near Limit") {
    SessionNotesInput(notes: .constant(String(repeating: "Testing character limit. ", count: 20)))
        .padding()
}
