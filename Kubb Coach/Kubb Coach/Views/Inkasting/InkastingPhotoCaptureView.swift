//
//  InkastingPhotoCaptureView.swift
//  Kubb Coach
//
//  Created by Claude Code on 2/24/26.
//  Refactored: 3/24/26 - Added permissions, error handling, loading states
//

import SwiftUI
import UIKit
import AVFoundation
import OSLog
import PhotosUI

// MARK: - Main View

struct InkastingPhotoCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPermission: AVAuthorizationStatus = .notDetermined
    @State private var showImagePicker = false
    @State private var showPhotosPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isCameraReady = false
    @State private var showPermissionAlert = false

    let kubbCount: Int
    let onCapture: (UIImage) -> Void

    var body: some View {
        Group {
            switch cameraPermission {
            case .authorized:
                cameraView
            case .denied, .restricted:
                permissionDeniedView
            case .notDetermined:
                loadingView
                    .onAppear {
                        checkCameraPermission()
                    }
            @unknown default:
                permissionDeniedView
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerRepresentable(onImagePicked: handleImageCapture)
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handleImageCapture(image)
                }
            }
        }
        .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to photograph kubbs for training analysis.")
        }
    }

    // MARK: - Camera View

    private var cameraView: some View {
        ZStack {
            // Camera view controller — always present so viewDidLoad can set up the session.
            // The loading overlay is shown on top until onReady fires.
            CameraViewControllerRepresentable(
                onCapture: handleImageCapture,
                onReady: { isCameraReady = true },
                onError: { error in
                    AppLogger.inkasting.error("Camera error: \(error)")
                }
            )
            .ignoresSafeArea()

            if !isCameraReady {
                Color.black
                    .ignoresSafeArea()
                loadingView
            }

            // Overlay UI
            VStack {
                // Top instructions
                Text("Position all \(kubbCount) kubbs in frame")
                    .font(.headline)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
                    .accessibilityLabel("Instruction: Position all \(kubbCount) kubbs in the camera frame")

                Spacer()

                // Bottom controls
                HStack(spacing: 40) {
                    // Photo library button (iOS 16+)
                    if #available(iOS 16, *) {
                        Button {
                            showPhotosPicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Open photo library")
                        .accessibilityHint("Select a photo of kubbs from your library")
                    } else {
                        // Fallback for iOS 15
                        Button {
                            showImagePicker = true
                        } label: {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Open photo library")
                    }

                    // Close button
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Close camera")
                    .accessibilityHint("Return to previous screen")
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Permission Denied View

    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
                .padding(.top, 60)

            VStack(spacing: 12) {
                Text("Camera Access Required")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Kubb Coach needs camera access to photograph kubbs for training analysis.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 16) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)

                // Alternative: Use photo library
                if #available(iOS 16, *) {
                    Button {
                        showPhotosPicker = true
                    } label: {
                        Label("Use Photo Library Instead", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 32)
                } else {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label("Use Photo Library Instead", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal, 32)
                }
            }

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Text("Cancel")
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Initializing camera...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Permission Handling

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .notDetermined {
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraPermission = granted ? .authorized : .denied
                    if !granted {
                        showPermissionAlert = true
                    }
                }
            }
        } else {
            cameraPermission = status
            if status == .denied || status == .restricted {
                showPermissionAlert = true
            }
        }
    }

    // MARK: - Image Handling

    private func handleImageCapture(_ image: UIImage) {
        // Validate and resize image
        guard let validatedImage = validateAndResizeImage(image) else {
            AppLogger.inkasting.error("Image validation failed")
            return
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        onCapture(validatedImage)
    }

    private func validateAndResizeImage(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else {
            AppLogger.inkasting.error("Failed to get CGImage from UIImage")
            return nil
        }

        // Check image size (limit to reasonable dimensions)
        let megapixels = (cgImage.width * cgImage.height) / 1_000_000
        AppLogger.inkasting.debug("Image size: \(cgImage.width)x\(cgImage.height) (\(megapixels)MP)")

        // If image is too large, resize it for vision processing
        let maxDimension: CGFloat = 2048
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

            AppLogger.inkasting.info("Resizing image from \(image.size.width)x\(image.size.height) to \(newSize.width)x\(newSize.height)")
            return image.resized(to: newSize)
        }

        return image
    }
}

// MARK: - Camera View Controller

struct CameraViewControllerRepresentable: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onReady: () -> Void
    let onError: (String) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        controller.onReady = onReady
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Camera Controller

class CameraViewController: UIViewController {
    /// Callback when photo is captured. Use [weak self] if capturing parent view.
    var onCapture: ((UIImage) -> Void)?
    var onReady: (() -> Void)?
    var onError: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureButton: UIButton!
    private var errorLabel: UILabel?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updatePreviewOrientation()
    }

    private func updatePreviewOrientation() {
        guard let connection = previewLayer?.connection else { return }
        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = currentVideoRotationAngle()
        } else {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = currentVideoOrientation()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AppLogger.inkasting.debug("🎥 Stopping camera session")
        stopCamera()
    }

    deinit {
        AppLogger.inkasting.debug("🎥 CameraViewController deinitialized")
        stopCamera()
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo

        guard let captureSession = captureSession else {
            showError("Failed to create capture session")
            return
        }

        // Get camera device
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            showError("Camera not available on this device")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            } else {
                throw CameraError.cannotAddInput
            }

            photoOutput = AVCapturePhotoOutput()

            // Set max photo dimensions to optimize for vision processing
            if let photoOutput = photoOutput {
                photoOutput.maxPhotoQualityPrioritization = .balanced

                if captureSession.canAddOutput(photoOutput) {
                    captureSession.addOutput(photoOutput)
                } else {
                    throw CameraError.cannotAddOutput
                }
            }

            // Setup preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
            previewLayer?.frame = view.bounds

            if let previewLayer = previewLayer {
                view.layer.addSublayer(previewLayer)
            }

            // Start session on background thread
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                captureSession.startRunning()

                DispatchQueue.main.async {
                    self?.onReady?()
                    AppLogger.inkasting.debug("🎥 Camera session started successfully")
                }
            }

        } catch {
            let errorMessage = "Error setting up camera: \(error.localizedDescription)"
            AppLogger.inkasting.error("\(errorMessage)")
            showError(errorMessage)
            onError?(errorMessage)
        }
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
        photoOutput = nil
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Capture button
        captureButton = UIButton(type: .custom)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        captureButton.accessibilityLabel = "Capture photo"
        captureButton.accessibilityHint = "Take a photo of the kubbs"

        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
    }

    private func showError(_ message: String) {
        // Remove existing error label
        errorLabel?.removeFromSuperview()

        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        errorLabel = label
    }

    // MARK: - Photo Capture

    @objc private func capturePhoto() {
        guard let photoOutput = photoOutput else {
            showError("Photo output not available")
            return
        }

        // Visual feedback - animate button
        UIView.animate(withDuration: 0.1, animations: {
            self.captureButton.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.captureButton.transform = .identity
            }
        }

        let settings = AVCapturePhotoSettings()

        // Set photo orientation to match device orientation
        if let connection = photoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = currentVideoRotationAngle()
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = currentVideoOrientation()
                }
            }
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
        AppLogger.inkasting.debug("🎥 Capturing photo...")
    }

    // MARK: - Orientation Handling

    /// Returns the video rotation angle for iOS 17+.
    /// Uses interface orientation (from windowScene) which is always valid, unlike
    /// UIDevice.current.orientation which returns .unknown/.faceUp at view load time.
    @available(iOS 17.0, *)
    private func currentVideoRotationAngle() -> CGFloat {
        let interfaceOrientation = view.window?.windowScene?.interfaceOrientation
            ?? .portrait

        switch interfaceOrientation {
        case .portrait:
            return 90
        case .portraitUpsideDown:
            return 270
        case .landscapeLeft:
            return 180
        case .landscapeRight:
            return 0
        @unknown default:
            return 90
        }
    }

    /// Returns the video orientation for iOS 16 and earlier.
    /// Called only from the `else` branch of `#available(iOS 17.0, *)` — intentional use of legacy API.
    @available(iOS, deprecated: 17.0, renamed: "currentVideoRotationAngle()")
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        let interfaceOrientation = view.window?.windowScene?.interfaceOrientation
            ?? .portrait

        switch interfaceOrientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight // AVCapture landscape is mirrored vs interface
        case .landscapeRight:
            return .landscapeLeft
        @unknown default:
            return .portrait
        }
    }
}

// MARK: - Photo Capture Delegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        AppLogger.inkasting.debug("🎥 photoOutput delegate called")

        if let error = error {
            let errorMessage = "Camera capture error: \(error.localizedDescription)"
            AppLogger.inkasting.error("🎥 \(errorMessage)")
            showError(errorMessage)
            onError?(errorMessage)
            return
        }

        guard let imageData = photo.fileDataRepresentation() else {
            AppLogger.inkasting.error("🎥 No image data from photo")
            showError("Failed to process photo")
            return
        }

        guard let image = UIImage(data: imageData) else {
            AppLogger.inkasting.error("🎥 Failed to create UIImage from data")
            showError("Failed to create image")
            return
        }

        AppLogger.inkasting.info("🎥 Photo successfully processed")
        onCapture?(image)
    }
}

// MARK: - Image Picker (iOS 15 Fallback)

struct ImagePickerRepresentable: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerRepresentable

        init(_ parent: ImagePickerRepresentable) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Camera Error

enum CameraError: LocalizedError {
    case cannotAddInput
    case cannotAddOutput
    case deviceUnavailable

    var errorDescription: String? {
        switch self {
        case .cannotAddInput:
            return "Cannot add camera input to session"
        case .cannotAddOutput:
            return "Cannot add photo output to session"
        case .deviceUnavailable:
            return "Camera device not available"
        }
    }
}
