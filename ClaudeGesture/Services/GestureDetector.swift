import Vision
import Combine
import Foundation

/// Detects hand gestures from camera frames using Vision framework
class GestureDetector: ObservableObject {
    @Published var currentGesture: Gesture = .none
    @Published var detectionConfidence: Float = 0.0
    @Published var isProcessing = false

    private let settings = AppSettings.shared

    // Debouncing
    private var lastGesture: Gesture = .none
    private var gestureStartTime: Date?
    private var lastTriggerTime: Date?

    /// Callback when a gesture is confirmed (held for required duration)
    var onGestureConfirmed: ((Gesture) -> Void)?

    /// Analyze a frame for hand gestures
    func analyzeFrame(_ pixelBuffer: CVPixelBuffer) {
        guard !isProcessing else { return }
        isProcessing = true

        let request = VNDetectHumanHandPoseRequest { [weak self] request, error in
            defer {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                }
            }

            guard error == nil,
                  let observations = request.results as? [VNHumanHandPoseObservation],
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    self?.resetGesture()
                }
                return
            }

            self?.classifyGesture(from: observation)
        }

        request.maximumHandCount = 1

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision request failed: \(error)")
            DispatchQueue.main.async {
                self.isProcessing = false
            }
        }
    }

    /// Classify the gesture based on hand pose observation
    private func classifyGesture(from observation: VNHumanHandPoseObservation) {
        do {
            // Get finger tip and pip (proximal interphalangeal) points
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let thumbIP = try observation.recognizedPoint(.thumbIP)
            let indexTip = try observation.recognizedPoint(.indexTip)
            let indexPIP = try observation.recognizedPoint(.indexPIP)
            let middleTip = try observation.recognizedPoint(.middleTip)
            let middlePIP = try observation.recognizedPoint(.middlePIP)
            let ringTip = try observation.recognizedPoint(.ringTip)
            let ringPIP = try observation.recognizedPoint(.ringPIP)
            let littleTip = try observation.recognizedPoint(.littleTip)
            let littlePIP = try observation.recognizedPoint(.littlePIP)
            let wrist = try observation.recognizedPoint(.wrist)

            // Check confidence threshold
            let minConfidence = Float(settings.gestureSensitivity)
            guard thumbTip.confidence > minConfidence,
                  indexTip.confidence > minConfidence,
                  middleTip.confidence > minConfidence else {
                DispatchQueue.main.async {
                    self.resetGesture()
                }
                return
            }

            // Determine which fingers are extended
            let thumbExtended = thumbTip.y > thumbIP.y + 0.05
            let thumbDown = thumbTip.y < thumbIP.y - 0.05
            let indexExtended = indexTip.y > indexPIP.y + 0.03
            let middleExtended = middleTip.y > middlePIP.y + 0.03
            let ringExtended = ringTip.y > ringPIP.y + 0.03
            let littleExtended = littleTip.y > littlePIP.y + 0.03

            // Count extended fingers
            let extendedCount = [indexExtended, middleExtended, ringExtended, littleExtended].filter { $0 }.count

            // Classify gesture
            let detectedGesture: Gesture
            let confidence: Float

            if thumbExtended && !indexExtended && !middleExtended && !ringExtended && !littleExtended {
                // Thumbs up: only thumb extended upward
                detectedGesture = .thumbsUp
                confidence = thumbTip.confidence
            } else if thumbDown && !indexExtended && !middleExtended && !ringExtended && !littleExtended {
                // Thumbs down: only thumb extended downward
                detectedGesture = .thumbsDown
                confidence = thumbTip.confidence
            } else if !indexExtended && !middleExtended && !ringExtended && littleExtended {
                // Pinky up: only little finger extended
                detectedGesture = .pinkyUp
                confidence = littleTip.confidence
            } else if thumbExtended && indexExtended && middleExtended && ringExtended && littleExtended {
                // Five fingers: all fingers extended including thumb
                detectedGesture = .fiveFingers
                confidence = (thumbTip.confidence + indexTip.confidence + middleTip.confidence + ringTip.confidence + littleTip.confidence) / 5
            } else if !thumbExtended && indexExtended && middleExtended && ringExtended && littleExtended {
                // Four fingers: all four fingers extended (excluding thumb)
                detectedGesture = .fourFingers
                confidence = (indexTip.confidence + middleTip.confidence + ringTip.confidence + littleTip.confidence) / 4
            } else if !indexExtended && !middleExtended && !ringExtended && !littleExtended {
                // Closed fist: no fingers extended (triggers Shift+Tab)
                detectedGesture = .closedFist
                confidence = 0.8
            } else if indexExtended && !middleExtended && !ringExtended && !littleExtended {
                // One finger up: only index extended
                detectedGesture = .oneFingerUp
                confidence = indexTip.confidence
            } else if indexExtended && middleExtended && !ringExtended && !littleExtended {
                // Peace sign: index and middle extended
                detectedGesture = .peaceSign
                confidence = (indexTip.confidence + middleTip.confidence) / 2
            } else if indexExtended && middleExtended && ringExtended && !littleExtended {
                // Three fingers: index, middle, and ring extended
                detectedGesture = .threeFingers
                confidence = (indexTip.confidence + middleTip.confidence + ringTip.confidence) / 3
            } else {
                detectedGesture = .none
                confidence = 0
            }

            DispatchQueue.main.async {
                self.updateGesture(detectedGesture, confidence: confidence)
            }

        } catch {
            print("Failed to get hand points: \(error)")
            DispatchQueue.main.async {
                self.resetGesture()
            }
        }
    }

    /// Update the current gesture with debouncing logic
    private func updateGesture(_ gesture: Gesture, confidence: Float) {
        currentGesture = gesture
        detectionConfidence = confidence

        guard gesture != .none else {
            resetGesture()
            return
        }

        // Check if this is the same gesture being held
        if gesture == lastGesture {
            if let startTime = gestureStartTime {
                let holdDuration = Date().timeIntervalSince(startTime)
                if holdDuration >= settings.gestureHoldDuration {
                    // Check cooldown
                    if let lastTrigger = lastTriggerTime {
                        if Date().timeIntervalSince(lastTrigger) < settings.gestureCooldown {
                            return // Still in cooldown
                        }
                    }

                    // Trigger the gesture
                    lastTriggerTime = Date()
                    gestureStartTime = Date() // Reset for next trigger
                    onGestureConfirmed?(gesture)
                }
            }
        } else {
            // New gesture detected, start timing
            lastGesture = gesture
            gestureStartTime = Date()
        }
    }

    /// Reset gesture tracking state
    private func resetGesture() {
        currentGesture = .none
        detectionConfidence = 0
        lastGesture = .none
        gestureStartTime = nil
    }
}
