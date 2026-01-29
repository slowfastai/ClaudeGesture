import Vision
import Combine
import Foundation

/// Detects hand gestures from camera frames using Vision framework
class GestureDetector: ObservableObject {
    @Published var currentGesture: Gesture = .none
    @Published var detectionConfidence: Float = 0.0
    @Published var isProcessing = false

    private let settings = AppSettings.shared

    private let visionQueue = DispatchQueue(label: "com.gesturecode.vision")
    private let processingSemaphore = DispatchSemaphore(value: 1)
    private let sequenceHandler = VNSequenceRequestHandler()
    private let handPoseRequest = VNDetectHumanHandPoseRequest()

    private var frameIndex = 0
    private var stableGesture: Gesture = .none
    private var stableGestureFrames = 0
    private let stableFrameThreshold = 5
    private let frameSkipWhenStable = 2
    private let staleTimeout: TimeInterval = 0.4
    private var lastValidDetectionTime: Date?
    private var trackingObservations: [VNDetectedObjectObservation] = []
    private var lastFullDetectionFrame = 0
    private let fullDetectionInterval = 10
    private let trackingConfidenceThreshold: Float = 0.5
    private let roiPaddingRatio: CGFloat = 0.15

    // Debouncing
    private var lastGesture: Gesture = .none
    private var gestureStartTime: Date?
    private var lastTriggerTime: Date?

    /// Callback when a gesture is confirmed (held for required duration)
    var onGestureConfirmed: ((Gesture) -> Void)?

    init() {
        handPoseRequest.maximumHandCount = 2
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

        let shouldRefreshFullDetection = frameIndex - lastFullDetectionFrame >= fullDetectionInterval
        if shouldSkipFrame(forceFullDetection: shouldRefreshFullDetection) {
            return
        }

        var useFullDetection = shouldRefreshFullDetection || trackingObservations.isEmpty
        var roi: CGRect?

        if !useFullDetection {
            var updatedObservations: [VNDetectedObjectObservation] = []
            for observation in trackingObservations {
                if let updatedObservation = performTracking(on: pixelBuffer, observation: observation),
                   updatedObservation.confidence >= trackingConfidenceThreshold {
                    updatedObservations.append(updatedObservation)
                }
            }

            if updatedObservations.isEmpty {
                trackingObservations = []
                useFullDetection = true
            } else {
                trackingObservations = updatedObservations
                let boxes = updatedObservations.map { $0.boundingBox }
                roi = unionRegion(for: boxes)
            }
        }

        if useFullDetection {
            handPoseRequest.regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
        } else if let roi = roi {
            handPoseRequest.regionOfInterest = roi
        }

        do {
            try sequenceHandler.perform([handPoseRequest], on: pixelBuffer)

            guard let observations = handPoseRequest.results as? [VNHumanHandPoseObservation],
                  !observations.isEmpty else {
                handleNoObservation()
                return
            }

            var candidates: [(gesture: Gesture, confidence: Float)] = []
            var validObservations: [VNHumanHandPoseObservation] = []

            for observation in observations {
                let result = classifyGesture(from: observation)
                if result.isValid {
                    validObservations.append(observation)
                }
                if result.isValid, result.gesture != .none {
                    candidates.append((gesture: result.gesture, confidence: result.confidence))
                }
            }

            guard !validObservations.isEmpty else {
                handleNoObservation()
                return
            }

            lastValidDetectionTime = now
            trackingObservations = validObservations.compactMap { observation in
                guard let boundingBox = handBoundingBox(from: observation) else { return nil }
                return VNDetectedObjectObservation(boundingBox: boundingBox)
            }
            if trackingObservations.count > 2 {
                trackingObservations = Array(trackingObservations.prefix(2))
            }
            if useFullDetection {
                lastFullDetectionFrame = frameIndex
            }

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
        } catch {
            print("Vision request failed: \(error)")
            handleNoObservation()
        }
    }

    /// Classify the gesture based on hand pose observation
    private func classifyGesture(from observation: VNHumanHandPoseObservation) -> (gesture: Gesture, confidence: Float, isValid: Bool) {
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

            // Check confidence threshold
            let minConfidence = Float(settings.gestureSensitivity)
            guard thumbTip.confidence > minConfidence,
                  indexTip.confidence > minConfidence,
                  middleTip.confidence > minConfidence else {
                return (.none, 0, false)
            }

            // Determine which fingers are extended
            let thumbExtended = thumbTip.y > thumbIP.y + 0.05
            let thumbDown = thumbTip.y < thumbIP.y - 0.05
            let indexExtended = indexTip.y > indexPIP.y + 0.03
            let middleExtended = middleTip.y > middlePIP.y + 0.03
            let ringExtended = ringTip.y > ringPIP.y + 0.03
            let littleExtended = littleTip.y > littlePIP.y + 0.03

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
            } else if !thumbExtended && !thumbDown && !indexExtended && !middleExtended && !ringExtended && littleExtended {
                // Pinky up: only little finger extended (thumb must be tucked)
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

            return (detectedGesture, confidence, true)

        } catch {
            print("Failed to get hand points: \(error)")
            return (.none, 0, false)
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

    private func shouldSkipFrame(forceFullDetection: Bool) -> Bool {
        guard !forceFullDetection else { return false }
        guard !trackingObservations.isEmpty else { return false }
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
        trackingObservations = []
        stableGesture = .none
        stableGestureFrames = 0
        lastFullDetectionFrame = 0
        DispatchQueue.main.async {
            self.resetGesture()
        }
    }

    private func performTracking(on pixelBuffer: CVPixelBuffer, observation: VNDetectedObjectObservation) -> VNDetectedObjectObservation? {
        let request = VNTrackObjectRequest(detectedObjectObservation: observation)
        request.trackingLevel = .fast
        do {
            try sequenceHandler.perform([request], on: pixelBuffer)
            return request.results?.first as? VNDetectedObjectObservation
        } catch {
            return nil
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

    private func handBoundingBox(from observation: VNHumanHandPoseObservation) -> CGRect? {
        do {
            let points = try observation.recognizedPoints(.all)
            let minConfidence = Float(settings.gestureSensitivity)
            let confidentPoints = points.values.filter { $0.confidence >= minConfidence }
            guard !confidentPoints.isEmpty else { return nil }

            var minX: CGFloat = 1
            var minY: CGFloat = 1
            var maxX: CGFloat = 0
            var maxY: CGFloat = 0

            for point in confidentPoints {
                minX = min(minX, CGFloat(point.location.x))
                minY = min(minY, CGFloat(point.location.y))
                maxX = max(maxX, CGFloat(point.location.x))
                maxY = max(maxY, CGFloat(point.location.y))
            }

            let width = max(0, maxX - minX)
            let height = max(0, maxY - minY)
            guard width > 0, height > 0 else { return nil }
            return CGRect(x: minX, y: minY, width: width, height: height)
        } catch {
            return nil
        }
    }

    private func unionRegion(for boxes: [CGRect]) -> CGRect {
        guard let first = boxes.first else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        var union = expandedRegion(for: first)
        for box in boxes.dropFirst() {
            union = union.union(expandedRegion(for: box))
        }

        return clampedRegion(union)
    }

    private func clampedRegion(_ rect: CGRect) -> CGRect {
        var clamped = rect
        clamped.origin.x = max(0, min(1, clamped.origin.x))
        clamped.origin.y = max(0, min(1, clamped.origin.y))
        clamped.size.width = min(1 - clamped.origin.x, clamped.size.width)
        clamped.size.height = min(1 - clamped.origin.y, clamped.size.height)
        if clamped.width <= 0 || clamped.height <= 0 {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        return clamped
    }

    private func expandedRegion(for boundingBox: CGRect) -> CGRect {
        let paddingX = boundingBox.width * roiPaddingRatio
        let paddingY = boundingBox.height * roiPaddingRatio
        var expanded = boundingBox.insetBy(dx: -paddingX, dy: -paddingY)
        expanded.origin.x = max(0, expanded.origin.x)
        expanded.origin.y = max(0, expanded.origin.y)
        expanded.size.width = min(1 - expanded.origin.x, expanded.size.width)
        expanded.size.height = min(1 - expanded.origin.y, expanded.size.height)
        if expanded.width <= 0 || expanded.height <= 0 {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }
        return expanded
    }

    private func finishProcessing() {
        DispatchQueue.main.async {
            self.isProcessing = false
        }
        processingSemaphore.signal()
    }
}
