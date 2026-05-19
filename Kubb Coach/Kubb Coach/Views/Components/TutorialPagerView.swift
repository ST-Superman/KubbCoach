// TutorialPagerView.swift
// Reusable paged-tutorial sheet used by Pressure Cooker setup screens
// (and a natural fit for any future "how to play" sheet). Owns the
// NavigationStack, paged TabView, dot indicator, Primary CTA, and close
// link; callers supply the page list, theme, finish label, and a
// `onFinish` callback fired when the user advances past the last page.
//
// Visual language follows the Kubb design system: Fraunces italic 22
// titles, Inter 14 body copy, theme-accented icon tile, and the
// canonical midnight-navy Primary CTA recipe.

import SwiftUI

// MARK: - TutorialPage model

struct TutorialPage: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let body: String
    let details: [String]
    /// When `true`, `icon` is treated as an asset catalog name rendered via
    /// `Image(icon)` rather than an SF Symbol.
    let useCustomIcon: Bool

    init(
        icon: String,
        title: String,
        body: String,
        details: [String] = [],
        useCustomIcon: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.body = body
        self.details = details
        self.useCustomIcon = useCustomIcon
    }
}

// MARK: - TutorialPagerView

struct TutorialPagerView: View {
    let navTitle: String
    let pages: [TutorialPage]
    let theme: BriefingTheme
    let finishLabel: String
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        TutorialPageBody(page: page, theme: theme)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.2), value: currentPage)

                pageDots
                    .padding(.vertical, KubbSpacing.m)

                navigationButtons
                    .padding(.horizontal, KubbSpacing.xl2)
                    .padding(.bottom, KubbSpacing.xxl)
            }
            .background(Color.Kubb.paper.ignoresSafeArea())
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.Kubb.textTer)
                    }
                }
            }
        }
    }

    // MARK: - Dot indicator (size delta retained from the original 3-4-3 file)

    private var pageDots: some View {
        HStack(spacing: KubbSpacing.s) {
            ForEach(pages.indices, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? theme.accent : Color.Kubb.sep)
                    .frame(
                        width: index == currentPage ? 8 : 6,
                        height: index == currentPage ? 8 : 6
                    )
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Navigation buttons (Primary CTA + Close link)

    private var navigationButtons: some View {
        VStack(spacing: KubbSpacing.s2) {
            Button {
                if currentPage < pages.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    dismiss()
                    onFinish()
                }
            } label: {
                Text(currentPage < pages.count - 1 ? "NEXT" : finishLabel.uppercased())
                    .font(KubbFont.inter(13, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.Kubb.midnightNavy)
                    .clipShape(RoundedRectangle(cornerRadius: KubbRadius.l, style: .continuous))
                    .shadow(color: Color.Kubb.midnightNavy.opacity(0.22), radius: 10, y: 4)
            }
            .buttonStyle(.plain)

            Button {
                dismiss()
            } label: {
                Text("Close")
                    .font(KubbFont.inter(13, weight: .medium))
                    .foregroundStyle(Color.Kubb.textSec)
            }
        }
    }
}

// MARK: - Page body

private struct TutorialPageBody: View {
    let page: TutorialPage
    let theme: BriefingTheme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: KubbSpacing.xl2) {
                iconTile
                    .padding(.top, KubbSpacing.xl)

                VStack(spacing: KubbSpacing.s2) {
                    Text(page.title)
                        .font(KubbFont.fraunces(22, weight: .medium, italic: true))
                        .tracking(-0.4)
                        .foregroundStyle(Color.Kubb.text)
                        .multilineTextAlignment(.center)

                    Text(page.body)
                        .font(KubbFont.inter(14))
                        .foregroundStyle(Color.Kubb.textSec)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, KubbSpacing.xxl)
                }

                if !page.details.isEmpty {
                    detailList
                        .padding(.horizontal, KubbSpacing.l)
                }

                Spacer(minLength: KubbSpacing.xl)
            }
        }
    }

    @ViewBuilder
    private var iconTile: some View {
        ZStack {
            Circle()
                .fill(theme.accent.opacity(0.12))
                .frame(width: 88, height: 88)

            if page.useCustomIcon {
                Image(page.icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
            } else {
                Image(systemName: page.icon)
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
        }
    }

    private var detailList: some View {
        VStack(spacing: 0) {
            ForEach(Array(page.details.enumerated()), id: \.offset) { index, detail in
                HStack(alignment: .top, spacing: KubbSpacing.m) {
                    Text("•")
                        .font(KubbFont.inter(14, weight: .heavy))
                        .foregroundStyle(theme.accent)
                    Text(detail)
                        .font(KubbFont.inter(13))
                        .foregroundStyle(Color.Kubb.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, KubbSpacing.l)
                .padding(.vertical, KubbSpacing.s2)

                if index < page.details.count - 1 {
                    Rectangle()
                        .fill(Color.Kubb.sep)
                        .frame(height: 0.5)
                        .padding(.leading, KubbSpacing.l)
                }
            }
        }
        .background(Color.Kubb.card)
        .clipShape(RoundedRectangle(cornerRadius: KubbRadius.ml, style: .continuous))
        .kubbCardShadow()
    }
}

#Preview {
    TutorialPagerView(
        navTitle: "Tutorial",
        pages: [
            TutorialPage(
                icon: "rectangle.grid.2x2",
                title: "The Field Setup",
                body: "Set up a baseline and a midline 4 meters apart. Each line is 5 meters wide.",
                details: [
                    "Baseline: 5 m wide, 3 stakes",
                    "Midline: 5 m wide, 3 stakes",
                ]
            ),
            TutorialPage(
                icon: "star.fill",
                title: "Scoring",
                body: "Score 1 point per kubb knocked down. Bonus +1 per unused baton if all 10 are cleared."
            ),
        ],
        theme: .pressure,
        finishLabel: "Got it",
        onFinish: {}
    )
}
