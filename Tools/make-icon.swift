import AppKit

// 生成 1024x1024 的应用图标 PNG：橙色渐变圆角方块 + 白色计时器符号
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let inset: CGFloat = 64
let rect = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let path = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)

let gradient = NSGradient(colors: [
    NSColor(deviceRed: 1.00, green: 0.71, blue: 0.27, alpha: 1.0),
    NSColor(deviceRed: 0.96, green: 0.40, blue: 0.10, alpha: 1.0)
])!
gradient.draw(in: path, angle: -90)

NSColor.white.withAlphaComponent(0.16).setStroke()
path.lineWidth = 6
path.stroke()

if let symbol = NSImage(systemSymbolName: "timer", accessibilityDescription: nil)?
    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 540, weight: .semibold)) {
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    symbol.draw(in: NSRect(origin: .zero, size: symbol.size))
    NSColor.white.set()
    NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
    tinted.unlockFocus()

    let target = NSRect(
        x: (CGFloat(size) - tinted.size.width) / 2,
        y: (CGFloat(size) - tinted.size.height) / 2,
        width: tinted.size.width,
        height: tinted.size.height
    )
    tinted.draw(in: target)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("icon render failed\n".utf8))
    exit(1)
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
do {
    try png.write(to: URL(fileURLWithPath: output))
    print("wrote \(output)")
} catch {
    FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
    exit(1)
}
