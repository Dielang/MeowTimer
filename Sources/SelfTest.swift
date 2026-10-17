import AppKit
import SwiftUI

enum SelfTest {
    static func run() {
        var failures = 0

        func expect(_ condition: Bool, _ name: String) {
            if condition {
                print("PASS  \(name)")
            } else {
                failures += 1
                print("FAIL  \(name)")
            }
        }

        // 时间格式化
        expect(TimerEngine.formatted(0) == "00:00", "format 0s")
        expect(TimerEngine.formatted(59) == "00:59", "format 59s")
        expect(TimerEngine.formatted(59.2) == "01:00", "format rounds up")
        expect(TimerEngine.formatted(60) == "01:00", "format 60s")
        expect(TimerEngine.formatted(1500) == "25:00", "format 25min")
        expect(TimerEngine.formatted(3599) == "59:59", "format 59:59")
        expect(TimerEngine.formatted(3600) == "1:00:00", "format 1h")
        expect(TimerEngine.formatted(3661) == "1:01:01", "format 1h1m1s")

        // 引擎状态流转（用独立的 UserDefaults，避免测试污染用户数据）
        let suiteName = "meow.selftest"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)

        let engine = TimerEngine(defaults: testDefaults)
        expect(engine.state == .idle, "initial state idle")
        expect(engine.mode == .countdown, "initial mode countdown")

        engine.start(seconds: 90)
        expect(engine.state == .running, "start -> running")
        expect(engine.mode == .countdown, "start sets countdown mode")
        expect(engine.progress <= 1 && engine.progress > 0, "progress in range")
        expect(TimerEngine.formatted(engine.remaining) == "01:30", "remaining after start")

        engine.pause()
        expect(engine.state == .paused, "pause -> paused")
        let paused = engine.remaining
        expect(paused > 89 && paused <= 90, "remaining frozen on pause")

        engine.resume()
        expect(engine.state == .running, "resume -> running")

        engine.reset()
        expect(engine.state == .idle, "reset -> idle")
        expect(engine.remaining == 0, "remaining cleared")

        // 倒计时到点
        let quick = TimerEngine(defaults: testDefaults)
        quick.onFinish = {}
        quick.start(seconds: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(1.6))
        expect(quick.state == .finished, "countdown reaches finished")
        expect(quick.remaining == 0, "countdown ends at zero")
        expect(quick.progress == 0, "countdown progress at zero after finish")

        // 正计时（纯）
        let up = TimerEngine(defaults: testDefaults)
        up.startCountUp()
        expect(up.mode == .countup, "countup mode")
        expect(up.state == .running, "countup running")
        expect(up.total == 0, "countup has no target")
        expect(up.remaining < 0.2, "countup starts near zero")

        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        expect(up.remaining > 0.25, "countup ticks upward")
        expect(TimerEngine.formatted(up.remaining) == "00:01", "countup displays 00:01")

        up.pause()
        expect(up.state == .paused, "countup paused")
        let frozen = up.remaining
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        expect(abs(up.remaining - frozen) < 0.15, "countup frozen while paused")

        up.resume()
        expect(up.state == .running, "countup resumed")
        up.reset()
        expect(up.state == .idle, "countup reset -> idle")
        expect(up.remaining == 0, "countup reset to zero")
        expect(up.mode == .countup, "countup mode kept after reset")

        // 正计时（带目标）
        let targeted = TimerEngine(defaults: testDefaults)
        var targetHits = 0
        targeted.onTargetReached = { targetHits += 1 }
        targeted.startCountUp(target: 2)
        expect(targeted.total == 2, "countup target set")
        expect(targeted.progress == 0, "countup target progress starts at zero")

        RunLoop.main.run(until: Date().addingTimeInterval(2.4))
        expect(targeted.targetReached, "countup target reached flag")
        expect(targetHits == 1, "countup target callback fires once")
        expect(targeted.state == .running, "countup keeps running past target")
        expect(targeted.remaining > 2, "countup continues past target")
        expect(targeted.progress == 1, "countup progress clamped to one")

        targeted.reset()
        expect(targeted.targetReached == false, "countup reset clears target reached")
        expect(targeted.total == 0, "countup reset clears target")

        // restart 保留目标
        targeted.startCountUp(target: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        targeted.restart()
        expect(targeted.total == 1, "countup restart keeps target")
        expect(targeted.state == .running, "countup restart runs")
        targeted.reset()

        // 模式切换会重置
        up.startCountUp(target: 5)
        up.setMode(.countdown)
        expect(up.mode == .countdown, "setMode switches to countdown")
        expect(up.state == .idle, "setMode resets state")
        expect(up.remaining == 0, "setMode clears elapsed")

        // 空闲时按模式启动
        up.setMode(.countup)
        up.startPause()
        expect(up.state == .running, "startPause in countup mode starts countup")
        up.startPause()
        expect(up.state == .paused, "startPause pauses countup")
        up.reset()
        up.setMode(.countdown)
        up.startPause()
        expect(up.state == .running, "startPause in countdown mode starts countdown")
        up.reset()

        testDefaults.removePersistentDomain(forName: suiteName)

        print(failures == 0 ? "ALL TESTS PASSED" : "\(failures) TEST(S) FAILED")
        if failures > 0 { exit(1) }
    }
}
