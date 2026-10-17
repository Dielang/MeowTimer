import SwiftUI
import AppKit

/// 菜单栏图标点开后的小面板。
struct TimerPanelView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var launchAtLogin: LaunchAtLogin

    @State private var hours: Int
    @State private var minutes: Int
    @State private var seconds: Int
    @State private var showCustomEditor: Bool

    private let presetMinutes = [1, 3, 5, 10, 15, 25, 45, 60]

    private var customSeconds: Int { hours * 3600 + minutes * 60 + seconds }

    init(engine: TimerEngine,
         launchAtLogin: LaunchAtLogin = LaunchAtLogin(),
         showCustomEditor: Bool = false,
         hours: Int = 0,
         minutes: Int = 5,
         seconds: Int = 0) {
        self.engine = engine
        self.launchAtLogin = launchAtLogin
        _hours = State(initialValue: hours)
        _minutes = State(initialValue: minutes)
        _seconds = State(initialValue: seconds)
        _showCustomEditor = State(initialValue: showCustomEditor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            modePicker
            timeDisplay
            if engine.mode == .countdown || engine.total > 0 {
                progressBar
            }
            presetsGrid
            customToggleRow
            if showCustomEditor {
                customEditor
            }
            if engine.mode == .countdown {
                targetHintForCountdown
            } else {
                if engine.total > 0 {
                    targetCaption
                }
                if engine.state == .idle {
                    pureCountUpRow
                }
            }
            actionRow
            settingsSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)
            Text("喵时")
                .font(.system(size: 14, weight: .semibold))
            Text(statusText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
            Spacer()
        }
    }

    private var modePicker: some View {
        Picker("模式", selection: modeBinding) {
            Text("倒计时").tag(TimerMode.countdown)
            Text("正计时").tag(TimerMode.countup)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .tint(.orange)
        .disabled(engine.state == .running || engine.state == .paused)
    }

    private var modeBinding: Binding<TimerMode> {
        Binding(
            get: { engine.mode },
            set: { engine.setMode($0) }
        )
    }

    // MARK: - 时间显示

    private var timeDisplay: some View {
        Text(displayText)
            .font(.system(size: 46, weight: .light, design: .rounded).monospacedDigit())
            .foregroundStyle(engine.state == .idle ? Color.secondary.opacity(0.55) : Color.primary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
    }

    private var progressBar: some View {
        ProgressView(value: engine.progress)
            .progressViewStyle(.linear)
            .tint(.orange)
            .opacity(engine.total > 0 ? 1 : 0.25)
    }

    private var targetCaption: some View {
        HStack(spacing: 6) {
            Text("目标 \(TimerEngine.formatted(engine.total))")
            if engine.targetReached {
                Text("已达标")
                    .foregroundStyle(.orange)
            }
            Spacer()
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
    }

    private var targetHintForCountdown: some View {
        HStack(spacing: 6) {
            Text("到点后响铃 + 屏幕提醒")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    // MARK: - 时间设置

    private var presetsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
            ForEach(presetMinutes, id: \.self) { mins in
                Button {
                    startTimer(seconds: TimeInterval(mins * 60))
                } label: {
                    Text("\(mins) 分")
                        .font(.system(size: 11))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    /// 「自定义时间…」入口：展开后可自己选 时/分/秒。
    private var customToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showCustomEditor.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 10))
                Text(showCustomEditor ? "收起自定义时间" : "自定义时间…")
                    .font(.system(size: 11))
                if !showCustomEditor && customSeconds > 0 {
                    Text(TimerEngine.formatted(TimeInterval(customSeconds)))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showCustomEditor ? 180 : 0))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var customEditor: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                timeStepper("时", $hours, 0...23)
                timeStepper("分", $minutes, 0...59)
                timeStepper("秒", $seconds, 0...59)
                Spacer()
            }
            HStack(spacing: 8) {
                Text("共 \(TimerEngine.formatted(TimeInterval(max(1, customSeconds))))")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("开始") {
                    startTimer(seconds: TimeInterval(max(1, customSeconds)))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
                .disabled(customSeconds <= 0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func timeStepper(_ title: String, _ value: Binding<Int>, _ range: ClosedRange<Int>) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            HStack(spacing: 2) {
                stepButton("−") {
                    value.wrappedValue = value.wrappedValue > range.lowerBound ? value.wrappedValue - 1 : range.upperBound
                }
                TextField("0", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .multilineTextAlignment(.center)
                    .frame(width: 34)
                stepButton("+") {
                    value.wrappedValue = value.wrappedValue < range.upperBound ? value.wrappedValue + 1 : range.lowerBound
                }
            }
        }
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 14, height: 18)
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }

    private var pureCountUpRow: some View {
        HStack(spacing: 8) {
            Button("纯正计时（不设目标）") {
                engine.startCountUp(target: 0)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .font(.system(size: 10))
            Spacer()
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if engine.state != .idle {
            HStack(spacing: 8) {
                Button(action: primaryAction) {
                    Text(primaryLabel)
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)

                Button("重置") { engine.reset() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()
            }
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle("提示音", isOn: $engine.soundEnabled)
            Toggle("桌面悬浮倒计时窗", isOn: $engine.floatingEnabled)
            Toggle("菜单栏显示时间", isOn: $engine.menuShowsTime)
            Toggle("开机自启", isOn: launchAtLoginBinding)
            if launchAtLogin.requiresApproval {
                Button("需要在「系统设置 → 登录项」里批准") {
                    launchAtLogin.openSystemSettingsLoginItems()
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundStyle(.orange)
            } else if !isInApplications {
                Text("提示：先把 App 放进「应用程序」，开机自启才稳定")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(.system(size: 11))
    }

    private var footer: some View {
        HStack {
            Text("⌥ ⌘ T 开始 / 暂停")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("退出") { NSApp.terminate(nil) }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 辅助

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.enabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }

    private var isInApplications: Bool {
        Bundle.main.bundlePath.hasPrefix("/Applications/")
    }

    private func startTimer(seconds: TimeInterval) {
        let duration = max(1, seconds)
        if engine.mode == .countdown {
            engine.start(seconds: duration)
        } else {
            engine.startCountUp(target: duration)
        }
    }

    private var statusText: String {
        switch engine.state {
        case .idle:
            return "未开始"
        case .running:
            if engine.mode == .countdown { return "计时中" }
            return engine.targetReached ? "已达标" : "正计时"
        case .paused:
            return "已暂停"
        case .finished:
            return "时间到"
        }
    }

    private var displayText: String {
        if engine.state == .idle {
            return engine.mode == .countdown ? TimerEngine.formatted(engine.lastDuration) : "00:00"
        }
        return TimerEngine.formatted(engine.remaining)
    }

    private var primaryLabel: String {
        switch engine.state {
        case .running: return "暂停"
        case .paused: return "继续"
        case .finished: return "再来一次"
        case .idle: return "开始"
        }
    }

    private func primaryAction() {
        switch engine.state {
        case .running: engine.pause()
        case .paused: engine.resume()
        case .finished: engine.restart()
        case .idle: engine.startPause()
        }
    }
}
