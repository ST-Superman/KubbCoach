//
//  QRCodeGenerator.swift
//  Kubb Coach
//
//  CoreImage-backed QR generator used by the share card's App Store footer.
//  Renders locally — no network — and tints the output with arbitrary
//  foreground / background colors via a false-color filter.
//

#if os(iOS)
import UIKit
import CoreImage.CIFilterBuiltins

enum QRCodeGenerator {
    /// Renders a QR code for `text` with `dark` foreground and `light` background.
    /// Returns nil if the CoreImage filter chain fails for any reason.
    static func image(for text: String, dark: UIColor, light: UIColor, scale: CGFloat = 10) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let raw = filter.outputImage else { return nil }

        let tint = CIFilter.falseColor()
        tint.inputImage = raw
        tint.color0 = CIColor(color: dark)
        tint.color1 = CIColor(color: light)

        guard let tinted = tint.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else {
            return nil
        }
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(tinted, from: tinted.extent) else {
            return nil
        }
        return UIImage(cgImage: cg)
    }
}
#endif
