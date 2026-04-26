//
//  ManualKubbMarkerView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI
import OSLog

/// Constants for marker appearance and behavior
private enum MarkerConstants {
    // Zoom
    static let minZoomScale: CGFloat = 1.0
    static let maxZoomScale: CGFloat = 4.0

    // Marker appearance
    static let markerSize: CGFloat = 30
    static let markerRadius: CGFloat = markerSize / 2
    static let markerStrokeWidth: CGFloat = 3
    static let markerOpacity: Double = 0.7
    static let markerColor: Color = .blue

    // Layout
    static let maxImageHeight: CGFloat = 500

    // Analysis limits
    static let minKubbsForAnalysis: Int = 2
    static let absoluteMinKubbs: Int = 3
}

/// Helper struct for coordinate transformations between screen and image space
struct KubbMarkerCoordinateTransformer {
    let imageSize: CGSize
    let containerSize: CGSize
    let scale: CGFloat
    let offset: CGSize

    /// Cached aspect ratio calculations
    private var imageAspect: CGFloat {
        imageSize.width / imageSize.height
    }

    private var containerAspect: CGFloat {
        containerSize.width / containerSize.height
    }

    /// Calculates the displayed image size and offset accounting for aspect ratio fit
    private var displayedImageInfo: (size: CGSize, offset: CGPoint) {
        var displayedImageSize: CGSize
        var imageOffset: CGPoint

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            displayedImageSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
            imageOffset = CGPoint(
                x: 0,
                y: (containerSize.height - displayedImageSize.height) / 2
            )
        } else {
            // Image is taller - fit to height
            displayedImageSize = CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
            imageOffset = CGPoint(
                x: (containerSize.width - displayedImageSize.width) / 2,
                y: 0
            )
        }

        return (displayedImageSize, imageOffset)
    }

    /// Converts a screen point to image coordinates, accounting for zoom and pan
    func screenToImageCoordinates(_ point: CGPoint) -> CGPoint {
        // Step 1: Adjust for pan offset
        let adjustedPoint = CGPoint(
            x: point.x - offset.width,
            y: point.y - offset.height
        )

        // Step 2: Adjust for zoom scale (reverse the scale transform)
        let center = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let unscaledPoint = CGPoint(
            x: center.x + (adjustedPoint.x - center.x) / scale,
            y: center.y + (adjustedPoint.y - center.y) / scale
        )

        // Step 3: Convert to image coordinates accounting for aspect ratio
        let info = displayedImageInfo
        let relativeX = (unscaledPoint.x - info.offset.x) / info.size.width
        let relativeY = (unscaledPoint.y - info.offset.y) / info.size.height

        return CGPoint(x: relativeX * imageSize.width, y: relativeY * imageSize.height)
    }

    /// Converts normalized image coordinates (0-1) to screen coordinates
    func normalizedToScreenCoordinates(_ point: CGPoint) -> CGPoint {
        let info = displayedImageInfo
        return CGPoint(
            x: info.offset.x + point.x * info.size.width,
            y: info.offset.y + point.y * info.size.height
        )
    }

    /// Constrains pan offset to keep image within bounds when zoomed
    func constrainOffset(_ proposedOffset: CGSize) -> CGSize {
        guard scale > MarkerConstants.minZoomScale else { return .zero }

        let info = displayedImageInfo
        let scaledWidth = info.size.width * scale
        let scaledHeight = info.size.height * scale

        let maxOffsetX = (scaledWidth - containerSize.width) / 2
        let maxOffsetY = (scaledHeight - containerSize.height) / 2

        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }
}

/// View for manually marking kubb positions by tapping
struct ManualKubbMarkerView: View {
    let image: UIImage
    let totalKubbs: Int
    let onComplete: ([CGPoint]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var markedPositions: [CGPoint] = []
    @State private var showingConfirmation = false

    // Zoom and pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    // Haptic feedback generators
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    var remainingKubbs: Int {
        totalKubbs - markedPositions.count
    }

    init(image: UIImage, totalKubbs: Int, onComplete: @escaping ([CGPoint]) -> Void) {
        // Validate image dimensions
        guard image.size.width > 0, image.size.height > 0 else {
            preconditionFailure("Image must have non-zero dimensions (got \(image.size))")
        }

        // Validate kubb count (reasonable range for manual marking)
        guard (1...20).contains(totalKubbs) else {
            preconditionFailure("Total kubbs must be between 1 and 20 (got \(totalKubbs))")
        }

        self.image = image
        self.totalKubbs = totalKubbs
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Instructions
                instructionsBanner

                // Image with markers
                GeometryReader { geometry in
                    ZStack {
                        // Background image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                        // Draw markers
                        Canvas { context, size in
                            drawMarkers(context: context, size: size)
                        }

                        // Transparent tap overlay
                        Color.clear
                            .contentShape(Rectangle())
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        // Double-tap to reset zoom
                        TapGesture(count: 2)
                            .onEnded {
                                hapticFeedback.impactOccurred()
                                withAnimation(.spring()) {
                                    scale = MarkerConstants.minZoomScale
                                    lastScale = MarkerConstants.minZoomScale
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                    )
                    .gesture(
                        // Pinch to zoom
                        MagnificationGesture()
                            .onChanged { value in
                                let delta = value / lastScale
                                lastScale = value
                                let newScale = scale * delta
                                scale = min(max(newScale, MarkerConstants.minZoomScale), MarkerConstants.maxZoomScale)
                            }
                            .onEnded { _ in
                                lastScale = 1.0
                            }
                            .simultaneously(with:
                                // Pan when zoomed
                                DragGesture()
                                    .onChanged { value in
                                        let newOffset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        let transformer = KubbMarkerCoordinateTransformer(
                                            imageSize: image.size,
                                            containerSize: geometry.size,
                                            scale: scale,
                                            offset: newOffset
                                        )
                                        offset = transformer.constrainOffset(newOffset)
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                    )
                    .gesture(
                        // Tap to mark kubbs
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                handleTap(at: value.location, containerSize: geometry.size, imageSize: image.size)
                            }
                    )
                }
                .frame(maxHeight: MarkerConstants.maxImageHeight)

                // Zoom level indicator
                if scale > MarkerConstants.minZoomScale {
                    Text("\(String(format: "%.1fx", scale)) zoom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .transition(.opacity)
                }

                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("Mark Kubbs (\(markedPositions.count)/\(totalKubbs))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel marking")
                    .accessibilityHint("Dismisses the manual kubb marker without saving")
                }

                if !markedPositions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Undo") {
                            markedPositions.removeLast()
                            hapticFeedback.impactOccurred()
                        }
                        .accessibilityLabel("Undo last marker")
                        .accessibilityHint("Removes the most recently placed kubb marker")
                    }
                }
            }
            .alert("Complete Analysis?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Analyze") {
                    completeMarking()
                }
            } message: {
                Text("You've marked \(markedPositions.count) of \(totalKubbs) kubbs. Analyze with current marks?")
            }
        }
        .accessibilityLabel(generateAccessibilityLabel())
        .accessibilityHint("Double tap with two fingers to zoom. Use pinch gesture to zoom in and out. Tap on kubbs in the image to mark their positions.")
        .accessibilityAction(named: "Zoom In") {
            withAnimation(.spring()) {
                scale = min(scale + 0.5, MarkerConstants.maxZoomScale)
            }
            hapticFeedback.impactOccurred()
        }
        .accessibilityAction(named: "Zoom Out") {
            withAnimation(.spring()) {
                scale = max(scale - 0.5, MarkerConstants.minZoomScale)
                if scale == MarkerConstants.minZoomScale {
                    offset = .zero
                    lastOffset = .zero
                }
            }
            hapticFeedback.impactOccurred()
        }
        .accessibilityAction(named: "Reset Zoom") {
            withAnimation(.spring()) {
                scale = MarkerConstants.minZoomScale
                lastScale = MarkerConstants.minZoomScale
                offset = .zero
                lastOffset = .zero
            }
            hapticFeedback.impactOccurred()
        }
    }

    private var instructionsBanner: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "hand.tap.fill")
                    .foregroundStyle(.blue)
                Text("Tap on each kubb to mark its position")
                    .font(.headline)
            }

            if remainingKubbs > 0 {
                Text("\(remainingKubbs) kubb(s) remaining")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("All kubbs marked! Tap 'Analyze' to continue")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }

            Text("Pinch to zoom • Double-tap to reset")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if markedPositions.count >= max(totalKubbs - MarkerConstants.minKubbsForAnalysis, MarkerConstants.absoluteMinKubbs) {
                Button {
                    if markedPositions.count == totalKubbs {
                        completeMarking()
                    } else {
                        showingConfirmation = true
                    }
                } label: {
                    Text("ANALYZE")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(markedPositions.count == totalKubbs ? Color.Kubb.forestGreen : Color.Kubb.phase4m)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Analyze marked kubbs")
                .accessibilityHint("Proceeds to analysis with \(markedPositions.count) of \(totalKubbs) kubbs marked")
            }

            if !markedPositions.isEmpty {
                Button {
                    markedPositions.removeAll()
                    notificationFeedback.notificationOccurred(.warning)
                } label: {
                    Text("Clear All")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.red)
                        .cornerRadius(12)
                }
                .accessibilityLabel("Clear all markers")
                .accessibilityHint("Removes all \(markedPositions.count) kubb markers")
            }
        }
    }

    // MARK: - Accessibility

    /// Generates accessibility label describing current marking state (internal for testing)
    func generateAccessibilityLabel() -> String {
        """
        Manual kubb marking. \(markedPositions.count) of \(totalKubbs) kubbs marked. \
        \(remainingKubbs) remaining. \
        Tap on kubbs in the image to mark their positions.
        """
    }

    // MARK: - Drawing

    private func drawMarkers(context: GraphicsContext, size: CGSize) {
        // Create transformer for current state (no zoom/pan in canvas)
        let transformer = KubbMarkerCoordinateTransformer(
            imageSize: image.size,
            containerSize: size,
            scale: 1.0,
            offset: .zero
        )

        for (index, position) in markedPositions.enumerated() {
            let screenPos = transformer.normalizedToScreenCoordinates(position)

            // Draw numbered marker
            let markerRect = CGRect(
                x: screenPos.x - MarkerConstants.markerRadius,
                y: screenPos.y - MarkerConstants.markerRadius,
                width: MarkerConstants.markerSize,
                height: MarkerConstants.markerSize
            )
            let markerPath = Path(ellipseIn: markerRect)

            // Fill with marker color
            context.fill(markerPath, with: .color(MarkerConstants.markerColor.opacity(MarkerConstants.markerOpacity)))
            context.stroke(markerPath, with: .color(.white), lineWidth: MarkerConstants.markerStrokeWidth)

            // Draw number
            let numberText = Text("\(index + 1)")
                .font(.caption)
                .bold()
                .foregroundColor(.white)

            context.draw(numberText, at: screenPos)
        }
    }

    private func handleTap(at location: CGPoint, containerSize: CGSize, imageSize: CGSize) {
        guard markedPositions.count < totalKubbs else { return }

        // Create transformer for current zoom/pan state
        let transformer = KubbMarkerCoordinateTransformer(
            imageSize: imageSize,
            containerSize: containerSize,
            scale: scale,
            offset: offset
        )

        // Convert screen tap to image coordinates
        let imagePos = transformer.screenToImageCoordinates(location)

        // Convert to normalized coordinates and clamp to [0, 1] range
        let normalizedPos = CGPoint(
            x: max(0, min(1, imagePos.x / imageSize.width)),
            y: max(0, min(1, imagePos.y / imageSize.height))
        )

        // Validate position is within image bounds (reject taps outside the image)
        guard (0...1).contains(normalizedPos.x), (0...1).contains(normalizedPos.y) else {
            AppLogger.inkasting.warning("Tap outside image bounds at \(normalizedPos.debugDescription), ignoring")
            notificationFeedback.notificationOccurred(.warning)
            return
        }

        markedPositions.append(normalizedPos)
        AppLogger.inkasting.info("✅ Marked kubb \(markedPositions.count) at normalized position: \(normalizedPos.debugDescription)")

        // Haptic feedback on successful tap
        hapticFeedback.impactOccurred()

        // Success notification when all kubbs are marked
        if markedPositions.count == totalKubbs {
            notificationFeedback.notificationOccurred(.success)
        }
    }

    private func completeMarking() {
        AppLogger.inkasting.info("📊 Completing marking with \(markedPositions.count) positions")
        // Return normalized positions (0-1 range)
        onComplete(markedPositions)
        dismiss()
    }
}
