//
//  ShareCardView.swift
//  Kubb Coach
//
//  "Magazine cover" share card. Fixed 1080×1350 logical canvas — caller
//  scales down for on-screen preview, then exports at native resolution
//  via `renderImage()`.
//
//  Layout: design_handoff_share_image/README.md (V5b)
//

import SwiftUI

struct ShareCardView: View {
    let data: ShareCardData

    var body: some View {
        VStack(spacing: 0) {
            mastheadBand
            paperBlock
            footerBand
        }
        .frame(width: ShareCard.canvasWidth, height: ShareCard.canvasHeight)
        .background(Color.Kubb.paper)
        .environment(\.colorScheme, .light)
    }

    // MARK: - Masthead

    private var mastheadBand: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Kubb Coach")
                    .font(KubbFont.fraunces(88, weight: .medium, italic: true))
                    .tracking(-3)
                    .foregroundStyle(Color.Kubb.cream)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("VOL · 26 / 05")
                        .font(KubbFont.mono(11, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Color.Kubb.cream.opacity(0.7))

                    Text(mastheadDate)
                        .font(KubbFont.mono(11, weight: .bold))
                        .tracking(2.4)
                        .foregroundStyle(Color.Kubb.cream.opacity(0.7))
                }
            }

            Rectangle()
                .fill(Color.Kubb.swedishGold.opacity(0.7))
                .frame(height: 1)
                .padding(.top, 18)

            HStack {
                Text(taglineString)
                    .font(KubbFont.mono(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Color.Kubb.swedishGold)

                Spacer()

                Text("$0.00")
                    .font(KubbFont.mono(11, weight: .bold))
                    .tracking(2.4)
                    .foregroundStyle(Color.Kubb.cream.opacity(0.7))
            }
            .padding(.top, 14)
        }
        .padding(.top, 40)
        .padding(.horizontal, 72)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .background(Color.Kubb.swedishBlue)
    }

    private var mastheadDate: String {
        data.date
            .formatted(.dateTime.month(.abbreviated).day().year())
            .uppercased()
    }

    private var taglineString: String {
        "· FIELD JOURNAL · ISSUE \(data.issueNumber) · \(data.taglineSegment) ·"
    }

    // MARK: - Paper feature block

    private var paperBlock: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(data.heroEyebrow)
                        .font(KubbFont.mono(14, weight: .bold))
                        .tracking(3)
                        .foregroundStyle(Color.Kubb.miss)

                    heroBlock

                    if let quote = data.pullQuote {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(quote.line1)
                            Text(quote.line2)
                        }
                        .font(KubbFont.fraunces(40, weight: .medium, italic: true))
                        .lineSpacing(4)
                        .foregroundStyle(Color.Kubb.text)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 14) {
                    Image("coach4kubb")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 340, height: 340)

                    Text("· COACH ·")
                        .font(KubbFont.mono(11, weight: .bold))
                        .tracking(2.6)
                        .foregroundStyle(Color.Kubb.textSec)
                }
                .padding(.top, 30)
                .frame(width: 340)
            }

            Rectangle()
                .fill(Color.Kubb.text.opacity(0.13))
                .frame(height: 1.5)
                .padding(.top, 28)

            statRow
                .padding(.top, 28)

            Spacer(minLength: 0)
        }
        .padding(.top, 52)
        .padding(.horizontal, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Kubb.paper)
    }

    // MARK: - Hero block

    @ViewBuilder
    private var heroBlock: some View {
        switch data.hero {
        case .bigDecimalPercent(let value):
            decimalPercentHero(value: value)
        case .signedInt(let value):
            signedIntHero(value: value)
        case .measurement(let valueString, let unit):
            measurementHero(value: valueString, unit: unit)
        }
    }

    private func decimalPercentHero(value: Double) -> some View {
        let display = formatPercentValue(value)
        let intPart = display.prefix(while: { $0 != "." })
        let isThreeDigit = intPart.count >= 3
        let bigSize = isThreeDigit
            ? ShareCard.heroBigFontThreeDigit
            : ShareCard.heroBigFontDefault
        let tracking: CGFloat = -bigSize * 0.045

        return HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(display)
                .font(KubbFont.fraunces(bigSize, weight: .medium, italic: true))
                .tracking(tracking)
                .monospacedDigit()
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: true, vertical: false)

            Text("%")
                .font(KubbFont.fraunces(ShareCard.heroPercentSuffix, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func signedIntHero(value: Int) -> some View {
        let prefix: String = value > 0 ? "+" : (value < 0 ? "−" : "")
        let display = "\(prefix)\(abs(value))"
        let bigSize = ShareCard.heroSignedIntSize
        let tracking: CGFloat = -bigSize * 0.045

        return HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(display)
                .font(KubbFont.fraunces(bigSize, weight: .medium, italic: true))
                .tracking(tracking)
                .monospacedDigit()
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: true, vertical: false)

            Text("pts")
                .font(KubbFont.fraunces(ShareCard.heroSignedIntSuffix, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func measurementHero(value: String, unit: String) -> some View {
        let bigSize = ShareCard.heroMeasurementSize
        return HStack(alignment: .lastTextBaseline, spacing: 8) {
            Text(value)
                .font(KubbFont.fraunces(bigSize, weight: .medium, italic: true))
                .tracking(-bigSize * 0.045)
                .monospacedDigit()
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: true, vertical: false)

            Text(unit)
                .font(KubbFont.fraunces(ShareCard.heroMeasurementUnit, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.text)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Decimal percent display, e.g. 46.7 → "46.7", 50.0 → "50", 100.0 → "100".
    private func formatPercentValue(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    // MARK: - Stat row

    private var statRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(data.statCells.enumerated()), id: \.offset) { idx, cell in
                statCellView(cell, showLeftBorder: idx > 0)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func statCellView(_ cell: ShareCardStatCell, showLeftBorder: Bool) -> some View {
        HStack(spacing: 0) {
            if showLeftBorder {
                Rectangle()
                    .fill(Color.Kubb.text.opacity(0.12))
                    .frame(width: 1)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(cell.dotColor)
                        .frame(width: 8, height: 8)

                    Text(cell.label)
                        .font(KubbFont.mono(12, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(Color.Kubb.textSec)
                        .lineLimit(1)
                }

                statCellValue(cell)
            }
            .padding(.leading, showLeftBorder ? 22 : 0)
            .padding(.trailing, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func statCellValue(_ cell: ShareCardStatCell) -> some View {
        let size = cell.value.count >= ShareCard.statNumberLongThreshold
            ? ShareCard.statNumberFontLong
            : ShareCard.statNumberFontDefault

        switch cell.style {
        case .personalBest:
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.Kubb.pbInk)
                Text(cell.value)
                    .font(KubbFont.fraunces(size, weight: .medium, italic: true))
                    .monospacedDigit()
                    .foregroundStyle(Color.Kubb.pbInk)
            }
        case .date:
            Text(cell.value)
                .font(KubbFont.fraunces(size, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.text)
        case .drill:
            Text(cell.value)
                .font(KubbFont.fraunces(size, weight: .medium, italic: true))
                .foregroundStyle(Color.Kubb.text)
        case .standard:
            Text(cell.value)
                .font(KubbFont.fraunces(size, weight: .medium, italic: true))
                .monospacedDigit()
                .foregroundStyle(Color.Kubb.text)
        }
    }

    // MARK: - Footer

    private var footerBand: some View {
        HStack(spacing: 24) {
            qrBlock

            VStack(alignment: .leading, spacing: 6) {
                Text(ShareCard.pillEyebrow)
                    .font(KubbFont.mono(10, weight: .bold))
                    .tracking(2.8)
                    .foregroundStyle(Color.Kubb.swedishGold)

                Text("Download Kubb Coach\nfrom the App Store.")
                    .font(KubbFont.fraunces(26, weight: .medium, italic: true))
                    .lineSpacing(2)
                    .foregroundStyle(Color.Kubb.cream)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            appStorePill
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 72)
        .frame(maxWidth: .infinity)
        .background(Color.Kubb.midnightNavy)
    }

    private var qrBlock: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.Kubb.midnightNavy)
                .frame(width: 100, height: 100)

            if let qr = QRCodeGenerator.image(
                for: ShareCard.appStoreURL,
                dark: UIColor(Color.Kubb.cream),
                light: UIColor(Color.Kubb.midnightNavy)
            ) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 88, height: 88)
            }
        }
    }

    private var appStorePill: some View {
        HStack(spacing: 10) {
            Image(systemName: "apple.logo")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.Kubb.midnightNavy)

            VStack(alignment: .leading, spacing: -2) {
                Text(ShareCard.pillLine1)
                    .font(KubbFont.inter(14, weight: .medium))
                    .tracking(0.2)
                    .foregroundStyle(Color.Kubb.midnightNavy.opacity(0.67))

                Text(ShareCard.pillLine2)
                    .font(KubbFont.inter(20, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(Color.Kubb.midnightNavy)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 22)
        .background(
            RoundedRectangle(cornerRadius: KubbRadius.ml)
                .fill(Color.Kubb.cream)
        )
    }

    // MARK: - Render

    /// Renders the card at its native 1080×1350 size for export.
    /// `ImageRenderer.scale = 1.0` produces a 1080×1350 px PNG; SwiftUI fonts
    /// are embedded as glyphs into the bitmap.
    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}

/// On-screen preview of the 1080×1350 share card, scaled to fit the
/// available width. Use `ShareCardView.renderImage()` for the actual export.
struct ShareCardPreview: View {
    let data: ShareCardData

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / ShareCard.canvasWidth
            ShareCardView(data: data)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: geo.size.width,
                    height: geo.size.width * ShareCard.canvasHeight / ShareCard.canvasWidth
                )
                .clipShape(RoundedRectangle(cornerRadius: KubbRadius.xl))
        }
        .aspectRatio(ShareCard.canvasWidth / ShareCard.canvasHeight, contentMode: .fit)
    }
}
