import AppKit
import Foundation
import ServiceManagement
import Combine

/// 开机自启（登录项）管理：macOS 13+ 的 SMAppService。
final class LaunchAtLogin: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var requiresApproval = false
    private(set) var lastError: String?

    init() {
        refresh()
    }

    /// 读取系统里的真实状态（用户也可能在系统设置里手动改过）。
    func refresh() {
        let status = SMAppService.mainApp.status
        enabled = (status == .enabled)
        requiresApproval = (status == .requiresApproval)
    }

    @discardableResult
    func setEnabled(_ on: Bool) -> Bool {
        lastError = nil
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
        return lastError == nil
    }

    func openSystemSettingsLoginItems() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    /// `--login-test`：注册 → 读状态 → 注销，用于构建自检（建议在 /tmp 的副本上跑）。
    static func probe() {
        let manager = LaunchAtLogin()
        print("[login] initial enabled=\(manager.enabled) requiresApproval=\(manager.requiresApproval) raw=\(SMAppService.mainApp.status.rawValue)")

        manager.setEnabled(true)
        print("[login] after register enabled=\(manager.enabled) requiresApproval=\(manager.requiresApproval) raw=\(SMAppService.mainApp.status.rawValue) error=\(manager.lastError ?? "-")")

        manager.setEnabled(false)
        print("[login] after unregister enabled=\(manager.enabled) requiresApproval=\(manager.requiresApproval) raw=\(SMAppService.mainApp.status.rawValue) error=\(manager.lastError ?? "-")")
    }
}
