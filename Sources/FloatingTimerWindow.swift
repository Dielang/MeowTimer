import AppKit
import SwiftUI
import Combine

/// Catime 风格的透明悬浮倒计时窗：置顶、可拖动、半透明黑底。
final class FloatingTimerWindow: NSObject, NSWindowDelegate {
    private let engine: TimerEngine
    private let panel: NSPanel
    private var cancellables = Set<AnyCancellable>()
    private let frameKey = "meow.floatingFrame"

    init(engine: TimerEngine) {
        self.engine = engine
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 170),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: FloatingTimerView(engine: engine))

        restoreFrame()
        observe()
        syncVisibility()
    }

    var isPanelVisible: Bool { panel.isVisible }

    // MARK: - 显示/隐藏

    private func observe() {
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.syncVisibility() }
            .store(in: &cancellables)
    }

    private func syncVisibility() {
        let shouldShow = engine.floatingEnabled && engine.state != .idle
        if shouldShow {
            if !panel.isVisible {
                panel.orderFrontRegardless()
            }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    // MARK: - 位置

    private func restoreFrame() {
        if let saved = UserDefaults.standard.string(forKey: frameKey) {
            let rect = NSRectFromString(saved)
            if rect.width > 10, rect.height > 10,
               NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
                panel.setFrame(rect, display: false)
                return
            }
        }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 32, y: screen.minY + 48))
    }

    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }
}

/// 悬浮窗内容。
struct FloatingTimerView: View {
    @ObservedObject var engine: TimerEngine

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 10) {
                Text(engine.state == .finished ? "时间到！" : TimerEngine.formatted(engine.remaining))
                    .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(engine.state == .finished ? Color.orange : Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                if engine.total > 0 {
                    ProgressView(value: engine.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.white.opacity(0.85))
                        .frame(width: 220)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.45))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )

            Button {
                engine.floatingEnabled = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.45))
            }
            .buttonStyle(.plain)
            .padding(9)
            .help("关闭悬浮窗")
        }
    }
}
