// SettingsPrimitives.swift
// Shared building blocks for the Settings surface:
//
//   - SettingsLargeTitle  — Fraunces 36 menu title with mono version eyebrow
//   - SettingsEyebrow     — mono-caps section header ("APP", "DEBUG TOOLS")
//   - SettingsCard        — rounded white card; auto-draws 0.5pt separators
//                            between direct child rows
//   - SettingsRow         — base row: 32×32 icon · label · detail · trailing
//   - SettingsNavRow      — convenience: SettingsRow ending in a chevron
//   - SettingsChevron     — the trailing chevron glyph
//   - SettingsToggle      — toggle with haptic feedback gated on user pref
//   - TrainingTile        — 2×2 grid tile face (icon · phase name · current
//                            value · mono meta)
//   - InlineNavHeader     — Fraunces italic intro line for inline subviews

import SwiftUI

// MARK: - SettingsLargeTitle

struct SettingsLargeTitle: View {
    let title: String
    let eyebrow: String?

    init(_ title: String, eyebrow: String? = nil) {
        self.title = title
        self.eyebrow = eyebrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow {
                Text(eyebrow)
                    .font(KubbType.monoXS)
                    .tracking(KubbTracking.monoXS)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.Kubb.textSec)
            }
            Text(title)
                .font(KubbFont.fraunces(36, weight: .medium))
                .tracking(-1.1)
                .foregroundStyle(Color.Kubb.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - SettingsEyebrow

struct SettingsEyebrow: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(KubbType.monoXS)
            .tracking(KubbTracking.monoXS)
            .textCase(.uppercase)
            .foregroundStyle(Color.Kubb.textSec)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

// MARK: - SettingsCard

/// Rounded white card that auto-draws a 0.5pt `Kubb.sep` separator between
/// each pair of direct children. Children are typically `SettingsRow` /
/// `SettingsNavRow` / `SettingsToggle`, but any view works.
struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        _VariadicView.Tree(SettingsCardLayout()) {
            content()
        }
    }
}

/// Uses `_VariadicView` (a non-public but long-stable SwiftUI API) to
/// inspect direct children so the card can drop a leading-inset separator
/// between every pair without the consumer having to add `Divider()` manually.
private struct SettingsCardLayout: _VariadicView_MultiViewRoot {
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        return VStack(spacing: 0) {
            ForEach(children) { child in
                child
                if child.id != last {
                    Rectangle()
                        .fill(Color.Kubb.sep)
                        .frame(height: 0.5)
                        .padding(.leading, 60)
                }
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
    }
}

// MARK: - SettingsRow

/// Base row primitive. Always: 32×32 tinted icon square · label · optional
/// detail · trailing view. The trailing slot is custom — pass a chevron, a
/// `Toggle`, a mono caption, or anything else.
struct SettingsRow<Trailing: View>: View {
    let icon: String
    let tint: Color
    let label: String
    let detail: String?
    let trailing: Trailing

    init(
        icon: String,
        tint: Color,
        label: String,
        detail: String? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.tint = tint
        self.label = label
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            Text(label)
                .font(KubbFont.inter(15, weight: .medium))
                .tracking(-0.2)
                .foregroundStyle(Color.Kubb.text)

            Spacer(minLength: 8)

            if let detail {
                Text(detail)
                    .font(KubbFont.inter(14))
                    .foregroundStyle(Color.Kubb.textSec)
                    .lineLimit(1)
            }

            trailing
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

// MARK: - SettingsNavRow

/// Convenience row for `NavigationLink` destinations — trailing chevron.
struct SettingsNavRow: View {
    let icon: String
    let tint: Color
    let label: String
    let detail: String?

    init(icon: String, tint: Color, label: String, detail: String? = nil) {
        self.icon = icon
        self.tint = tint
        self.label = label
        self.detail = detail
    }

    var body: some View {
        SettingsRow(icon: icon, tint: tint, label: label, detail: detail) {
            SettingsChevron()
        }
    }
}

// MARK: - SettingsChevron

struct SettingsChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color.Kubb.textTer)
    }
}

// MARK: - SettingsToggle

/// Row with a trailing `Toggle`. Fires a light selection haptic on flip,
/// gated by the global `hapticsEnabled` AppStorage key. Pass
/// `forcesHaptic: true` for the toggle that *controls* haptics so the user
/// always feels the change.
struct SettingsToggle: View {
    let icon: String
    let tint: Color
    let label: String
    let detail: String?
    @Binding var isOn: Bool
    var forcesHaptic: Bool = false

    init(
        icon: String,
        tint: Color,
        label: String,
        detail: String? = nil,
        isOn: Binding<Bool>,
        forcesHaptic: Bool = false
    ) {
        self.icon = icon
        self.tint = tint
        self.label = label
        self.detail = detail
        self._isOn = isOn
        self.forcesHaptic = forcesHaptic
    }

    var body: some View {
        SettingsRow(icon: icon, tint: tint, label: label, detail: detail) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(tint)
        }
        .onChange(of: isOn) { _, _ in
            #if os(iOS)
            HapticFeedbackService.shared.selection(force: forcesHaptic)
            #endif
        }
    }
}

// MARK: - TrainingTile

/// 2×2 grid tile face. Wrap this inside a `NavigationLink` to make it tap-
/// to-push. The tile shows its current setting as its value face.
struct TrainingTile: View {
    let title: String
    let value: String
    let meta: String
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(KubbFont.inter(13.5, weight: .semibold))
                    .foregroundStyle(Color.Kubb.text)
                Text(value)
                    .font(KubbFont.fraunces(20, weight: .medium))
                    .foregroundStyle(Color.Kubb.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(meta)
                    .font(KubbType.monoXS)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(tint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .kubbCardShadow()
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - InlineNavHeader

/// Fraunces italic intro line used inside subviews (Appearance, About, Focus
/// Area). Sits under the system inline nav-bar; not a replacement for it.
struct InlineNavHeader: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(KubbFont.fraunces(22, weight: .regular, italic: true))
            .tracking(-0.5)
            .foregroundStyle(Color.Kubb.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 12)
    }
}
