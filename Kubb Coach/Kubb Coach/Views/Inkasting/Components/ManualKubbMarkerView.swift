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
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        handleTap(at: value.location, containerSize: geometry.size, imageSize: image.size)
                                    }
                            )
                    }
                }
                .frame(maxHeight: 500)

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
                        .background(markedPositions.count == totalKubbs ? Color.green : Color.orange)
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

    // MARK: - Coordinate Conversion

    private func screenToImageCoordinates(_ point: CGPoint, containerSize: CGSize, imageSize: CGSize) -> CGPoint {
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

        let relativeX = (point.x - imageOffset.x) / displayedImageSize.width
        let relativeY = (point.y - imageOffset.y) / displayedImageSize.height

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
