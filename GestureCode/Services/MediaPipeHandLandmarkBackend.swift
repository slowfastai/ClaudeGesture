import CoreGraphics
import CoreVideo
import Foundation

#if canImport(MediaPipeTasksVision)
import MediaPipeTasksVision
#endif

enum MediaPipeBackendError: Error {
    case frameworkUnavailable
    case modelNotFound
    case invalidModel
    case initializationFailed
}

final class MediaPipeHandLandmarkBackend: HandLandmarkBackend {
    let maxHands: Int

#if canImport(MediaPipeTasksVision)
    private let handLandmarker: HandLandmarker
#endif

    init(maxHands: Int = 2, modelPath: String) throws {
        self.maxHands = maxHands

#if canImport(MediaPipeTasksVision)
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw MediaPipeBackendError.modelNotFound
        }
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: modelPath)[.size] as? NSNumber)?.intValue ?? 0
        guard fileSize > 1024 else { throw MediaPipeBackendError.invalidModel }

        let options = HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.numHands = maxHands
        options.runningMode = .image

        guard let landmarker = try? HandLandmarker(options: options) else {
            throw MediaPipeBackendError.initializationFailed
        }
        handLandmarker = landmarker
#else
        throw MediaPipeBackendError.frameworkUnavailable
#endif
    }

    func detectHands(in pixelBuffer: CVPixelBuffer) throws -> [HandObservation] {
#if canImport(MediaPipeTasksVision)
        let mpImage = try MPImage(pixelBuffer: pixelBuffer)
        let result = try handLandmarker.detect(image: mpImage)
        guard let landmarks = result.landmarks, !landmarks.isEmpty else { return [] }

        return landmarks.map { landmarksForHand in
            var joints: [HandJoint: HandJointPoint] = [:]

            addPoint(.wrist, index: 0, from: landmarksForHand, into: &joints)
            addPoint(.thumbTip, index: 4, from: landmarksForHand, into: &joints)
            addPoint(.thumbIP, index: 3, from: landmarksForHand, into: &joints)
            addPoint(.indexTip, index: 8, from: landmarksForHand, into: &joints)
            addPoint(.indexPIP, index: 6, from: landmarksForHand, into: &joints)
            addPoint(.middleTip, index: 12, from: landmarksForHand, into: &joints)
            addPoint(.middlePIP, index: 10, from: landmarksForHand, into: &joints)
            addPoint(.ringTip, index: 16, from: landmarksForHand, into: &joints)
            addPoint(.ringPIP, index: 14, from: landmarksForHand, into: &joints)
            addPoint(.littleTip, index: 20, from: landmarksForHand, into: &joints)
            addPoint(.littlePIP, index: 18, from: landmarksForHand, into: &joints)

            let confidences = joints.values.map { $0.confidence }
            let overallConfidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
            return HandObservation(joints: joints, overallConfidence: overallConfidence)
        }
#else
        return []
#endif
    }

    func resetState() {
    }

#if canImport(MediaPipeTasksVision)
    private func addPoint(
        _ joint: HandJoint,
        index: Int,
        from landmarks: [NormalizedLandmark],
        into joints: inout [HandJoint: HandJointPoint]
    ) {
        guard landmarks.indices.contains(index) else { return }
        let landmark = landmarks[index]
        let location = CGPoint(x: CGFloat(landmark.x), y: CGFloat(1.0 - landmark.y))
        joints[joint] = HandJointPoint(location: location, confidence: 1.0)
    }
#endif
}
