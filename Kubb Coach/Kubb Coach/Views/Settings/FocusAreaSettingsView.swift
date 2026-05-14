import SwiftUI
import SwiftData

struct FocusAreaSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPreferences: [FocusAreaPreference]
    @State private var editingPhase: TrainingPhase?

    private let phases: [TrainingPhase] = [
        .eightMeters, .fourMetersBlasting, .inkastingDrilling, .pressureCooker, .gameTracker
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KubbSpacing.l2) {
                Text("Choose a skill to focus on for each session type. Pin one to show it in the Lodge header.")
                    .font(KubbType.monoXS)
                    .foregroundStyle(Color.Kubb.textSec)
                    .tracking(KubbTracking.monoXS)
                    .padding(.horizontal, KubbSpacing.xs)

                VStack(alignment: .leading, spacing: KubbSpacing.xs2) {
                    Text("SESSION TYPES")
                        .font(KubbType.monoXS)
                        .foregroundStyle(Color.Kubb.textSec)
                        .tracking(KubbTracking.monoXS)
                        .padding(.horizontal, KubbSpacing.xs)

                    VStack(spacing: 0) {
                        ForEach(Array(phases.enumerated()), id: \.element) { idx, phase in
                            phaseRow(phase)
                            if idx < phases.count - 1 {
                                Color.Kubb.sep
                                    .frame(height: 0.5)
                                    .padding(.leading, 52)
                            }
                        }
                    }
                    .background(Color.Kubb.card)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
                    .kubbCardShadow()
                }
            }
            .padding(.horizontal, KubbSpacing.l)
            .padding(.top, KubbSpacing.l)
            .padding(.bottom, 100)
        }
        .background(Color.Kubb.paper.ignoresSafeArea())
        .navigationTitle("Focus Area")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingPhase) { phase in
            FocusAreaEditSheet(
                phase: phase,
                existing: preference(for: phase),
                onSave: { upsert($0, for: phase) }
            )
        }
    }

    private func preference(for phase: TrainingPhase) -> FocusAreaPreference? {
        allPreferences.first { $0.sessionTypeRaw == phase.rawValue }
    }

    private func upsert(_ draft: FocusAreaDraft, for phase: TrainingPhase) {
        // Unpin all others if this one is being pinned
        if draft.isPinned {
            for pref in allPreferences where pref.sessionTypeRaw != phase.rawValue {
                pref.isPinned = false
            }
        }
        if let existing = preference(for: phase) {
            existing.selectedSkill = draft.skill.rawValue
            existing.targetValue = draft.hasTarget ? draft.targetValue : nil
            existing.isPinned = draft.isPinned
        } else {
            let new = FocusAreaPreference(
                sessionTypeRaw: phase.rawValue,
                selectedSkill: draft.skill.rawValue,
                targetValue: draft.hasTarget ? draft.targetValue : nil,
                isPinned: draft.isPinned
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func phaseRow(_ phase: TrainingPhase) -> some View {
        Button { editingPhase = phase } label: {
            HStack(spacing: KubbSpacing.m) {
                ZStack {
                    RoundedRectangle(cornerRadius: KubbRadius.s)
                        .fill(phaseColor(phase))
                        .frame(width: 32, height: 32)
                    phase.iconImage
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.displayName)
                        .font(KubbType.body)
                        .foregroundStyle(Color.Kubb.text)
                    if let pref = preference(for: phase), let skill = pref.skill {
                        HStack(spacing: 4) {
                            Text(skill.rawValue)
                                .font(KubbFont.mono(10))
                                .foregroundStyle(Color.Kubb.textSec)
                            if let target = pref.targetValue {
                                Text("· \(formatTarget(target, skill: skill))")
                                    .font(KubbFont.mono(10))
                                    .foregroundStyle(Color.Kubb.textSec)
                            }
                        }
                    } else {
                        Text("Not configured")
                            .font(KubbFont.mono(10))
                            .foregroundStyle(Color.Kubb.textTer)
                    }
                }

                Spacer()

                if let pref = preference(for: phase), pref.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.Kubb.swedishGold)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.Kubb.textTer)
            }
            .padding(.horizontal, KubbSpacing.l)
            .padding(.vertical, KubbSpacing.m2)
        }
        .buttonStyle(.plain)
    }

    private func phaseColor(_ phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters:        return Color.Kubb.swedishBlue
        case .fourMetersBlasting: return Color.Kubb.phase4m
        case .inkastingDrilling:  return Color.Kubb.forestGreen
        case .pressureCooker:     return Color.Kubb.phasePC
        case .gameTracker:        return Color(hex: "7C6FA0")
        }
    }

    private func formatTarget(_ value: Double, skill: FocusSkill) -> String {
        switch skill.unit {
        case "%":   return String(format: "%.0f%% target", value)
        case "pts": return "\(Int(value))pt target"
        default:    return "\(Int(value)) target"
        }
    }
}

// MARK: - Draft model

struct FocusAreaDraft {
    var skill: FocusSkill
    var hasTarget: Bool
    var targetValue: Double
    var isPinned: Bool
}

// MARK: - Edit sheet

struct FocusAreaEditSheet: View {
    let phase: TrainingPhase
    let existing: FocusAreaPreference?
    let onSave: (FocusAreaDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: FocusAreaDraft

    private var availableSkills: [FocusSkill] { FocusSkill.available(for: phase) }

    init(phase: TrainingPhase, existing: FocusAreaPreference?, onSave: @escaping (FocusAreaDraft) -> Void) {
        self.phase = phase
        self.existing = existing
        self.onSave = onSave
        let defaultSkill = FocusSkill.available(for: phase).first ?? .accuracy
        _draft = State(initialValue: FocusAreaDraft(
            skill: existing?.skill ?? defaultSkill,
            hasTarget: existing?.targetValue != nil,
            targetValue: existing?.targetValue ?? 80,
            isPinned: existing?.isPinned ?? false
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Skill", selection: $draft.skill) {
                        ForEach(availableSkills, id: \.self) { skill in
                            Text(skill.rawValue).tag(skill)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Focus Skill")
                }

                Section {
                    Toggle("Set a target", isOn: $draft.hasTarget)
                    if draft.hasTarget {
                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("Value", value: $draft.targetValue, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text(draft.skill.unit.isEmpty ? "—" : draft.skill.unit)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .leading)
                        }
                    }
                } header: {
                    Text("Target")
                } footer: {
                    Text(draft.hasTarget
                        ? "The Lodge header will show your last-5-session average vs this target."
                        : "Without a target, the Lodge shows your lifetime average for this skill.")
                }

                Section {
                    Toggle("Pin to Lodge header", isOn: $draft.isPinned)
                } footer: {
                    Text("Only one focus area can be pinned at a time.")
                }
            }
            .navigationTitle(phase.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        FocusAreaSettingsView()
            .modelContainer(for: FocusAreaPreference.self, inMemory: true)
    }
}
