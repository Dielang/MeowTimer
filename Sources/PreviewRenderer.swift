import AppKit
import SwiftUI

/// `--render <目录>`：离屏渲染各个界面，用于构建时自检 UI。
enum PreviewRenderer {
    static func render(to directory: String) {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

        let suiteName = "meow.preview"
        let previewDefaults = UserDefaults(suiteName: suiteName)!
        previewDefaults.removePersistentDomain(forName: suiteName)
        let engine = TimerEngine(defaults: previewDefaults)
        let panelBackground = Color(nsColor: .windowBackgroundColor)

        save(
            TimerPanelView(engine: engine).background(panelBackground),
            path: directory + "/panel-idle.png"
        )
        save(
            TimerPanelView(engine: engine, showCustomEditor: true, hours: 1, minutes: 23, seconds: 30)
                .background(panelBackground),
            path: directory + "/panel-custom.png"
        )

        engine.start(seconds: 25 * 60)
        save(
            TimerPanelView(engine: engine).background(panelBackground),
            path: directory + "/panel-running.png"
        )
        save(
            FloatingTimerView(engine: engine).background(Color.gray),
            size: NSSize(width: 380, height: 170),
            path: directory + "/floating-running.png"
        )

        engine.pause()
        save(
            TimerPanelView(engine: engine).background(panelBackground),
            path: directory + "/panel-paused.png"
        )

        save(
            FinishHUDView(message: "时间到！", onDismiss: {}).background(Color.gray),
            size: NSSize(width: 320, height: 190),
            path: directory + "/hud-finished.png"
        )

        let countUp = TimerEngine(defaults: previewDefaults)
        countUp.startCountUp(target: 25 * 60)
        countUp.pause()
        countUp.debugSetElapsed(12 * 60 + 34)
        save(
            TimerPanelView(engine: countUp).background(panelBackground),
            path: directory + "/panel-countup.png"
        )
        save(
            FloatingTimerView(engine: countUp).background(Color.gray),
            size: NSSize(width: 380, height: 170),
            path: directory + "/floating-countup.png"
        )

        previewDefaults.removePersistentDomain(forName: suiteName)

        print("Preview images written to \(directory)")
    }

    private static func save<V: View>(_ view: V, size: NSSize? = nil, path: String) {
        let hosting = NSHostingView(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        let finalSize: NSSize
        if let size {
            finalSize = size
        } else {
            let fitting = hosting.fittingSize
            finalSize = NSSize(width: max(fitting.width, 1), height: max(fitting.height, 1))
        }
        hosting.frame = NSRect(origin: .zero, size: finalSize)
        window.setContentSize(finalSize)
        hosting.layoutSubtreeIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            print("FAILED bitmap for \(path)")
            return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("FAILED png for \(path)")
            return
        }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("wrote \(path) (\(Int(finalSize.width))x\(Int(finalSize.height)))")
        } catch {
            print("FAILED write \(path): \(error)")
        }
    }
}
