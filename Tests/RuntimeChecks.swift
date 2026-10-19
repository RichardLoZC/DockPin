import AppKit
import ApplicationServices

@main struct RuntimeChecks {
    static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        guard AXIsProcessTrusted() else { print("SKIP: event-tap lifecycle requires this test process to have Accessibility permission"); return }
        let engine = LockEngine()
        // Empty geometry is deliberately inert: no input is suppressed or posted.
        precondition(engine.start(), "Could not start the real Quartz event tap")
        precondition(engine.isRunning)
        precondition(engine.start(), "Repeated start should preserve one live tap")
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        precondition(engine.suppressedEvents == 0, "An inert policy must not consume real input")
        engine.stop(); precondition(!engine.isRunning)
        engine.stop(); precondition(!engine.isRunning)
        precondition(engine.start(), "A stopped tap must be restartable")
        engine.stop(); precondition(!engine.isRunning)
        print("PASS: native event tap start, repeated start, inert input, stop, repeated stop, restart")
    }
}
