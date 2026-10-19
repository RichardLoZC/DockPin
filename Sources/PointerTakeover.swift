import CoreGraphics

/// Sticky cancellation: releasing a button before the next timer tick must
/// never erase the user's decision to take the pointer back.
struct PointerTakeover {
    private(set) var interrupted = false

    mutating func interrupt() { interrupted = true }

    mutating func observe(ownEvent: Bool, buttonDown: Bool, delta: CGPoint,
                          location: CGPoint, expected: CGPoint?) {
        guard !ownEvent else { return }
        if buttonDown || delta.x != 0 || delta.y != 0 {
            interrupted = true
        } else if let expected, hypot(location.x - expected.x, location.y - expected.y) > 2 {
            interrupted = true
        }
    }
}
