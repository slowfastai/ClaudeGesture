import Foundation
import Vision
import CoreGraphics

/// Detects action gestures from temporal hand motion paths
class ActionDetector: ObservableObject {
    @Published var currentAction: ActionGesture = .none
    @Published var detectionConfidence: Float = 0

    var onActionConfirmed: ((ActionGesture) -> Void)?

    private let settings = AppSettings.shared

    private struct TimedPoint {
        let time: TimeInterval
        let point: CGPoint
    }

    private struct TimedScalar {
        let time: TimeInterval
        let value: CGFloat
    }

    private var indexPath: [TimedPoint] = []
    private var pinchPath: [TimedPoint] = []
    private var centerPath: [TimedPoint] = []
    private var areaSeries: [TimedScalar] = []

    private var lastTriggerTime: Date?
    private var actionDisplayUntil: Date?

    // Thresholds
    private let pinchThreshold: CGFloat = 0.06
    private let dragLeftDistance: CGFloat = 0.15
    private let dragMaxYDrift: CGFloat = 0.08
    private let waveAmplitude: CGFloat = 0.12
    private let waveDirectionChanges = 2
    private let waveDeadzone: CGFloat = 0.01
    private let circleClosureThreshold: CGFloat = 0.08
    private let circleRoundnessStdRatio: CGFloat = 0.35
    private let circleMinPathLength: CGFloat = 0.5
    private let circleMinPoints = 10
    private let airTapAreaIncrease: CGFloat = 0.20
    private let airTapAreaDecrease: CGFloat = 0.15
    private let airTapMaxDuration: TimeInterval = 0.35
    private let airTapMaxHorizontalDrift: CGFloat = 0.10
    private let actionDisplayDuration: TimeInterval = 0.6

    func process(observations: [VNHumanHandPoseObservation], at time: Date) {
        guard settings.isEnabled, settings.actionDetectionEnabled else {
            reset()
            return
        }

        expireCurrentActionIfNeeded(now: time)

        let nowTime = time.timeIntervalSinceReferenceDate
        pruneTracking(before: nowTime - settings.actionWindowSeconds)

        guard let observation = selectBestObservation(from: observations) else {
            clearTracking()
            return
        }

        let minConfidence = Float(settings.gestureSensitivity)

        if let boundingBox = handBoundingBox(from: observation, minConfidence: minConfidence) {
            let center = CGPoint(x: boundingBox.midX, y: boundingBox.midY)
            centerPath.append(TimedPoint(time: nowTime, point: center))
            areaSeries.append(TimedScalar(time: nowTime, value: boundingBox.width * boundingBox.height))
        }

        if let indexTip = try? observation.recognizedPoint(.indexTip),
           indexTip.confidence >= minConfidence {
            indexPath.append(TimedPoint(time: nowTime, point: indexTip.location))

            if let thumbTip = try? observation.recognizedPoint(.thumbTip),
               thumbTip.confidence >= minConfidence {
                let pinchDistance = distance(indexTip.location, thumbTip.location)
                if pinchDistance < pinchThreshold {
                    let mid = CGPoint(
                        x: (indexTip.location.x + thumbTip.location.x) * 0.5,
                        y: (indexTip.location.y + thumbTip.location.y) * 0.5
                    )
                    pinchPath.append(TimedPoint(time: nowTime, point: mid))
                }
            }
        }

        if isInCooldown(now: time) {
            return
        }

        if detectAirTap(now: nowTime) {
            triggerAction(.airTap, confidence: 1.0, now: time)
        } else if detectBackHandWave() {
            triggerAction(.backHandWave, confidence: 1.0, now: time)
        } else if detectPinchDragLeft() {
            triggerAction(.pinchDragLeft, confidence: 1.0, now: time)
        } else if detectCircle() {
            triggerAction(.circle, confidence: 1.0, now: time)
        }
    }

    func reset() {
        clearTracking()
        lastTriggerTime = nil
        actionDisplayUntil = nil
        updateCurrentAction(.none, confidence: 0)
    }

    func shouldSuppressGestures(now: Date) -> Bool {
        guard settings.actionDetectionEnabled else { return false }
        if let until = actionDisplayUntil, now < until {
            return true
        }
        if let last = lastTriggerTime, now.timeIntervalSince(last) < settings.actionCooldown {
            return true
        }
        return false
    }

    private func isInCooldown(now: Date) -> Bool {
        guard let last = lastTriggerTime else { return false }
        return now.timeIntervalSince(last) < settings.actionCooldown
    }

    private func triggerAction(_ action: ActionGesture, confidence: Float, now: Date) {
        lastTriggerTime = now
        actionDisplayUntil = now.addingTimeInterval(actionDisplayDuration)
        clearTracking()
        updateCurrentAction(action, confidence: confidence)
        DispatchQueue.main.async { [weak self] in
            self?.onActionConfirmed?(action)
        }
    }

    private func expireCurrentActionIfNeeded(now: Date) {
        guard let until = actionDisplayUntil, now > until else { return }
        actionDisplayUntil = nil
        updateCurrentAction(.none, confidence: 0)
    }

    private func updateCurrentAction(_ action: ActionGesture, confidence: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.currentAction = action
            self?.detectionConfidence = confidence
        }
    }

    private func clearTracking() {
        indexPath.removeAll()
        pinchPath.removeAll()
        centerPath.removeAll()
        areaSeries.removeAll()
    }

    private func pruneTracking(before cutoff: TimeInterval) {
        indexPath.removeAll { $0.time < cutoff }
        pinchPath.removeAll { $0.time < cutoff }
        centerPath.removeAll { $0.time < cutoff }
        areaSeries.removeAll { $0.time < cutoff }
    }

    private func selectBestObservation(from observations: [VNHumanHandPoseObservation]) -> VNHumanHandPoseObservation? {
        guard !observations.isEmpty else { return nil }

        let minConfidence = Float(settings.gestureSensitivity)
        var best: (observation: VNHumanHandPoseObservation, confidence: Float)?

        for observation in observations {
            if let indexTip = try? observation.recognizedPoint(.indexTip),
               indexTip.confidence >= minConfidence {
                if let currentBest = best {
                    if indexTip.confidence > currentBest.confidence {
                        best = (observation, indexTip.confidence)
                    }
                } else {
                    best = (observation, indexTip.confidence)
                }
            }
        }

        return best?.observation ?? observations.first
    }

    private func handBoundingBox(from observation: VNHumanHandPoseObservation, minConfidence: Float) -> CGRect? {
        do {
            let points = try observation.recognizedPoints(.all)
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

    // MARK: - Detection

    private func detectAirTap(now: TimeInterval) -> Bool {
        let recentAreas = areaSeries.filter { $0.time >= now - airTapMaxDuration }
        guard recentAreas.count >= 3 else { return false }

        guard let first = recentAreas.first, let last = recentAreas.last else { return false }
        guard first.value > 0, last.value > 0 else { return false }

        guard let maxEntry = recentAreas.max(by: { $0.value < $1.value }) else { return false }
        if maxEntry.time == first.time || maxEntry.time == last.time {
            return false
        }

        let increased = maxEntry.value >= first.value * (1 + airTapAreaIncrease)
        let decreased = last.value <= maxEntry.value * (1 - airTapAreaDecrease)
        guard increased && decreased else { return false }

        let recentIndex = indexPath.filter { $0.time >= now - airTapMaxDuration }
        if recentIndex.count >= 2 {
            let minX = recentIndex.map { $0.point.x }.min() ?? 0
            let maxX = recentIndex.map { $0.point.x }.max() ?? 0
            if maxX - minX > airTapMaxHorizontalDrift {
                return false
            }
        }

        return true
    }

    private func detectBackHandWave() -> Bool {
        guard centerPath.count >= 6 else { return false }

        let xs = centerPath.map { $0.point.x }
        guard let minX = xs.min(), let maxX = xs.max() else { return false }
        guard (maxX - minX) >= waveAmplitude else { return false }

        var signChanges = 0
        var lastSign: CGFloat?
        for i in 1..<xs.count {
            let dx = xs[i] - xs[i - 1]
            if abs(dx) < waveDeadzone {
                continue
            }
            let sign: CGFloat = dx > 0 ? 1 : -1
            if let last = lastSign, sign != last {
                signChanges += 1
            }
            lastSign = sign
        }

        return signChanges >= waveDirectionChanges
    }

    private func detectPinchDragLeft() -> Bool {
        guard pinchPath.count >= 3 else { return false }

        guard let first = pinchPath.first, let last = pinchPath.last else { return false }
        let deltaX = first.point.x - last.point.x
        guard deltaX >= dragLeftDistance else { return false }

        let ys = pinchPath.map { $0.point.y }
        guard let minY = ys.min(), let maxY = ys.max() else { return false }
        if maxY - minY > dragMaxYDrift {
            return false
        }

        return true
    }

    private func detectCircle() -> Bool {
        guard indexPath.count >= circleMinPoints else { return false }

        guard let first = indexPath.first, let last = indexPath.last else { return false }
        guard distance(first.point, last.point) <= circleClosureThreshold else { return false }

        let pathLength = totalPathLength(indexPath.map { $0.point })
        guard pathLength >= circleMinPathLength else { return false }

        let centroid = averagePoint(indexPath.map { $0.point })
        let radii = indexPath.map { distance($0.point, centroid) }
        let mean = radii.reduce(0, +) / CGFloat(radii.count)
        guard mean > 0 else { return false }
        let variance = radii.reduce(0) { partial, radius in
            let diff = radius - mean
            return partial + diff * diff
        } / CGFloat(radii.count)
        let std = sqrt(variance)
        guard (std / mean) <= circleRoundnessStdRatio else { return false }

        return true
    }

    // MARK: - Geometry

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func totalPathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var length: CGFloat = 0
        for i in 1..<points.count {
            length += distance(points[i - 1], points[i])
        }
        return length
    }

    private func averagePoint(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }
}
