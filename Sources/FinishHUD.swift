import AppKit
import SwiftUI

/// 时间到之后屏幕中央的提示窗。
enum FinishHUD {
    private final class Box {
        weak var panel: NSPanel?
    }

    private static var current: NSPanel?

    static var isVisible: Bool { current?.isVisible ?? false }

    static func show(message: String) {
        current?.orderOut(nil)

        let box = Box()
        let view = FinishHUDView(message: message) {
            box.panel?.orderOut(nil)
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 190),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: view)
        box.panel = panel
        current = panel

        if let screen = NSScreen.main {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: screen.frame.midX - size.width / 2,
                y: screen.frame.midY - size.height / 2
            ))
        }
        panel.orderFrontRegardless()

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak panel] in
            panel?.orderOut(nil)
        }
    }
}

struct FinishHUDView: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("⏰")
                .font(.system(size: 38))
            Text(message)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("点击关闭")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(26)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
    }
}
