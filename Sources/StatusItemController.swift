import AppKit
import SwiftUI
import Combine

/// 菜单栏图标 + 左键弹面板 / 右键弹菜单。
final class StatusItemController: NSObject {
    private let engine: TimerEngine
    private let launchAtLogin: LaunchAtLogin
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()

    init(engine: TimerEngine, launchAtLogin: LaunchAtLogin) {
        self.engine = engine
        self.launchAtLogin = launchAtLogin
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureButton()
        configurePopover()
        observe()
        updateTitle()
    }

    // MARK: - 初始化

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "timer", accessibilityDescription: "喵时计时器")
        button.imagePosition = .imageLeading
        button.target = self
        button.action = #selector(handleClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        let hosting = NSHostingController(rootView: TimerPanelView(engine: engine, launchAtLogin: launchAtLogin))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.animates = true
    }

    private func observe() {
        engine.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateTitle() }
            .store(in: &cancellables)
    }

    // MARK: - 点击

    @objc private func handleClick() {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopoverIfNeeded()
        }
    }

    func showPopoverIfNeeded() {
        guard !popover.isShown, let button = statusItem.button else { return }
        launchAtLogin.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    // MARK: - 自检钩子（--smoke）

    var statusItemReady: Bool { statusItem.button != nil }
    var isPopoverShown: Bool { popover.isShown }
    var currentTitle: String { statusItem.button?.title ?? "" }

    @discardableResult
    func showPopoverForSmokeTest() -> Bool {
        showPopoverIfNeeded()
        return popover.isShown
    }

    // MARK: - 菜单栏标题

    private func updateTitle() {
        guard let button = statusItem.button else { return }
        switch engine.state {
        case .idle:
            button.image = symbol(for: engine.mode, description: "喵时")
            setTitle("")
        case .running:
            button.image = symbol(for: engine.mode, description: "计时中")
            setTitle(engine.menuShowsTime ? " " + TimerEngine.formatted(engine.remaining) : "")
        case .paused:
            button.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: "已暂停")
            setTitle(engine.menuShowsTime ? " " + TimerEngine.formatted(engine.remaining) : "")
        case .finished:
            // 结束后保持静态提示，不再在 00:00 / 时间到 之间反复切换
            button.image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: "时间到")
            setTitle(engine.menuShowsTime ? " 时间到" : "")
        }
    }

    private func symbol(for mode: TimerMode, description: String) -> NSImage? {
        let name = mode == .countup ? "stopwatch" : "timer"
        return NSImage(systemSymbolName: name, accessibilityDescription: description)
    }

    private func setTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize - 0.5, weight: .semibold)
        button.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
    }

    // MARK: - 右键菜单

    private func showContextMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: toggleMenuTitle, action: #selector(menuToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        if !(engine.mode == .countup && engine.isActive) {
            let countUpItem = NSMenuItem(title: "开始正计时（从 0 累计）", action: #selector(menuStartCountUp), keyEquivalent: "")
            countUpItem.target = self
            menu.addItem(countUpItem)
        }

        let resetItem = NSMenuItem(title: "重置", action: #selector(menuReset), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        let quickItem = NSMenuItem(title: "快速开始倒计时", action: nil, keyEquivalent: "")
        let quickMenu = NSMenu()
        for minutes in [5, 10, 25, 45, 60] {
            let item = NSMenuItem(title: "\(minutes) 分钟", action: #selector(menuQuickStart(_:)), keyEquivalent: "")
            item.tag = minutes
            item.target = self
            quickMenu.addItem(item)
        }
        quickItem.submenu = quickMenu
        menu.addItem(quickItem)

        menu.addItem(.separator())

        let floatingItem = NSMenuItem(title: "桌面悬浮窗", action: #selector(menuToggleFloating), keyEquivalent: "")
        floatingItem.state = engine.floatingEnabled ? .on : .off
        floatingItem.target = self
        menu.addItem(floatingItem)

        let menuTimeItem = NSMenuItem(title: "菜单栏显示时间", action: #selector(menuToggleMenuTime), keyEquivalent: "")
        menuTimeItem.state = engine.menuShowsTime ? .on : .off
        menuTimeItem.target = self
        menu.addItem(menuTimeItem)

        let loginItem = NSMenuItem(title: "开机自启", action: #selector(menuToggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = launchAtLogin.enabled ? .on : .off
        loginItem.target = self
        menu.addItem(loginItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "退出喵时", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    private var toggleMenuTitle: String {
        switch engine.state {
        case .running:
            return "暂停"
        case .paused:
            return "继续"
        case .finished:
            return "再来一次"
        case .idle:
            if engine.mode == .countup {
                return "开始正计时"
            }
            return "开始（上次 \(TimerEngine.formatted(engine.lastDuration))）"
        }
    }

    @objc private func menuToggle() { engine.startPause() }
    @objc private func menuStartCountUp() { engine.startCountUp() }
    @objc private func menuReset() { engine.reset() }
    @objc private func menuToggleFloating() { engine.floatingEnabled.toggle() }
    @objc private func menuToggleMenuTime() { engine.menuShowsTime.toggle() }
    @objc private func menuToggleLaunchAtLogin() { launchAtLogin.setEnabled(!launchAtLogin.enabled) }
    @objc private func menuQuit() { NSApp.terminate(nil) }
    @objc private func menuQuickStart(_ sender: NSMenuItem) {
        engine.start(seconds: TimeInterval(sender.tag * 60))
    }
}
