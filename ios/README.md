# iOS 版 Henge

Henge App，运行在 HengeVM 的引擎之上。构建方式：`ios/scripts/package_ipa.sh`（写出
`~/Desktop/Henge.ipa`；加上 `--trollstore` 则写出 `Henge.tipa`，供 TrollStore 和
TrollStore Lite 使用，其中不含 TrollStore 禁止的授权项）。需要 Xcode 27 或更高版本、xcodegen，
以及由 `ios/scripts/fetch_deps.sh` 从 Husk 复制过来的预编译组件（StikJIT、配对库、
用于 iOS 的 libslirp 和 glib）。`HENGE_ENTITLEMENTS` 用于指定 App 的授权文件
（默认是 `Henge/Henge.entitlements`）。免费的个人团队请使用
`Henge/Henge.personal.entitlements`：把它作为构建设置传给 xcodebuild
（`xcodebuild ... HENGE_ENTITLEMENTS=Henge/Henge.personal.entitlements`，因为
`project.yml` 已经设置了它，环境变量无法覆盖），同时也作为环境变量传给
打包脚本（`HENGE_ENTITLEMENTS=... ios/scripts/package_ipa.sh`）。

- **JIT**：在 iOS 26+（TXM）上，只有已附加的调试器才能授予可执行内存。
  Henge 使用的是与 Husk 相同的一套机制：StikDebug、TrollStore、越狱，
  或内置的 StikJIT 辅助程序（`HengeJITHelper.appex`，在 iOS 27 上支持设备端配对）。
  App 每次启动会申请一块 1 GB 的区域（`JITBootstrap.jitBytes`），
  引擎则通过 `vm_remap` 出来的别名写入（`host/jit_region.c`，分离模式）。
- **内存**：推荐但不强制使用 `increased-memory-limit`。一旦有调试器附加，
  客户机内存就不再计入 App 的内存上限；如果 iOS 拒绝这样做，
  则会改用可用存储空间上的一个文件。
- **机器**在 iPhone 上从 Apple 的恢复镜像安装
  （`Installer.swift`，[docs/architecture.md](../docs/architecture.md)）。也可以从
  App 中导出一台机器，或在 Mac 上用
  `tools/export_ios.sh DISK AUX ECID [NAME]` 制作（磁盘打包时略去空洞，
  参见 `host/hvsparse.h`），然后在“访达”里拖到 Henge 上，或在“文件”里选取。
- **启动 ROM**：安装时从 Apple 获取，不随 App 分发（`Henge/BootROM.swift`，
  [docs/architecture.md](../docs/architecture.md)）。
- **显示**：iOS 没有 ParavirtualizedGraphics 框架，所以 Henge 用 Metal 重放
  客户机的 GPU 命令（`devices/pvg_lite.c`、`devices/pvg_metal.m`）。
- **外接显示器**：在 iOS 27 上，`SessionView` 会在 Mac 会话期间注册一个 SwiftUI 的
  `ExternalNonInteractiveAccessory`。在 iOS 17–26 上，iOS 改为把显示场景提供给
  App 代理（`HengeAppDelegate`），由 `LegacyExternalDisplay` 按 `ExternalScreenPlan`
  的决定在那里呈现会话；在会话之外，显示器只是镜像手机画面。`DisplayRouter`
  会选择唯一一个处于活动状态的 `CAMetalLayer`，优先使用外接画面，并在断开时
  切回设备。手机的会话掌控虚拟机与全部输入；外接配件只负责呈现像素。
  客户机已有的分辨率保持不变（iPhone 上默认 1920×1080），并按比例适配显示器，
  不会拉伸。当 iOS 识别出外设时，USB-C 视频与扩展坞上的键盘／鼠标可以同时使用。
  AirPlay 也可能提供外接场景，延迟取决于传输方式。运行 `make test-display-routing`
  可做路由生命周期检查；`ios/scripts/check_display.sh` 还能在不链接外部库的情况下
  编译所有 App 的 Swift 源码以及 iOS/macOS 渲染器。
  USB-C 视频已在运行 iOS 27 的 iPhone 17 Pro 上、用开发版 0.1/2 由用户确认可用；
  在 Mac 会话期间会自动启用。iOS 17–26 的路径可以编译，其方案也经过测试，
  但尚未在真机上运行。还有待验收：在启动前／启动中接入、在空闲桌面上拔插、
  旋转手机、通过扩展坞使用键盘／鼠标，以及在连接状态下结束会话。
  这些具体的生命周期情形、其他设备以及 AirPlay 都还没有单独验证。
- **共享**（`Henge/Sharing.swift`、`host/share.c`、
  [docs/architecture.md](../docs/architecture.md)）：即“文件”里的共享文件夹和
  剪贴板。Mac 上的剪贴板会同步过来；反方向则要用系统的粘贴按钮，
  因为 App 自行读取剪贴板时 iOS 会请求权限。
- **硬件输入**（`Henge/Hardware.swift`）：键盘的按键按 HID usage 送到 Mac 的
  USB 键盘，这也是 iOS 上报它们的方式。触控板或鼠标经由 GameController 并锁定
  指针，iPadOS 只允许全屏的 App 这样做。最初的几个滚动数值会记录到 `henge.log`，
  以便在真机上调整滚动。

- **芯片**：虚拟 CPU 提供 Armv8.5 指令（`core/sysreg.c`），macOS 会用到它们，
  而且它们按原样执行，因此 Henge 需要 A14 或 M1 及更新一代的芯片。

来自 Husk 的代码（GPL-2.0-or-later）：`Henge/JIT/*`、`Henge/HengeLog.swift`、
`Henge/Native/henge-ios-jit.*`、`henge-brk.S`、`HengeJITHelper/`。StikJIT 为
MPL-2.0，idevice 为 MIT（`Henge/Resources/legal/`）；`tcg-apple-jit.h` 属于 QEMU
（LGPL-2.1）。参见 [docs/licensing.md](../docs/licensing.md)。
