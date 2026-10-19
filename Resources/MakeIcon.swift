import AppKit

let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 192, yRadius: 192)
        NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.40, blue: 0.90, alpha: 1),
                   ending: NSColor(srgbRed: 0.08, green: 0.16, blue: 0.42, alpha: 1))!.draw(in: background, angle: -90)
        NSColor.white.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: NSRect(x: 224, y: 224, width: 576, height: 130), xRadius: 42, yRadius: 42).fill()
        NSColor.white.setFill()
        for x in [270, 398, 526, 654] {
            NSBezierPath(roundedRect: NSRect(x: x, y: 250, width: 100, height: 78), xRadius: 22, yRadius: 22).fill()
        }
        // An original pushpin silhouette above a four-tile Dock.
        let pin = NSBezierPath()
        pin.move(to: NSPoint(x: 420, y: 748)); pin.line(to: NSPoint(x: 604, y: 748))
        pin.line(to: NSPoint(x: 584, y: 622)); pin.line(to: NSPoint(x: 654, y: 552))
        pin.curve(to: NSPoint(x: 638, y: 524), controlPoint1: NSPoint(x: 670, y: 536), controlPoint2: NSPoint(x: 654, y: 524))
        pin.line(to: NSPoint(x: 536, y: 524)); pin.line(to: NSPoint(x: 512, y: 402))
        pin.line(to: NSPoint(x: 488, y: 524)); pin.line(to: NSPoint(x: 386, y: 524))
        pin.curve(to: NSPoint(x: 370, y: 552), controlPoint1: NSPoint(x: 370, y: 524), controlPoint2: NSPoint(x: 354, y: 536))
        pin.line(to: NSPoint(x: 440, y: 622)); pin.close(); pin.fill()
        NSBezierPath(roundedRect: NSRect(x: 394, y: 730, width: 236, height: 60), xRadius: 24, yRadius: 24).fill()
        NSGraphicsContext.restoreGraphicsState()
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(filename))
    }
}
