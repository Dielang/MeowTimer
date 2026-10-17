import Foundation
import Combine

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case finished
}

enum TimerMode: String, CaseIterable, Equatable {
    /// 倒计时（到 0 结束，响铃提醒）
    case countdown
    /// 正计时（从 0 开始往上累计，不响铃）
    case countup
}

/// 计时核心逻辑：与 UI 解耦，全部在主线程回调。
final class TimerEngine: ObservableObject {
    @Published private(set) var state: TimerState = .idle
    @Published private(set) var mode: TimerMode = .countdown
    /// 倒计时 = 设定的总时长；正计时 = 目标时长（0 表示纯正计时、无目标）
    @Published private(set) var total: TimeInterval = 0
    /// 倒计时 = 剩余时间；正计时 = 已用时间
    @Published private(set) var remaining: TimeInterval = 0
    /// 正计时是否已经到达目标时长
    @Published private(set) var targetReached = false

    @Published var soundEnabled: Bool { didSet { defaults.set(soundEnabled, forKey: Keys.sound) } }
    @Published var floatingEnabled: Bool { didSet { defaults.set(floatingEnabled, forKey: Keys.floating) } }
    @Published var menuShowsTime: Bool { didSet { defaults.set(menuShowsTime, forKey: Keys.menuTime) } }

    /// 倒计时结束时回调（播放提示音、弹 HUD）。
    var onFinish: (() -> Void)?
    /// 正计时到达目标时长时回调（继续计时，不结束）。
    var onTargetReached: (() -> Void)?

    private enum Keys {
        static let sound = "meow.sound"
        static let floating = "meow.floating"
        static let menuTime = "meow.menuTime"
        static let lastDuration = "meow.lastDuration"
    }

    private let defaults: UserDefaults
    private var ticker: Timer?
    private var endDate: Date?     // 倒计时用
    private var startDate: Date?   // 正计时用
    private var targetNotified = false
    private(set) var lastDuration: TimeInterval = 25 * 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.sound: true,
            Keys.floating: true,
            Keys.menuTime: true
        ])
        soundEnabled = defaults.bool(forKey: Keys.sound)
        floatingEnabled = defaults.bool(forKey: Keys.floating)
        menuShowsTime = defaults.bool(forKey: Keys.menuTime)
        let saved = defaults.double(forKey: Keys.lastDuration)
        if saved >= 1 { lastDuration = saved }
    }

    // MARK: - 状态

    /// 倒计时 = 剩余比例；正计时 = 已用时间占目标的比例（无目标时为 0）。
    var progress: Double {
        guard total > 0 else { return 0 }
        return max(0, min(1, remaining / total))
    }

    var isActive: Bool { state == .running || state == .paused }

    // MARK: - 控制

    func setMode(_ newMode: TimerMode) {
        guard newMode != mode else { return }
        reset()
        mode = newMode
    }

    /// 倒计时：指定时长开始。
    func start(seconds: TimeInterval) {
        stopTicker()
        let duration = max(1, seconds)
        mode = .countdown
        lastDuration = duration
        defaults.set(duration, forKey: Keys.lastDuration)
        total = duration
        remaining = duration
        targetReached = false
        targetNotified = false
        startDate = nil
        endDate = Date().addingTimeInterval(duration)
        state = .running
        startTicker()
    }

    /// 正计时：从 0 开始累计。
    /// - Parameter target: 目标时长（秒），0 表示不设目标、纯正计时。
    func startCountUp(target: TimeInterval = 0) {
        stopTicker()
        mode = .countup
        total = max(0, target)
        remaining = 0
        targetReached = false
        targetNotified = false
        endDate = nil
        startDate = Date()
        state = .running
        startTicker()
    }

    /// ⌥⌘T 或菜单里的“开始/暂停”。
    func startPause() {
        switch state {
        case .running: pause()
        case .paused: resume()
        case .finished: restart()
        case .idle:
            if mode == .countup {
                startCountUp()
            } else {
                start(seconds: lastDuration)
            }
        }
    }

    func restart() {
        if mode == .countup {
            startCountUp(target: total)
        } else {
            start(seconds: lastDuration)
        }
    }

    func pause() {
        guard state == .running else { return }
        switch mode {
        case .countdown:
            guard let end = endDate else { return }
            remaining = max(0, end.timeIntervalSinceNow)
            endDate = nil
        case .countup:
            guard let start = startDate else { return }
            remaining = max(0, Date().timeIntervalSince(start))
            startDate = nil
        }
        state = .paused
        stopTicker()
    }

    func resume() {
        guard state == .paused else { return }
        switch mode {
        case .countdown:
            guard remaining > 0 else { return }
            endDate = Date().addingTimeInterval(remaining)
        case .countup:
            startDate = Date().addingTimeInterval(-remaining)
        }
        state = .running
        startTicker()
    }

    func reset() {
        stopTicker()
        endDate = nil
        startDate = nil
        state = .idle
        total = 0
        remaining = 0
        targetReached = false
        targetNotified = false
    }

    // MARK: - 计时

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard state == .running else { return }
        switch mode {
        case .countdown:
            guard let end = endDate else { return }
            let left = end.timeIntervalSinceNow
            if left <= 0 {
                remaining = 0
                finish()
            } else {
                remaining = left
            }
        case .countup:
            guard let start = startDate else { return }
            remaining = max(0, Date().timeIntervalSince(start))
            if total > 0, !targetNotified, remaining >= total {
                targetNotified = true
                targetReached = true
                onTargetReached?()
            }
        }
    }

    private func finish() {
        stopTicker()
        endDate = nil
        startDate = nil
        state = .finished
        remaining = 0
        onFinish?()
    }

    /// 预览/测试用：直接设置正计时已用时间。
    func debugSetElapsed(_ seconds: TimeInterval) {
        guard mode == .countup else { return }
        remaining = seconds
    }

    // MARK: - 格式化

    /// 25:00 / 1:05:00，向上取整（避免刚开始就显示 24:59）。
    static func formatted(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(ceil(interval)))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
