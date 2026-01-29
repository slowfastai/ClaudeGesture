import CoreGraphics
import Foundation

enum HandJoint: CaseIterable {
    case wrist
    case thumbTip
    case thumbIP
    case indexTip
    case indexPIP
    case middleTip
    case middlePIP
    case ringTip
    case ringPIP
    case littleTip
    case littlePIP
}

struct HandJointPoint {
    let location: CGPoint
    let confidence: Float
}

struct HandObservation {
    let joints: [HandJoint: HandJointPoint]
    let overallConfidence: Float
}
