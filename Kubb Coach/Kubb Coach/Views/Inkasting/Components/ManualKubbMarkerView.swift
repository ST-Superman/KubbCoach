//
//  ManualKubbMarkerView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI

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

    var remainingKubbs: Int {
        totalKubbs - markedPositions.count
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
                                withAnimation(.spring()) {
                                    scale = 1.0
                                    lastScale = 1.0
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
                                scale = min(max(newScale, 1.0), 4.0)
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
                                        offset = constrainOffset(newOffset, scale: scale, containerSize: geometry.size, imageSize: image.size)
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
                .frame(maxHeight: 500)

                // Zoom level indicator
                if scale > 1.0 {
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
                }

                if !markedPositions.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Undo") {
                            if !markedPositions.isEmpty {
                                markedPositions.removeLast()
                            }
                        }
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
            if markedPositions.count >= max(totalKubbs - 2, 3) {
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
                        .background(markedPositions.count == totalKubbs ? KubbColors.forestGreen : KubbColors.phase4m)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }

            if !markedPositions.isEmpty {
                Button {
                    markedPositions.removeAll()
                } label: {
                    Text("Clear All")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundStyle(.red)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func drawMarkers(context: GraphicsContext, size: CGSize) {
        for (index, position) in markedPositions.enumerated() {
            let screenPos = imageToScreenCoordinates(position, containerSize: size, imageSize: image.size)

            // Draw numbered marker
            let markerRect = CGRect(x: screenPos.x - 15, y: screenPos.y - 15, width: 30, height: 30)
            let markerPath = Path(ellipseIn: markerRect)

            // Fill with blue
            context.fill(markerPath, with: .color(.blue.opacity(0.7)))
            context.stroke(markerPath, with: .color(.white), lineWidth: 3)

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

        // Convert screen tap to normalized image coordinates (0-1)
        let imagePos = screenToImageCoordinates(location, containerSize: containerSize, imageSize: imageSize)

        // Convert to normalized coordinates (0-1 range)
        let normalizedPos = CGPoint(
            x: imagePos.x / imageSize.width,
            y: imagePos.y / imageSize.height
        )

        markedPositions.append(normalizedPos)
        print("✅ Marked kubb \(markedPositions.count) at normalized position: \(normalizedPos)")
    }

    private func completeMarking() {
        print("📊 Completing marking with \(markedPositions.count) positions")
        // Return normalized positions (0-1 range)
        onComplete(markedPositions)
        dismiss()
    }

    // MARK: - Zoom/Pan Helpers

    private func constrainOffset(_ offset: CGSize, scale: CGFloat, containerSize: CGSize, imageSize: CGSize) -> CGSize {
        guard scale > 1.0 else { return .zero }

        // Calculate displayed image size accounting for aspect ratio
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayedImageSize: CGSize
        if imageAspect > containerAspect {
            displayedImageSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
        } else {
            displayedImageSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
        }

        // Calculate how much the scaled image extends beyond container
        let scaledWidth = displayedImageSize.width * scale
        let scaledHeight = displayedImageSize.height * scale

        let maxOffsetX = (scaledWidth - containerSize.width) / 2
        let maxOffsetY = (scaledHeight - containerSize.height) / 2

        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }

    // MARK: - Coordinate Conversion

    private func screenToImageCoordinates(_ point: CGPoint, containerSize: CGSize, imageSize: CGSize) -> CGPoint {
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

        // Step 3: Continue with existing aspect ratio calculations
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayedImageSize: CGSize
        var imageOffset: CGPoint

        if imageAspect > containerAspect {
            displayedImageSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayedImageSize.height) / 2)
        } else {
            displayedImageSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayedImageSize.width) / 2, y: 0)
        }

        let relativeX = (unscaledPoint.x - imageOffset.x) / displayedImageSize.width
        let relativeY = (unscaledPoint.y - imageOffset.y) / displayedImageSize.height

        return CGPoint(x: relativeX * imageSize.width, y: relativeY * imageSize.height)
    }

    private func imageToScreenCoordinates(_ point: CGPoint, containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayedImageSize: CGSize
        var imageOffset: CGPoint

        if imageAspect > containerAspect {
            displayedImageSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayedImageSize.height) / 2)
        } else {
            displayedImageSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayedImageSize.width) / 2, y: 0)
        }

        // Point is already in normalized coordinates (0-1), so use directly
        let relativeX = point.x
        let relativeY = point.y

        return CGPoint(
            x: imageOffset.x + relativeX * displayedImageSize.width,
            y: imageOffset.y + relativeY * displayedImageSize.height
        )
    }
}
