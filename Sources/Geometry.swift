import Foundation
import CoreGraphics

/// All rectangles use Quartz desktop points: origin at the primary display's
/// top-left, y increasing downwards. Never mix these with NSScreen.frame.
struct DisplayInfo: Equatable {
    let id: UInt32
    let uuid: String
    let name: String
    let bounds: CGRect
    let isMain: Bool
}

struct DockPolicy {
    let displays: [DisplayInfo]
    let preferredUUID: String? // nil means follow the system's main display.
    let edgeDepth: CGFloat = 4

    var target: DisplayInfo? {
        if let preferredUUID, let match = displays.first(where: { $0.uuid == preferredUUID }) { return match }
        return displays.first(where: \.isMain) ?? displays.first
    }

    var usingFallback: Bool {
        preferredUUID != nil && !displays.contains(where: { $0.uuid == preferredUUID })
    }

    func suppresses(_ point: CGPoint, bypass: Bool = false) -> Bool {
        guard !bypass, point.x.isFinite, point.y.isFinite, displays.count > 1,
              let target, let display = displays.first(where: { $0.bounds.contains(point) }),
              display.id != target.id else { return false }
        return point.y >= display.bounds.maxY - edgeDepth
    }

    /// Exclude portions of the bottom edge that lead into another display.
    /// The remaining segment must have room for a point away from hot corners.
    func summonPoint(for display: DisplayInfo) -> CGPoint? {
        var segments: [ClosedRange<CGFloat>] = [display.bounds.minX...display.bounds.maxX]
        let y = display.bounds.maxY
        for other in displays where other.id != display.id && other.bounds.minY <= y + 1 && other.bounds.maxY > y - 1 {
            let lo = other.bounds.minX, hi = other.bounds.maxX
            segments = segments.flatMap { segment -> [ClosedRange<CGFloat>] in
                guard hi > segment.lowerBound, lo < segment.upperBound else { return [segment] }
                var rest: [ClosedRange<CGFloat>] = []
                if lo > segment.lowerBound { rest.append(segment.lowerBound...min(lo, segment.upperBound)) }
                if hi < segment.upperBound { rest.append(max(hi, segment.lowerBound)...segment.upperBound) }
                return rest
            }
        }
        guard let segment = segments.filter({ $0.upperBound - $0.lowerBound >= 8 })
            .max(by: { $0.upperBound - $0.lowerBound < $1.upperBound - $1.lowerBound }) else { return nil }
        return CGPoint(x: (segment.lowerBound + segment.upperBound) / 2, y: y - 1)
    }

    func display(intersecting rect: CGRect) -> DisplayInfo? {
        guard !rect.isNull, !rect.isEmpty else { return nil }
        return displays.compactMap { display -> (DisplayInfo, CGFloat)? in
            let intersection = display.bounds.intersection(rect)
            guard !intersection.isNull, !intersection.isEmpty else { return nil }
            return (display, intersection.width * intersection.height)
        }.max(by: { $0.1 < $1.1 })?.0
    }
}
