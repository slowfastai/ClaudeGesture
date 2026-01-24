import SwiftUI
import AVFoundation

/// NSView wrapper for AVCaptureVideoPreviewLayer
struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer?

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.wantsLayer = true
        if let layer = previewLayer {
            layer.frame = view.bounds
            layer.videoGravity = .resizeAspectFill
            view.layer?.addSublayer(layer)
        }
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        if let layer = previewLayer {
            layer.frame = nsView.bounds
        }
    }
}

/// Custom NSView for camera preview
class CameraPreviewNSView: NSView {
    override func layout() {
        super.layout()
        // Update sublayer frames when view resizes
        layer?.sublayers?.forEach { sublayer in
            sublayer.frame = bounds
        }
    }
}

/// SwiftUI view that shows camera preview with gesture overlay
struct CameraPreviewWithOverlay: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var gestureDetector: GestureDetector

    var body: some View {
        ZStack {
            // Camera preview
            if let previewLayer = cameraManager.previewLayer {
                CameraPreviewView(previewLayer: previewLayer)
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .overlay(
                        VStack {
                            Image(systemName: "camera.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Camera not available")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }

            // Gesture overlay
            VStack {
                Spacer()
                HStack {
                    // Current gesture indicator
                    if gestureDetector.currentGesture != .none {
                        HStack(spacing: 8) {
                            Text(gestureDetector.currentGesture.emoji)
                                .font(.title)
                            VStack(alignment: .leading) {
                                Text(gestureDetector.currentGesture.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Text(gestureDetector.currentGesture.actionDescription)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                    }
                    Spacer()
                    // Confidence indicator
                    if gestureDetector.detectionConfidence > 0 {
                        Text("\(Int(gestureDetector.detectionConfidence * 100))%")
                            .font(.caption)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(4)
                    }
                }
                .padding(8)
            }
        }
        .frame(height: 150)
        .cornerRadius(8)
        .clipped()
    }
}

#Preview {
    CameraPreviewWithOverlay(
        cameraManager: CameraManager(),
        gestureDetector: GestureDetector()
    )
    .frame(width: 280)
    .padding()
}
