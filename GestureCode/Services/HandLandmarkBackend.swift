import CoreVideo
import Foundation

protocol HandLandmarkBackend {
    var maxHands: Int { get }
    func detectHands(in pixelBuffer: CVPixelBuffer) throws -> [HandObservation]
    func resetState()
}

enum DetectionBackend: String, CaseIterable {
    case vision
    case mediaPipe

    var displayName: String {
        switch self {
        case .vision:
            return "Vision"
        case .mediaPipe:
            return "MediaPipe"
        }
    }
}
