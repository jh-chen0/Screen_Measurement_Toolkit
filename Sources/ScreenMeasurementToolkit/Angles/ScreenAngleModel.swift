import Foundation

/// Two rays with one shared vertex. The result covers both acute and obtuse angles.
struct ScreenAngle: Equatable {
    var vertex: CGPoint
    var first: CGPoint
    var second: CGPoint

    var degrees: CGFloat? {
        let ax = first.x - vertex.x, ay = first.y - vertex.y
        let bx = second.x - vertex.x, by = second.y - vertex.y
        let al = hypot(ax, ay), bl = hypot(bx, by)
        guard al >= 1, bl >= 1, [ax, ay, bx, by].allSatisfy({ $0.isFinite }) else { return nil }
        let ux = ax / al, uy = ay / al, vx = bx / bl, vy = by / bl
        return atan2(abs(ux * vy - uy * vx), ux * vx + uy * vy) * 180 / .pi
    }

    var firstBearing: CGFloat { atan2(first.y - vertex.y, first.x - vertex.x) }
    var secondBearing: CGFloat { atan2(second.y - vertex.y, second.x - vertex.x) }

    func translated(by delta: CGPoint) -> ScreenAngle {
        func move(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + delta.x, y: p.y + delta.y) }
        return ScreenAngle(vertex: move(vertex), first: move(first), second: move(second))
    }

    static func shortestTurn(from: CGFloat, to: CGFloat) -> CGFloat {
        atan2(sin(to - from), cos(to - from))
    }

    static func snap(_ point: CGPoint, around vertex: CGPoint) -> CGPoint {
        let distance = hypot(point.x - vertex.x, point.y - vertex.y)
        let bearing = atan2(point.y - vertex.y, point.x - vertex.x)
        let step = CGFloat.pi / 12
        let a = (bearing / step).rounded() * step
        return CGPoint(x: vertex.x + distance * cos(a), y: vertex.y + distance * sin(a))
    }
}

/// Only clicks advance the state. Pointer movement updates a preview without committing.
struct ScreenAngleConstruction {
    enum Stage { case vertex, firstEndpoint, secondEndpoint, finished }
    private(set) var stage: Stage = .vertex
    private(set) var vertex: CGPoint?
    private(set) var first: CGPoint?
    private(set) var pointer: CGPoint?
    private(set) var completed: ScreenAngle?

    var preview: ScreenAngle? {
        guard stage == .secondEndpoint, let vertex, let first, let pointer else { return nil }
        let angle = ScreenAngle(vertex: vertex, first: first, second: pointer)
        return angle.degrees == nil ? nil : angle
    }

    mutating func move(to point: CGPoint, snap: Bool = false) {
        guard point.x.isFinite, point.y.isFinite else { return }
        pointer = snap && vertex != nil ? ScreenAngle.snap(point, around: vertex!) : point
    }

    /// Returns a measurement on the third valid click, and never on a hover or drag.
    mutating func click(at point: CGPoint, snap: Bool = false) -> ScreenAngle? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        move(to: point, snap: snap)
        switch stage {
        case .vertex:
            vertex = point
            stage = .firstEndpoint
        case .firstEndpoint:
            guard let vertex, let pointer, hypot(pointer.x - vertex.x, pointer.y - vertex.y) >= 8 else { return nil }
            first = pointer
            stage = .secondEndpoint
        case .secondEndpoint:
            guard let vertex, let first, let pointer,
                  hypot(pointer.x - vertex.x, pointer.y - vertex.y) >= 8 else { return nil }
            let angle = ScreenAngle(vertex: vertex, first: first, second: pointer)
            guard angle.degrees != nil else { return nil }
            completed = angle
            stage = .finished
            return angle
        case .finished:
            break
        }
        return nil
    }
}
