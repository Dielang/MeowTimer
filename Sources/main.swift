import AppKit
import Foundation

let arguments = CommandLine.arguments

if arguments.contains("--selftest") {
    SelfTest.run()
    exit(0)
}

if let index = arguments.firstIndex(of: "--render"), index + 1 < arguments.count {
    PreviewRenderer.render(to: arguments[index + 1])
    exit(0)
}

if arguments.contains("--login-test") {
    _ = NSApplication.shared
    LaunchAtLogin.probe()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
