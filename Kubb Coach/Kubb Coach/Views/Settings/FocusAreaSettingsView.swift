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
            VStack(alignment: .leading, spacing: 24) {
                InlineNavHeader("One skill to chase, per phase.")

                SettingsCard {
                    ForEach(phases, id: \.self) { phase in
                        phaseRow(phase)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)
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
        // Only carry pcGameType for PC focus areas; clear it for everything else.
        let pcRaw: String? = (phase == .pressureCooker) ? draft.pcGameType?.rawValue : nil
        if let existing = preference(for: phase) {
            existing.selectedSkill = draft.skill.rawValue
            existing.targetValue = draft.hasTarget ? draft.targetValue : nil
            existing.isPinned = draft.isPinned
            existing.pcGameTypeRaw = pcRaw
        } else {
            let new = FocusAreaPreference(
                sessionTypeRaw: phase.rawValue,
                selectedSkill: draft.skill.rawValue,
                targetValue: draft.hasTarget ? draft.targetValue : nil,
                isPinned: draft.isPinned,
                pcGameTypeRaw: pcRaw
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func phaseRow(_ phase: TrainingPhase) -> some View {
        let pref = preference(for: phase)
        let color = phaseColor(phase)
        Button { editingPhase = phase } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                    phase.iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(color)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.displayName)
                        .font(KubbFont.inter(15, weight: .medium))
                        .tracking(-0.2)
                        .foregroundStyle(Color.Kubb.text)
                    skillCaption(for: pref)
                }

                Spacer(minLength: 8)

                if pref?.isPinned == true {
                    HStack(spacing: 4) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.Kubb.swedishGold)
                        Text("PINNED")
                            .font(KubbType.monoXS)
                            .tracking(KubbTracking.monoXS)
                            .foregroundStyle(Color.Kubb.swedishGold)
                    }
                }

                SettingsChevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func skillCaption(for pref: FocusAreaPreference?) -> some View {
        if let pref, let skill = pref.skill {
            HStack(spacing: 0) {
                if let pcGameType = pref.pcGameType, pref.sessionType == .pressureCooker {
                    Text(pcGameType.displayName.uppercased())
                    Text(" · ").foregroundStyle(Color.Kubb.textTer)
                }
                Text(skill.rawValue.uppercased())
                if let target = pref.targetValue {
                    Text(" · ").foregroundStyle(Color.Kubb.textTer)
                    Text(formatTarget(target, skill: skill))
                }
            }
            .font(KubbType.monoXS)
            .tracking(KubbTracking.monoXS)
            .foregroundStyle(Color.Kubb.textSec)
        } else {
            Text("NOT CONFIGURED")
                .font(KubbType.monoXS)
                .tracking(KubbTracking.monoXS)
                .foregroundStyle(Color.Kubb.textTer)
        }
    }

    private func phaseColor(_ phase: TrainingPhase) -> Color {
        switch phase {
        case .eightMeters:        return Color.Kubb.swedishBlue
        case .fourMetersBlasting: return Color.Kubb.phase4m
        case .inkastingDrilling:  return Color.Kubb.forestGreen
        case .pressureCooker:     return Color.Kubb.phasePC
        case .gameTracker:        return Color.Kubb.phaseGT
        }
    }

    private func formatTarget(_ value: Double, skill: FocusSkill) -> String {
        switch skill.unit {
        case "%":   return String(format: "%.0f%% TARGET", value)
        case "pts": return "\(Int(value))PT TARGET"
        default:    return "\(Int(value)) TARGET"
        }
    }
}

// MARK: - Draft model

struct FocusAreaDraft {
    var skill: FocusSkill
    var hasTarget: Bool
    var targetValue: Double
    var isPinned: Bool
    /// Only meaningful when the focus area's phase is `.pressureCooker`.
    /// Targets / averages are scoped to this sub-type because 3-4-3 and
    /// In the Red have different scoring scales.
    var pcGameType: PressureCookerGameType?
}

// MARK: - Edit sheet

struct FocusAreaEditSheet: View {
    let phase: TrainingPhase
    let existing: FocusAreaPreference?
    let onSave: (FocusAreaDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: FocusAreaDraft

    private var availableSkills: [FocusSkill] { FocusSkill.available(for: phase) }

    private var targetFooterText: String {
        let scopeNote: String = {
            guard phase == .pressureCooker, let gt = draft.pcGameType else { return "" }
            return " \(gt.displayName) sessions only."
        }()
        if draft.hasTarget {
            return "The Lodge header will show your last-5-session average vs this target.\(scopeNote)"
        }
        return "Without a target, the Lodge shows your lifetime average for this skill.\(scopeNote)"
    }

    init(phase: TrainingPhase, existing: FocusAreaPreference?, onSave: @escaping (FocusAreaDraft) -> Void) {
        self.phase = phase
        self.existing = existing
        self.onSave = onSave
        let defaultSkill = FocusSkill.available(for: phase).first ?? .accuracy
        // PC focus areas always carry a sub-type so the target is scoped to
        // one scoring scale. Default to 3-4-3 for new prefs or migrated rows
        // that predate this field.
        let defaultPCType: PressureCookerGameType? = (phase == .pressureCooker)
            ? (existing?.pcGameType ?? .threeForThree)
            : nil
        _draft = State(initialValue: FocusAreaDraft(
            skill: existing?.skill ?? defaultSkill,
            hasTarget: existing?.targetValue != nil,
            targetValue: existing?.targetValue ?? 80,
            isPinned: existing?.isPinned ?? false,
            pcGameType: defaultPCType
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                if phase == .pressureCooker {
                    Section {
                        Picker("Game type", selection: Binding(
                            get: { draft.pcGameType ?? .threeForThree },
                            set: { draft.pcGameType = $0 }
                        )) {
                            ForEach(PressureCookerGameType.allCases, id: \.self) { gt in
                                Text(gt.displayName).tag(gt)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Pressure Cooker Type")
                    } footer: {
                        Text("Each Pressure Cooker variant has its own scoring scale. The target you set here only applies to this sub-type.")
                    }
                }

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
                    Text(targetFooterText)
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
