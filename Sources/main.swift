import AppKit
import ApplicationServices

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if CommandLine.arguments.contains("--diagnose") {
    let policy = DockPolicy(displays: DisplayCatalog.read(), preferredUUID: UserDefaults.standard.string(forKey: "targetUUID"))
    let report: [String: Any] = [
        "version": "1.0.0", "accessibility": AXIsProcessTrusted(),
        "dockAtBottom": DisplayCatalog.dockAtBottom,
        "separateSpaces": NSScreen.screensHaveSeparateSpaces,
        "dockDisplayID": DockLocator().display(in: policy)?.id as Any? ?? NSNull(),
        "targetDisplayID": policy.target?.id as Any? ?? NSNull(),
        "displays": policy.displays.map { d -> [String: Any] in
            ["id": d.id, "uuid": d.uuid, "name": d.name, "main": d.isMain,
             "bounds": [d.bounds.minX, d.bounds.minY, d.bounds.width, d.bounds.height],
             "bottomEdgeAvailable": policy.summonPoint(for: d) != nil]
        }
    ]
    let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
} else {
    let delegate = DockPinApp()
    app.delegate = delegate
    withExtendedLifetime(delegate) { app.run() }
}
