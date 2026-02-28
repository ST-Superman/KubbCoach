//
//  CalibrationView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//

import SwiftUI

struct CalibrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var capturedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var kubb1Position: CGPoint?
    @State private var kubb2Position: CGPoint?
    @State private var distance: Double = 1.0  // Default 1 meter

    let onComplete: (Double) -> Void

    var body: some View {
        NavigationStack {
            if let image = capturedImage {
                positionMarkerView(image: image)
            } else {
                instructionsView
            }
        }
    }

    private var instructionsView: some View {
        VStack(spacing: 24) {
            Text("Calibration")
                .font(.largeTitle)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 12) {
                Text("Instructions:")
                    .font(.headline)

                Text("1. Place two kubbs exactly \(Int(distance)) meter(s) apart")
                Text("2. Take or select a photo showing both kubbs")
                Text("3. Tap on the center of each kubb")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Stepper("Distance: \(Int(distance))m", value: $distance, in: 1...3, step: 1)
                .padding()

            VStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KubbColors.swedishBlue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }

                Button {
                    showingImagePicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KubbColors.phaseInkasting)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
            }

            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingCamera) {
            InkastingPhotoCaptureView(kubbCount: 2) { image in
                capturedImage = image
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePickerRepresentable(sourceType: .photoLibrary) { image in
                capturedImage = image
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func positionMarkerView(image: UIImage) -> some View {
        VStack(spacing: 16) {
            Text("Tap the center of each kubb")
                .font(.headline)

            if kubb1Position == nil {
                Text("Tap first kubb")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            } else if kubb2Position == nil {
                Text("Tap second kubb")
                    .font(.subheadline)
                    .foregroundStyle(.green)
            } else {
                Text("Tap 'Complete' or tap again to reset")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack {
                    // Background image
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)

                    // Draw markers
                    Canvas { context, size in
                        if let pos1 = kubb1Position {
                            let screenPos1 = imageToScreenCoordinates(pos1, containerSize: size, imageSize: image.size)
                            let marker1 = Path(ellipseIn: CGRect(x: screenPos1.x - 15, y: screenPos1.y - 15, width: 30, height: 30))
                            context.fill(marker1, with: .color(.blue.opacity(0.7)))
                            context.stroke(marker1, with: .color(.white), lineWidth: 2)
                        }
                        if let pos2 = kubb2Position {
                            let screenPos2 = imageToScreenCoordinates(pos2, containerSize: size, imageSize: image.size)
                            let marker2 = Path(ellipseIn: CGRect(x: screenPos2.x - 15, y: screenPos2.y - 15, width: 30, height: 30))
                            context.fill(marker2, with: .color(.green.opacity(0.7)))
                            context.stroke(marker2, with: .color(.white), lineWidth: 2)
                        }
                    }

                    // Transparent tap overlay on top to capture gestures
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    print("Tap detected at: \(value.location)")
                                    handleTap(at: value.location, containerSize: geometry.size, imageSize: image.size)
                                }
                        )
                }
            }
            .frame(maxHeight: 500)

            if kubb1Position != nil && kubb2Position != nil {
                Button {
                    calculateAndSave()
                } label: {
                    Text("Complete Calibration")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KubbColors.forestGreen)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Retake") {
                    kubb1Position = nil
                    kubb2Position = nil
                    capturedImage = nil
                }
            }
        }
    }

    private func handleTap(at location: CGPoint, containerSize: CGSize, imageSize: CGSize) {
        // Convert screen tap to image coordinates
        let imagePosition = screenToImageCoordinates(location, containerSize: containerSize, imageSize: imageSize)

        print("Container size: \(containerSize)")
        print("Image size: \(imageSize)")
        print("Screen tap: \(location)")
        print("Image position: \(imagePosition)")

        if kubb1Position == nil {
            kubb1Position = imagePosition
            print("Set kubb1Position: \(imagePosition)")
        } else if kubb2Position == nil {
            kubb2Position = imagePosition
            print("Set kubb2Position: \(imagePosition)")
        } else {
            // Reset - start over with first tap
            kubb1Position = imagePosition
            kubb2Position = nil
            print("Reset - set kubb1Position: \(imagePosition)")
        }
    }

    // Convert screen coordinates (tap location) to image coordinates
    private func screenToImageCoordinates(_ point: CGPoint, containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayedImageSize: CGSize
        var imageOffset: CGPoint

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            displayedImageSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayedImageSize.height) / 2)
        } else {
            // Image is taller - fit to height
            displayedImageSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayedImageSize.width) / 2, y: 0)
        }

        // Convert tap location to image coordinates
        let relativeX = (point.x - imageOffset.x) / displayedImageSize.width
        let relativeY = (point.y - imageOffset.y) / displayedImageSize.height

        return CGPoint(x: relativeX * imageSize.width, y: relativeY * imageSize.height)
    }

    // Convert image coordinates to screen coordinates for drawing
    private func imageToScreenCoordinates(_ point: CGPoint, containerSize: CGSize, imageSize: CGSize) -> CGPoint {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        var displayedImageSize: CGSize
        var imageOffset: CGPoint

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            displayedImageSize = CGSize(width: containerSize.width, height: containerSize.width / imageAspect)
            imageOffset = CGPoint(x: 0, y: (containerSize.height - displayedImageSize.height) / 2)
        } else {
            // Image is taller - fit to height
            displayedImageSize = CGSize(width: containerSize.height * imageAspect, height: containerSize.height)
            imageOffset = CGPoint(x: (containerSize.width - displayedImageSize.width) / 2, y: 0)
        }

        // Convert image coordinates to screen coordinates
        let relativeX = point.x / imageSize.width
        let relativeY = point.y / imageSize.height

        return CGPoint(
            x: imageOffset.x + relativeX * displayedImageSize.width,
            y: imageOffset.y + relativeY * displayedImageSize.height
        )
    }

    private func calculateAndSave() {
        guard let pos1 = kubb1Position, let pos2 = kubb2Position else { return }

        let service = CalibrationService()
        let calibration = service.calculateCalibration(
            point1: pos1,
            point2: pos2,
            knownDistanceMeters: distance
        )

        // Ensure ModelContext save happens on main thread
        Task { @MainActor in
            service.saveCalibration(calibration, modelContext: modelContext)
            onComplete(calibration)
            dismiss()
        }
    }
}
