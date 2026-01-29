import Combine
import CoreGraphics
import CoreVideo
import Foundation

/// Detects hand gestures from camera frames using the selected backend
class GestureDetector: ObservableObject {
    @Published var currentGesture: Gesture = .none
    @Published var detectionConfidence: Float = 0.0
    @Published var isProcessing = false

    private let settings = AppSettings.shared

    private let visionQueue = DispatchQueue(label: "com.gesturecode.vision")
    private let processingSemaphore = DispatchSemaphore(value: 1)
    private var backend: HandLandmarkBackend
    private let actionDetector: HandActionDetector

    private var frameIndex = 0
    private var stableGesture: Gesture = .none
    private var stableGestureFrames = 0
    private let stableFrameThreshold = 5
    private let frameSkipWhenStable = 2
    private let staleTimeout: TimeInterval = 0.4
    private var lastValidDetectionTime: Date?
    private var cancellables = Set<AnyCancellable>()

    // Debouncing
    private var lastGesture: Gesture = .none
    private var gestureStartTime: Date?
    private var lastTriggerTime: Date?

    /// Callback when a gesture is confirmed (held for required duration)
    var onGestureConfirmed: ((Gesture) -> Void)?
    var onActionDetected: ((HandAction) -> Void)?

    init() {
        backend = GestureDetector.makeBackend(settings.detectionBackend)
        actionDetector = HandActionDetector(settings: settings)
        observeSettings()
    }

    /// Analyze a frame for hand gestures
    func analyzeFrame(_ pixelBuffer: CVPixelBuffer) {
        guard processingSemaphore.wait(timeout: .now()) == .success else { return }

        DispatchQueue.main.async {
            self.isProcessing = true
        }

        visionQueue.async { [weak self] in
            self?.processFrame(pixelBuffer)
        }
    }

    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        defer { finishProcessing() }

        frameIndex += 1
        let now = Date()

        if handleStaleIfNeeded(now: now) {
            return
        }

        if shouldSkipFrame() {
            return
        }

        do {
            let observations = try backend.detectHands(in: pixelBuffer)
            guard !observations.isEmpty else {
                handleNoObservation()
                return
            }

            lastValidDetectionTime = now

            var candidates: [(gesture: Gesture, confidence: Float)] = []
            var gestureObservations: [HandObservation] = []

            for observation in observations {
                let result = classifyGesture(from: observation)
                if result.isValid {
                    gestureObservations.append(observation)
                }
                if result.isValid, result.gesture != .none {
                    candidates.append((gesture: result.gesture, confidence: result.confidence))
                }
            }

            if gestureObservations.isEmpty {
                stableGesture = .none
                stableGestureFrames = 0
                DispatchQueue.main.async {
                    self.resetGesture()
                }
            } else {
                let selectedGesture: Gesture
                let selectedConfidence: Float

                let fiveFingerCandidates = candidates.filter { $0.gesture == .fiveFingers }
                if fiveFingerCandidates.count >= 2 {
                    selectedGesture = .doubleOpenHands
                    let first = fiveFingerCandidates[0].confidence
                    let second = fiveFingerCandidates[1].confidence
                    selectedConfidence = min(first, second)
                } else if let bestCandidate = selectBestCandidate(from: candidates) {
                    selectedGesture = bestCandidate.gesture
                    selectedConfidence = bestCandidate.confidence
                } else {
                    selectedGesture = .none
                    selectedConfidence = 0
                }

                updateStability(for: selectedGesture, confidence: selectedConfidence)
                DispatchQueue.main.async {
                    self.updateGesture(selectedGesture, confidence: selectedConfidence)
                }
            }

            let actionObservations = observations.filter {
                ($0.joints[.wrist]?.confidence ?? 0) >= Float(settings.gestureSensitivity)
            }
            if let primaryHand = selectPrimaryHand(from: actionObservations),
               let action = actionDetector.detectAction(from: primaryHand, at: now) {
                DispatchQueue.main.async {
                    self.onActionDetected?(action)
                }
            }
        } catch {
            print("Hand detection failed: \(error)")
            handleNoObservation()
        }
    }

    /// Classify the gesture based on hand pose observation
    private func classifyGesture(from observation: HandObservation) -> (gesture: Gesture, confidence: Float, isValid: Bool) {
        guard let thumbTip = observation.joints[.thumbTip],
              let thumbIP = observation.joints[.thumbIP],
              let indexTip = observation.joints[.indexTip],
              let indexPIP = observation.joints[.indexPIP],
              let middleTip = observation.joints[.middleTip],
              let middlePIP = observation.joints[.middlePIP],
              let ringTip = observation.joints[.ringTip],
              let ringPIP = observation.joints[.ringPIP],
              let littleTip = observation.joints[.littleTip],
              let littlePIP = observation.joints[.littlePIP] else {
            return (.none, 0, false)
        }

        let minConfidence = Float(settings.gestureSensitivity)
        guard thumbTip.confidence > minConfidence,
              indexTip.confidence > minConfidence,
              middleTip.confidence > minConfidence else {
            return (.none, 0, false)
        }

        let thumbExtended = thumbTip.location.y > thumbIP.location.y + 0.05
        let thumbDown = thumbTip.location.y < thumbIP.location.y - 0.05
        let indexExtended = indexTip.location.y > indexPIP.location.y + 0.03
        let middleExtended = middleTip.location.y > middlePIP.location.y + 0.03
        let ringExtended = ringTip.location.y > ringPIP.location.y + 0.03
        let littleExtended = littleTip.location.y > littlePIP.location.y + 0.03

        let detectedGesture: Gesture
        let confidence: Float

        if thumbExtended && !indexExtended && !middleExtended && !ringExtended && !littleExtended {
            detectedGesture = .thumbsUp
            confidence = thumbTip.confidence
        } else if thumbDown && !indexExtended && !middleExtended && !ringExtended && !littleExtended {
            detectedGesture = .thumbsDown
            confidence = thumbTip.confidence
        } else if !thumbExtended && !thumbDown && !indexExtended && !middleExtended && !ringExtended && littleExtended {
            detectedGesture = .pinkyUp
            confidence = littleTip.confidence
        } else if thumbExtended && indexExtended && middleExtended && ringExtended && littleExtended {
            detectedGesture = .fiveFingers
            confidence = (thumbTip.confidence + indexTip.confidence + middleTip.confidence + ringTip.confidence + littleTip.confidence) / 5
        } else if !thumbExtended && indexExtended && middleExtended && ringExtended && littleExtended {
            detectedGesture = .fourFingers
            confidence = (indexTip.confidence + middleTip.confidence + ringTip.confidence + littleTip.confidence) / 4
        } else if !indexExtended && !middleExtended && !ringExtended && !littleExtended {
            detectedGesture = .closedFist
            confidence = 0.8
        } else if indexExtended && !middleExtended && !ringExtended && !littleExtended {
            detectedGesture = .oneFingerUp
            confidence = indexTip.confidence
        } else if indexExtended && middleExtended && !ringExtended && !littleExtended {
            detectedGesture = .peaceSign
            confidence = (indexTip.confidence + middleTip.confidence) / 2
        } else if indexExtended && middleExtended && ringExtended && !littleExtended {
            detectedGesture = .threeFingers
            confidence = (indexTip.confidence + middleTip.confidence + ringTip.confidence) / 3
        } else {
            detectedGesture = .none
            confidence = 0
        }

        return (detectedGesture, confidence, true)
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

    private func updateStability(for gesture: Gesture, confidence: Float) {
        let minConfidence = Float(settings.gestureSensitivity)
        guard gesture != .none, confidence >= minConfidence else {
            stableGesture = .none
            stableGestureFrames = 0
            return
        }

        if gesture == stableGesture {
            stableGestureFrames += 1
        } else {
            stableGesture = gesture
            stableGestureFrames = 1
        }
    }

    private func shouldSkipFrame() -> Bool {
        guard stableGestureFrames >= stableFrameThreshold else { return false }
        let skipInterval = frameSkipWhenStable + 1
        return frameIndex % skipInterval != 0
    }

    private func handleStaleIfNeeded(now: Date) -> Bool {
        guard let lastValidDetectionTime = lastValidDetectionTime else { return false }
        if now.timeIntervalSince(lastValidDetectionTime) > staleTimeout {
            handleNoObservation()
            return true
        }
        return false
    }

    private func handleNoObservation() {
        lastValidDetectionTime = nil
        stableGesture = .none
        stableGestureFrames = 0
        backend.resetState()
        actionDetector.reset()
        DispatchQueue.main.async {
            self.resetGesture()
        }
    }

    private func selectBestCandidate(from candidates: [(gesture: Gesture, confidence: Float)]) -> (gesture: Gesture, confidence: Float)? {
        guard !candidates.isEmpty else { return nil }

        if stableGesture != .none {
            let stableCandidates = candidates.filter { $0.gesture == stableGesture }
            if let bestStable = stableCandidates.max(by: { $0.confidence < $1.confidence }) {
                return bestStable
            }
        }

        return candidates.max(by: { $0.confidence < $1.confidence })
    }

    private func selectPrimaryHand(from observations: [HandObservation]) -> HandObservation? {
        observations.max(by: { $0.overallConfidence < $1.overallConfidence })
    }

    private static func makeBackend(_ backend: DetectionBackend) -> HandLandmarkBackend {
        switch backend {
        case .vision:
            return VisionHandLandmarkBackend(maxHands: 2)
        case .mediaPipe:
            if let modelUrl = Bundle.main.url(forResource: "hand_landmarker", withExtension: "task", subdirectory: "Models") {
                if let backend = try? MediaPipeHandLandmarkBackend(maxHands: 2, modelPath: modelUrl.path) {
                    return backend
                }
            }
            print("MediaPipe backend unavailable, falling back to Vision.")
            return VisionHandLandmarkBackend(maxHands: 2)
        }
    }

    private func observeSettings() {
        settings.$detectionBackend
            .removeDuplicates()
            .sink { [weak self] backend in
                guard let self else { return }
                self.visionQueue.async {
                    self.backend = GestureDetector.makeBackend(backend)
                    self.handleNoObservation()
                }
            }
            .store(in: &cancellables)
    }

    private func finishProcessing() {
        DispatchQueue.main.async {
            self.isProcessing = false
        }
        processingSemaphore.signal()
    }
}
