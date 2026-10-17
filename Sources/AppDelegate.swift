import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: TimerEngine!
    private var launchAtLogin: LaunchAtLogin!
    private var statusController: StatusItemController!
    private var floatingWindow: FloatingTimerWindow!
    private var hotKeyManager: HotKeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        engine = Self.makeEngine()
        launchAtLogin = LaunchAtLogin()
        statusController = StatusItemController(engine: engine, launchAtLogin: launchAtLogin)
        floatingWindow = FloatingTimerWindow(engine: engine)
        hotKeyManager = HotKeyManager(engine: engine)

        engine.onFinish = { [weak self] in
            guard let self else { return }
            if self.engine.soundEnabled {
                NSSound(named: "Glass")?.play()
            }
            FinishHUD.show(message: "时间到！")
        }

        engine.onTargetReached = { [weak self] in
            guard let self else { return }
            if self.engine.soundEnabled {
                NSSound(named: "Glass")?.play()
            }
            FinishHUD.show(message: "已正计时 \(TimerEngine.formatted(self.engine.total))")
        }

        if CommandLine.arguments.contains("--smoke") {
            runSmokeTest()
            return
        }

        // 首次启动自动弹出一次面板，让用户知道图标点开有东西
        let launchedKey = "meow.hasLaunched"
        if !UserDefaults.standard.bool(forKey: launchedKey) {
            UserDefaults.standard.set(true, forKey: launchedKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.statusController.showPopoverIfNeeded()
            }
        }
    }

    // MARK: - 冒烟测试（构建自检用）

    /// 冒烟测试使用独立的 UserDefaults，避免污染真实用户设置。
    private static func makeEngine() -> TimerEngine {
        guard CommandLine.arguments.contains("--smoke") else {
            return TimerEngine()
        }
        let suiteName = "meow.smoke"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return TimerEngine(defaults: defaults)
    }

    private func runSmokeTest() {
        var failures = 0

        func check(_ condition: Bool, _ name: String) {
            if condition {
                print("PASS  \(name)")
            } else {
                failures += 1
                print("FAIL  \(name)")
            }
        }

        engine.soundEnabled = false
        engine.floatingEnabled = true
        engine.menuShowsTime = true
        check(statusController.statusItemReady, "status item created")
        check(floatingWindow.isPanelVisible == false, "floating window hidden while idle")
        check(hotKeyManager?.isRegistered == true, "global hotkey registered")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let shown = self.statusController.showPopoverForSmokeTest()
            check(shown, "popover shown")
            self.engine.start(seconds: 2)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            check(self.floatingWindow.isPanelVisible, "floating window visible while running")
            check(self.engine.state == .running, "engine running")
            check(!self.statusController.currentTitle.isEmpty, "menu bar shows countdown")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            check(self.engine.state == .finished, "engine finished at zero")
            check(FinishHUD.isVisible, "finish HUD visible")
            check(self.statusController.currentTitle.contains("时间到"), "menu bar alerts on finish")

            self.engine.reset()
            self.engine.startCountUp()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.9) {
            // 结束后标签要保持稳定，不能反复在 00:00 和 时间到 之间切换
            check(!self.statusController.currentTitle.contains("00:00"), "finish label does not flash 00:00")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            check(self.engine.mode == .countup, "countup mode active")
            check(self.engine.state == .running, "countup running")
            check(self.engine.remaining > 0, "countup ticks up")
            check(!self.statusController.currentTitle.isEmpty, "menu bar shows countup")

            self.engine.reset()
            self.engine.startCountUp(target: 1)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.2) {
            check(self.engine.targetReached, "countup target reached")
            check(self.engine.state == .running, "countup keeps running after target")

            print(failures == 0 ? "ALL SMOKE TESTS PASSED" : "\(failures) SMOKE TEST(S) FAILED")
            UserDefaults(suiteName: "meow.smoke")?.removePersistentDomain(forName: "meow.smoke")
            exit(failures == 0 ? 0 : 1)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
