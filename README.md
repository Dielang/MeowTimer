# 喵时 MeowTimer

一个 **Catime 风格的 macOS 菜单栏计时器**。原生 Swift（AppKit + SwiftUI）实现，无第三方依赖，App 体积约 910KB。

> 为什么做这个：Catime 只有 Windows 版（[官方跨平台 issue](https://github.com/vladelaina/Catime/issues/28) 还开着），macOS 上没有 star 多、又足够轻的同类产品，所以手写了一个。

## 功能

- **倒计时 / 正计时双模式**：面板顶部切换
  - **倒计时**：设一个时长 → 到 0 结束，提示音 + 提醒窗 + 菜单栏「时间到」
  - **正计时**：同样可以设**目标时长**；从 `00:00` 开始往上累计，进度条显示「已用 / 目标」，到达目标时响铃 + 提醒窗，然后**继续累计**不打断；也可以选「纯正计时（不设目标）」当秒表用
- **8 个快捷预设**：1 / 3 / 5 / 10 / 15 / 25 / 45 / 60 分钟，点一下就开始
- **自定义时间**：点「自定义时间…」展开，时 / 分 / 秒都可以用 `−` / `+` 逐格调节，也能直接输入，下面实时显示合计（如「共 1:23:30」），点「开始」即用
- **菜单栏实时时间**：等宽数字不抖动，暂停 / 结束有独立图标（正计时是秒表图标）
- **透明悬浮计时窗**：置顶、可拖动、位置记忆、右上角 ✕ 关闭；有目标时显示进度条
- **到点提醒**：系统提示音 + 屏幕中央提醒窗（点击关闭）；结束后菜单栏保持静态「时间到」，不闪烁
- **全局快捷键**：`⌥⌘T` 开始 / 暂停 / 继续（两种模式通用）
- **右键菜单**：暂停/继续、开始正计时、重置、快速开始倒计时、悬浮窗开关、菜单栏时间开关、退出
- **开机自启**：面板里直接开关（注册为 macOS 登录项，无需管理员权限）
- **自动保存**：上次时长、各开关、悬浮窗位置
- 中文界面，深色 / 浅色自动适配，无 Dock 图标

## 安装

1. 把 `MeowTimer.app` 拖进「应用程序」
2. 首次打开如果提示"无法验证开发者"（本地 ad-hoc 签名、未做 Apple 公证）：
   - 右键 App →「打开」→ 再点「打开」，或执行
     ```bash
     xattr -dr com.apple.quarantine /Applications/MeowTimer.app
     ```
3. 启动后 Dock 里没有图标，**图标在屏幕右上角菜单栏**，点它打开面板
4. 悬浮窗上次关掉了的话：面板里打开「桌面悬浮倒计时窗」开关即可

## 开机自启

两种方式，任选一种：

1. **App 内开关（推荐）**：面板里打开「开机自启」开关，用的是 macOS 13+ 的 `SMAppService`，注册到「系统设置 → 通用 → 登录项与扩展」的「登录时打开」列表里，不需要管理员权限。
   - 如果 App 不在「应用程序」文件夹，面板会提示：**先把 App 放进 /Applications 再开**，否则登录项记录的是当前路径，移动 App 后要关一下再开一次。
2. **手动添加（任何版本 App 都适用）**：
   - 把 `MeowTimer.app` 拖进 `/Applications`
   - 打开「系统设置 → 通用 → 登录项与扩展」
   - 在「登录时打开」区域点 `+`，选择 `MeowTimer.app`（也可以直接把 App 拖进列表）
   - 如果系统把它放进「允许在后台」列表并显示为关闭，打开对应开关即可

> App 是 `LSUIElement`（无 Dock 图标），开机自启后只会出现在菜单栏，不会弹窗口。
> 注销/禁用：面板里关掉「开机自启」，或在系统设置的登录项列表里移除。

## 使用

- **左键**菜单栏图标 → 打开面板（顶部切换倒计时 / 正计时）
- **自定义时长**：点「自定义时间…」→ 用 `−`/`+` 或直接输入 时·分·秒 → 点「开始」
- 正计时：设目标时长后开始，从 0 往上计到目标会提醒并继续；「纯正计时（不设目标）」是无目标秒表
- **右键**菜单栏图标 → 快捷菜单
- 计时中把鼠标移到悬浮窗上，右上角出现 ✕ 可隐藏悬浮窗
- 退出：右键菜单 →「退出喵时」

## 用 IDE 打开 / 开发

工程本身是**轻量的**：`Sources/*.swift` + `build.sh`，另外附了 `Package.swift` 方便 IDE 识别。

**Xcode（推荐，macOS 原生开发的标准工具）**

```
Xcode → File → Open… → 选择 MeowTimer 文件夹（或直接选 Package.swift）
```

- Xcode 会把文件夹当成 Swift Package 打开，可直接编辑代码、跳转定义、`⌘B` 构建、`⌘R` 运行调试（跑的是调试用可执行文件，不带 .app 外壳）
- 正式打包 `.app`（含 Info.plist / 图标 / 签名）仍用终端：`bash build.sh`
- 如果要 Xcode 里直接出 .app，可以再补一个 `.xcodeproj`（需要的话告诉我）

**VS Code / Cursor**：打开 `MeowTimer` 文件夹，装官方 Swift 扩展即可；构建照样用 `bash build.sh`。

**JetBrains AppCode**：已停止维护（2025 年 EOL），不建议。

## 从源码构建

需要 Xcode（或 Command Line Tools）：

```bash
bash build.sh                 # 生成 build/MeowTimer.app（自动 ad-hoc 签名）
# 或者用 SwiftPM 编出调试用可执行文件：
swift build                   # 产物在 .build/debug/MeowTimer
```

内置自检：

```bash
./build/MeowTimer.app/Contents/MacOS/MeowTimer --selftest          # 逻辑单测（52 项）
./build/MeowTimer.app/Contents/MacOS/MeowTimer --smoke             # GUI 冒烟测试（17 项，会弹窗约 6 秒）
./build/MeowTimer.app/Contents/MacOS/MeowTimer --render ./preview  # 离屏渲染各界面 PNG
```

> 受限沙箱环境（比如自动化脚本）里 SwiftUI 宏插件需要关掉嵌套沙箱，并把模块缓存指到工程目录：
> ```bash
> CLANG_MODULE_CACHE_PATH="$PWD/.modulecache" SWIFT_MODULE_CACHE_PATH="$PWD/.modulecache" \
> TMPDIR="$PWD/.tmp/" swift build --disable-sandbox -Xswiftc -disable-sandbox
> ```
> 普通终端里直接 `swift build` / `bash build.sh` 即可。

## 版本管理（Git）

仓库已在 `MeowTimer/` 里初始化，当前版本打了 tag `v1.4`：

```bash
git log --oneline --decorate   # 提交历史
git tag                        # 版本标签
git show v1.4 --stat           # 某版本改了什么
git checkout -b feature/xxx    # 开分支开发
```

构建产物（`build/`、`dist/`、`preview/`、`.build/`、`.swiftpm/` 等）都在 `.gitignore` 里，不会提交。

要推送到 GitHub（先在网页建一个空仓库）：

```bash
git remote add origin git@github.com:<你的用户名>/MeowTimer.git
git push -u origin main --tags
```

## 目录结构

```
MeowTimer/
├── Package.swift             # SwiftPM 清单（给 IDE / swift build 用）
├── build.sh                  # 一键构建 .app
├── Sources/
│   ├── main.swift            # 入口 / 命令行工具模式
│   ├── AppDelegate.swift     # 生命周期、冒烟测试
│   ├── TimerEngine.swift     # 倒计时 / 正计时状态机（可注入 UserDefaults）
│   ├── StatusItemController.swift  # 菜单栏图标 / 面板 / 右键菜单
│   ├── TimerPanelView.swift  # 面板 UI（SwiftUI，含自定义时间选择器）
│   ├── FloatingTimerWindow.swift   # 透明悬浮计时窗
│   ├── FinishHUD.swift       # 到点 / 达标提醒窗
│   ├── HotKeyManager.swift   # 全局快捷键（Carbon）
│   ├── LaunchAtLogin.swift   # 开机自启（SMAppService 登录项）
│   ├── PreviewRenderer.swift # 离屏渲染预览图
│   └── SelfTest.swift        # 单测
├── Resources/
│   ├── Info.plist
│   ├── MeowTimer.icns
│   └── icon-1024.png
└── Tools/make-icon.swift     # 生成应用图标
```

## 更新记录

- **v1.4**
  - 新增**开机自启**开关（`SMAppService` 登录项），面板与右键菜单均可设置；需要批准时可直接跳转系统设置
- **v1.3**
  - 新增显式的「自定义时间…」入口：展开后可自由选择 时 / 分 / 秒（`−`/`+` 调节或直接输入），实时显示合计
- **v1.2**
  - 正计时支持**目标时长**：从 0 累计到目标时响铃提醒并继续计时
  - 正计时进度条、目标标签、达标状态
  - 保留「纯正计时（不设目标）」秒表模式
- **v1.1**
  - 新增**正计时**模式（面板切换 / 右键菜单 / 悬浮窗 / 菜单栏均支持）
  - 修复结束时菜单栏在 `00:00` 和 `时间到` 之间反复切换的问题：现在保持静态「时间到」
- **v1.0** 初版

## 已知限制 / Roadmap

- 未做 Apple 公证（本地自签名；自己用没问题，分发给别人要用户手动放行）
- 暂无开机自启（`SMAppService` 需要正规签名，后续可加）
- 暂无多计时器 / 历史统计 / 自定义颜色字号
- macOS 菜单栏不支持第三方 GIF 动画图标，Catime 的"动态托盘图标"无法 1:1 复刻

## License

MIT
