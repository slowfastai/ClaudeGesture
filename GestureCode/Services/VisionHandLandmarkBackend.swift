import CoreGraphics
import CoreVideo
import Vision

final class VisionHandLandmarkBackend: HandLandmarkBackend {
    let maxHands: Int

    private let sequenceHandler = VNSequenceRequestHandler()
    private let handPoseRequest = VNDetectHumanHandPoseRequest()

    private var trackingObservations: [VNDetectedObjectObservation] = []
    private var lastFullDetectionFrame = 0
    private let fullDetectionInterval = 10
    private let trackingConfidenceThreshold: Float = 0.5
    private let roiPaddingRatio: CGFloat = 0.15
    private var frameIndex = 0

    init(maxHands: Int = 2) {
        self.maxHands = maxHands
        handPoseRequest.maximumHandCount = maxHands
    }

    func detectHands(in pixelBuffer: CVPixelBuffer) throws -> [HandObservation] {
        frameIndex += 1

        let shouldRefreshFullDetection = frameIndex - lastFullDetectionFrame >= fullDetectionInterval
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

        try sequenceHandler.perform([handPoseRequest], on: pixelBuffer)

        guard let observations = handPoseRequest.results as? [VNHumanHandPoseObservation],
              !observations.isEmpty else {
            trackingObservations = []
            return []
        }

        trackingObservations = observations.compactMap { observation in
            guard let boundingBox = handBoundingBox(from: observation) else { return nil }
            return VNDetectedObjectObservation(boundingBox: boundingBox)
        }
        if trackingObservations.count > maxHands {
            trackingObservations = Array(trackingObservations.prefix(maxHands))
        }
        if useFullDetection {
            lastFullDetectionFrame = frameIndex
        }

        return observations.map { toHandObservation($0) }
    }

    func resetState() {
        trackingObservations = []
        lastFullDetectionFrame = 0
        frameIndex = 0
    }

    private func toHandObservation(_ observation: VNHumanHandPoseObservation) -> HandObservation {
        var joints: [HandJoint: HandJointPoint] = [:]

        addPoint(.wrist, name: .wrist, from: observation, into: &joints)
        addPoint(.thumbTip, name: .thumbTip, from: observation, into: &joints)
        addPoint(.thumbIP, name: .thumbIP, from: observation, into: &joints)
        addPoint(.indexTip, name: .indexTip, from: observation, into: &joints)
        addPoint(.indexPIP, name: .indexPIP, from: observation, into: &joints)
        addPoint(.middleTip, name: .middleTip, from: observation, into: &joints)
        addPoint(.middlePIP, name: .middlePIP, from: observation, into: &joints)
        addPoint(.ringTip, name: .ringTip, from: observation, into: &joints)
        addPoint(.ringPIP, name: .ringPIP, from: observation, into: &joints)
        addPoint(.littleTip, name: .littleTip, from: observation, into: &joints)
        addPoint(.littlePIP, name: .littlePIP, from: observation, into: &joints)

        let confidences = joints.values.map { $0.confidence }
        let overallConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
        return HandObservation(joints: joints, overallConfidence: overallConfidence)
    }

    private func addPoint(
        _ joint: HandJoint,
        name: VNHumanHandPoseObservation.JointName,
        from observation: VNHumanHandPoseObservation,
        into joints: inout [HandJoint: HandJointPoint]
    ) {
        guard let point = try? observation.recognizedPoint(name) else { return }
        joints[joint] = HandJointPoint(location: point.location, confidence: point.confidence)
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

    private func handBoundingBox(from observation: VNHumanHandPoseObservation) -> CGRect? {
        do {
            let points = try observation.recognizedPoints(.all)
            let confidentPoints = points.values.filter { $0.confidence > 0 }
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
}
