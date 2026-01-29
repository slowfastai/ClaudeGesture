import CoreGraphics
import Foundation

final class HandActionDetector {
    private struct FrameSample {
        let time: Date
        let wrist: CGPoint
    }

    private let settings: AppSettings
    private var samples: [FrameSample] = []
    private var lastActionTime: Date?
    private var isPinched = false

    init(settings: AppSettings) {
        self.settings = settings
    }

    func reset() {
        samples.removeAll()
        lastActionTime = nil
        isPinched = false
    }

    func detectAction(from hand: HandObservation, at time: Date) -> HandAction? {
        guard let wristPoint = hand.joints[.wrist]?.location else { return nil }

        if let pinchAction = detectPinch(from: hand, at: time) {
            samples.removeAll()
            return pinchAction
        }

        samples.append(FrameSample(time: time, wrist: wristPoint))
        pruneSamples(keepingWithin: settings.swipeTimeWindow, now: time)

        return detectSwipe(at: time)
    }

    private func detectPinch(from hand: HandObservation, at time: Date) -> HandAction? {
        guard let thumb = hand.joints[.thumbTip]?.location,
              let index = hand.joints[.indexTip]?.location else {
            return nil
        }

        let pinchDistance = hypot(thumb.x - index.x, thumb.y - index.y)
        let pinchThreshold = CGFloat(settings.pinchThreshold)
        let pinchReleaseThreshold = CGFloat(settings.pinchReleaseThreshold)
        let canTrigger = canTriggerAction(at: time)

        if !isPinched, pinchDistance < pinchThreshold, canTrigger {
            isPinched = true
            lastActionTime = time
            return .pinch
        }

        if isPinched, pinchDistance > pinchReleaseThreshold {
            isPinched = false
        }

        return nil
    }

    private func detectSwipe(at time: Date) -> HandAction? {
        guard samples.count >= 2, canTriggerAction(at: time),
              let first = samples.first, let last = samples.last else {
            return nil
        }

        let dx = last.wrist.x - first.wrist.x
        let dy = last.wrist.y - first.wrist.y
        let swipeDistanceThreshold = CGFloat(settings.swipeDistanceThreshold)
        let swipeVerticalTolerance = CGFloat(settings.swipeVerticalTolerance)

        guard abs(dx) >= swipeDistanceThreshold,
              abs(dy) <= swipeVerticalTolerance else {
            return nil
        }

        lastActionTime = time
        samples.removeAll()
        return dx < 0 ? .swipeLeft : .swipeRight
    }

    private func pruneSamples(keepingWithin window: Double, now: Date) {
        samples = samples.filter { now.timeIntervalSince($0.time) <= window }
    }

    private func canTriggerAction(at time: Date) -> Bool {
        guard let lastActionTime else { return true }
        return time.timeIntervalSince(lastActionTime) >= settings.actionCooldown
    }
}
