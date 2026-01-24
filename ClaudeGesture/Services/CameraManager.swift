import AVFoundation
import Combine
import Vision

/// Manages camera capture and feeds frames to the gesture detector
class CameraManager: NSObject, ObservableObject {
    @Published var isRunning = false
    @Published var permissionGranted = false
    @Published var errorMessage: String?

    private let captureSession = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.gesturecontrol.camera")

    /// Callback for when a new frame is available
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?

    /// Preview layer for displaying camera feed
    var previewLayer: AVCaptureVideoPreviewLayer?

    override init() {
        super.init()
        checkPermissions()
    }

    /// Check and request camera permissions
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.errorMessage = "Camera access denied. Please enable in System Settings."
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Camera access denied. Please enable in System Settings > Privacy > Camera."
            }
        @unknown default:
            break
        }
    }

    /// Configure the capture session
    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .medium

            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                DispatchQueue.main.async {
                    self.errorMessage = "No front camera available"
                }
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create camera input: \(error.localizedDescription)"
                }
                return
            }

            // Add video output
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            // Set video orientation
            if let connection = self.videoOutput.connection(with: .video) {
                connection.videoRotationAngle = 0
                connection.isVideoMirrored = true
            }

            self.captureSession.commitConfiguration()

            // Create preview layer
            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer?.videoGravity = .resizeAspectFill
            }
        }
    }

    /// Start capturing video frames
    func start() {
        guard permissionGranted else {
            checkPermissions()
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    /// Stop capturing video frames
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}
