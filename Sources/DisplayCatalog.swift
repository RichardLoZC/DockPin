import AppKit
import ApplicationServices

enum DisplayCatalog {
    static func read() -> [DisplayInfo] {
        NSScreen.screens.compactMap { screen in
            guard let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value,
                  CGDisplayMirrorsDisplay(id) == kCGNullDirectDisplay else { return nil }
            let bounds = CGDisplayBounds(id)
            guard !bounds.isNull, !bounds.isEmpty else { return nil }
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }
                ?? "display-\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))"
            return DisplayInfo(id: id, uuid: uuid, name: screen.localizedName, bounds: bounds, isMain: id == CGMainDisplayID())
        }.sorted { a, b in a.isMain != b.isMain ? a.isMain : a.id < b.id }
    }

    static var dockAtBottom: Bool {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        return (CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String ?? "bottom") == "bottom"
    }

    static var dockPID: pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
    }
}

/// Read window metadata, never screen pixels or another app's document titles.
/// On macOS 27 the Dock's level-20 window covers the entire owning display.
/// Testing for a short rectangular bar would misidentify it.
final class DockLocator {
    private var cachedID: CGWindowID?

    func bounds() -> CGRect? {
        guard let pid = DisplayCatalog.dockPID else { cachedID = nil; return nil }
        let level = Int(CGWindowLevelForKey(.dockWindow))
        func candidate(_ window: [String: Any]) -> CGRect? {
            guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
                  (window[kCGWindowLayer as String] as? Int) == level,
                  let dictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: dictionary as CFDictionary), !rect.isEmpty else { return nil }
            return rect
        }
        if let cachedID,
           let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, cachedID) as? [[String: Any]],
           let window = windows.first, (window[kCGWindowNumber as String] as? UInt32) == cachedID,
           let rect = candidate(window) { return rect }
        cachedID = nil
        for options: CGWindowListOption in [[.optionOnScreenOnly, .excludeDesktopElements], .optionAll] {
            let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
            let matches = windows.compactMap { w -> (CGWindowID, CGRect)? in
                guard let id = w[kCGWindowNumber as String] as? UInt32, let r = candidate(w) else { return nil }
                return (id, r)
            }
            if let match = matches.max(by: { $0.1.width * $0.1.height < $1.1.width * $1.1.height }) {
                cachedID = match.0; return match.1
            }
        }
        return nil
    }

    func display(in policy: DockPolicy) -> DisplayInfo? {
        bounds().flatMap { policy.display(intersecting: $0) }
    }
}
