import AppKit
import ApplicationServices

/// The tap runs on the main run loop, in common modes, including menu tracking.
/// The callback only consults cached geometry; no IO or AX calls on the input path.
final class LockEngine {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var policy = DockPolicy(displays: [], preferredUUID: nil)
    private(set) var suppressedEvents: UInt64 = 0
    private(set) var timeoutCount = 0
    var onUnexpectedDisable: (() -> Void)?

    var isRunning: Bool { tap.map { CFMachPortIsValid($0) && CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func start() -> Bool {
        if isRunning { return true }
        stop()
        let mask = [CGEventType.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, context in
                    guard let context else { return Unmanaged.passUnretained(event) }
                    let engine = Unmanaged<LockEngine>.fromOpaque(context).takeUnretainedValue()
                    if type == .tapDisabledByTimeout {
                        engine.timeoutCount += 1
                        if let tap = engine.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                        return Unmanaged.passUnretained(event)
                    }
                    if type == .tapDisabledByUserInput {
                        DispatchQueue.main.async { engine.onUnexpectedDisable?() }
                        return Unmanaged.passUnretained(event)
                    }
                    if engine.policy.suppresses(event.location, bypass: event.flags.contains(.maskAlternate)) {
                        engine.suppressedEvents &+= 1
                        return nil
                    }
                    return Unmanaged.passUnretained(event)
                }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        guard let newSource = CFMachPortCreateRunLoopSource(nil, newTap, 0) else {
            CFMachPortInvalidate(newTap); return false
        }
        tap = newTap; source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        return isRunning
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil; source = nil
    }

    deinit { stop() }
}

/// Explicit one-shot relocation. Never moves the pointer automatically in the
/// background. Stops if the user takes over, a button is held, or geometry changes.
final class DockMover {
    static let eventTag: Int64 = 0x44504E4D4F5645
    private var timer: Timer?
    private var original: CGPoint?
    private var expected: CGPoint?
    private var snapshot: [DisplayInfo] = []
    private var step = 0
    private var target: DisplayInfo?
    private var edge: CGPoint?
    private var completion: ((String?) -> Void)?
    private var inputTap: CFMachPort?
    private var inputSource: CFRunLoopSource?
    private var takeover = PointerTakeover()
    private let eventSource = CGEventSource(stateID: .hidSystemState)
    private let locator = DockLocator()
    var isMoving: Bool { timer != nil }

    func start(policy: DockPolicy, completion: @escaping (String?) -> Void) {
        cancel()
        guard AXIsProcessTrusted(), let target = policy.target,
              let edge = policy.summonPoint(for: target), let point = CGEvent(source: nil)?.location else {
            completion("无法归位。请确认辅助功能权限，并让目标屏底边露出一段。")
            return
        }
        guard !Self.buttonsDown else { completion("请先松开鼠标按键。也可以直接在目标屏底边向下推动鼠标。") ; return }
        if locator.display(in: policy)?.id == target.id { completion(nil); return }
        self.target = target; self.edge = edge; snapshot = policy.displays
        original = point; expected = CGPoint(x: edge.x, y: edge.y - 14)
        self.completion = completion; step = 0
        takeover = PointerTakeover()
        guard watchForUserInput() else {
            finish("无法监测鼠标接管，已取消自动归位。请在目标屏底边手动唤出 Dock。", restore: false)
            return
        }
        eventSource?.localEventsSuppressionInterval = 0
        post(expected!, delta: 0)
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer; RunLoop.main.add(timer, forMode: .common)
    }

    private func tick() {
        guard let expected, let edge, let target else { finish("归位已取消。", restore: false); return }
        guard !takeover.interrupted, AXIsProcessTrusted(), DisplayCatalog.read() == snapshot, !Self.buttonsDown,
              let current = CGEvent(source: nil)?.location,
              hypot(current.x - expected.x, current.y - expected.y) <= 18 else {
            finish("归位已中止，鼠标由你控制。可在目标屏底边手动唤出 Dock。", restore: false); return
        }
        step += 1
        let policy = DockPolicy(displays: snapshot, preferredUUID: target.uuid)
        if step % 4 == 0, locator.display(in: policy)?.id == target.id { finish(nil, restore: true); return }
        if step >= 60 { finish("系统暂未移动 Dock。请退出调度中心，或在目标屏底边向下推动鼠标。", restore: true); return }
        let next = CGPoint(x: edge.x, y: step <= 7 ? edge.y - CGFloat(7-step)*2 : edge.y)
        self.expected = next; post(next, delta: 2)
    }

    private func post(_ point: CGPoint, delta: Int64) {
        guard let event = CGEvent(mouseEventSource: eventSource, mouseType: .mouseMoved,
                                  mouseCursorPosition: point, mouseButton: .left) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
        event.setIntegerValueField(.mouseEventDeltaY, value: delta)
        event.post(tap: .cghidEventTap)
    }

    private func finish(_ message: String?, restore: Bool) {
        timer?.invalidate(); timer = nil
        stopWatchingInput()
        // Warping emits no movement event, so restoring into a blocked edge
        // neither gets swallowed by our own filter nor summons the other Dock.
        if restore, let original, !Self.buttonsDown { CGWarpMouseCursorPosition(original) }
        self.original = nil; expected = nil; target = nil
        let callback = completion; completion = nil; callback?(message)
    }

    func cancel() {
        // Do not warp back during Quit, display changes, sleep, or user takeover.
        timer?.invalidate(); timer = nil; completion = nil
        stopWatchingInput()
        original = nil; expected = nil; target = nil
    }

    private func watchForUserInput() -> Bool {
        // Remember clicks even when down+up both occur between timer ticks.
        // No key events are requested, and this observer never consumes input.
        let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                                   .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .listenOnly, eventsOfInterest: mask, callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let mover = Unmanaged<DockMover>.fromOpaque(context).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    mover.takeover.interrupt()
                } else {
                    mover.takeover.observe(ownEvent: event.getIntegerValueField(.eventSourceUserData) == DockMover.eventTag,
                        buttonDown: type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown,
                        delta: CGPoint(x: CGFloat(event.getIntegerValueField(.mouseEventDeltaX)),
                                       y: CGFloat(event.getIntegerValueField(.mouseEventDeltaY))),
                        location: event.location, expected: mover.expected)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return false }
        guard let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else { CFMachPortInvalidate(tap); return false }
        inputTap = tap; inputSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        return true
    }

    private func stopWatchingInput() {
        if let inputTap { CFMachPortInvalidate(inputTap) }
        if let inputSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), inputSource, .commonModes) }
        inputTap = nil; inputSource = nil
    }

    static var buttonsDown: Bool {
        (0..<8).contains { CGEventSource.buttonState(.combinedSessionState, button: CGMouseButton(rawValue: UInt32($0))!) }
    }

    deinit { timer?.invalidate(); stopWatchingInput() }
}
