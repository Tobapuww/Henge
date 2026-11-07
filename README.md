<p align="center">
  <img src="docs/icon.png" width="120" height="120" alt="Henge">
</p>

<h1 align="center">Henge</h1>

<p align="center">在 iPhone 和 iPad 上运行 macOS。</p>

<p align="center">
  <a href="#安装">安装</a>
  ·
  <a href="docs/architecture.md">工作原理</a>
  ·
  <a href="https://itslevii.dev">网站</a>
  ·
  <a href="https://github.com/Leviidev/Henge/releases">发行版</a>
</p>

<p align="center">
  <a href="https://github.com/Leviidev/Henge/releases"><img src="https://img.shields.io/github/downloads/Leviidev/Henge/total?style=flat-square&color=2E6BFF&labelColor=111111" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Leviidev/Henge?style=flat-square&color=2E6BFF&labelColor=111111" alt="GPL-2.0-or-later"></a>
</p>

下载 macOS，把它装到设备上，然后直接用。

- **自研模拟器** —— iOS 不给 App 提供 hypervisor，所以 Henge 用自己的 JIT、自己的 MMU 和自己的设备来运行 Mac 的 arm64 代码。它没有使用 QEMU，也没有使用 Virtualization.framework。
- **在设备上直接安装** —— Henge 会下载 Apple 的恢复镜像，并像真正的 Mac 那样恢复它。不需要 Mac，也不会解密或修改任何东西。
- **图形** —— macOS 通过一块虚拟 GPU 绘制，Henge 用 Metal 重放它的命令。Safari 和 Discord 这类 Electron 应用都能正常显示。
- **触控** —— 屏幕就是触控板：按住可拖拽，双指可滚动。Esc、Tab、Control、Option 和 Command 位于键盘上方。
- **键盘与鼠标** —— 在 iPad 上，妙控键盘或蓝牙键盘和鼠标可以直接操控这台 Mac。
- **外接显示器** —— 在 Mac 会话期间，用支持视频传输的 USB-C 线或 USB-C/HDMI 扩展坞连接显示器。该模式会自动启用：显示器显示这台 Mac，而 iPhone 或 iPad 仍保留触控板和键盘控制。断开连接后画面回到设备上。客户机已有的分辨率会保留。在 iOS 17–26 上，同样的功能通过一条较早的 iOS 路径实现，但尚未在真机上验证；在 Mac 会话之外，显示器只是镜像设备画面。USB-C 视频输出已在运行 iOS 27 的 iPhone 17 Pro 上由用户确认可用（开发版 0.1/2）。
- **共享** —— 在 macOS 与设备之间复制粘贴，并有一个在“文件”和 Mac 上都能看到的共享文件夹。
- **贴合屏幕** —— 在 iPad 上，新建的 Mac 会得到与 iPad 形状相同的屏幕，因此不会出现黑边。

在 iPhone 17 Pro 上，macOS 大约 15 秒进入锁屏界面。Discord 可以安装，约 15 秒打开，能登录并发送消息。

## 安装

用 SideStore 或 AltStore 侧载 [发行版](https://github.com/Leviidev/Henge/releases) 中的 `Henge.ipa`，或用 TrollStore、TrollStore Lite 安装 `Henge.tipa`。需要 iOS 或 iPadOS 17 及以上，且芯片为 A14 或 M1 及更新型号。目前只在 iPhone 17 Pro 上测试过：iPad 支持是新加的，还没有在真正的 iPad 上运行过。

- **必须开启 JIT**：StikDebug、TrollStore（仅支持到 iOS 17.0）、TrollStore Lite（需要越狱）、单独越狱，或者 Henge 内置的 StikJIT 辅助程序（iOS 26 及以上）。
- **存储**：macOS Sequoia 大约需要 43 GB 可用空间。其中 17 GB 是下载的镜像，装完之后可以删掉，另外 26 GB 归这台 Mac。
- **内存**：一台 Mac 可分到 4、6 或 8 GB。如果你的证书带有“更高内存上限”授权，请用它给 Henge 签名。

然后打开“安装”标签页，选择 macOS Sequoia 15.6.1，并保持 Henge 打开、设备插着电。Tahoe 26.6.2 和 macOS 27.2 也可以选，但尚未测试。

## 与 Mac 共享

每台 Mac 只需做一次：在这台 Mac 上打开“终端”，然后在 Henge 中打开“详情”，点 **键入设置命令**。在 Mac 上按 Return 键，当 macOS 询问 `henge-agent` 和本地网络的权限时选择“允许”。这要求 Mac 的键盘布局为美式。

之后，Mac 个人文件夹里的 Henge 文件夹就等同于“文件 › Henge › 共享”。在 Mac 上复制的内容也会复制到设备上，而“粘贴”按钮会把设备上的内容粘贴到 Mac 上。

## 已知限制

- 在 macOS 内登录 Apple 账号会失败，提示验证错误。
- 图形只在 macOS 自带应用、Chrome、Firefox、VS Code 和 Discord 上测试过。其他应用可能绘制异常。
- 登录后的前几分钟，macOS 会在后台忙着启动，因此应用打开得比较慢。
- 每次启动 Henge 只能运行一台 Mac。要再启动一台，或在重启／关机 macOS 之后重新启动，请退出 Henge 再打开。
- iPadOS 会自己保留一些键盘快捷键，例如 Command-Tab。
- 这是模拟运行，所以比真正的 Mac 慢。

## 截图

<table>
  <tr>
    <td align="center" colspan="3"><img src="Screenshots/ipad.jpg" alt="iPad 上的 Discord"><br><sub>iPad</sub></td>
  </tr>
  <tr>
    <td align="center" width="33%"><img src="Screenshots/macs.png" alt="Macs"><br><sub>Macs</sub></td>
    <td align="center" width="33%"><img src="Screenshots/trackpad.png" alt="触控板"><br><sub>触控板</sub></td>
    <td align="center" width="33%"><img src="Screenshots/install.png" alt="安装 macOS"><br><sub>安装 macOS</sub></td>
  </tr>
</table>

<sub>在 Mac 上截图：App 自身的界面配上示例数据，包含 iPad 和 iPhone 两种尺寸，画面来自 Henge 的渲染器。</sub>

## 构建

**`main` 处在两次发行之间，无法直接从源码构建。** 正在开发的内容都放在这里，等它完成后，补齐它的那个文件会随每次发行一起提供。想用 Henge 请安装[最新发行版](https://github.com/Leviidev/Henge/releases)；想自己构建请检出某个发行标签。

需要装有 Xcode 27 或更高版本的 Mac，以及 `xcodegen`。Henge 从位于 `~/Documents/Coding/Husk` 的、已构建好的 [Husk](https://github.com/Leviidev/Husk) 检出中获取 StikJIT、设备端配对、libslirp 和 glib（可通过设置 `HUSK` 指定其他路径）：

```bash
ios/scripts/fetch_deps.sh
tools/build_ios_restore.sh
make ios-lib
ios/scripts/package_ipa.sh
```

以上会生成 `~/Desktop/Henge.ipa`，而 `package_ipa.sh --trollstore` 会写出 `Henge.tipa`。

`make` 会为 Mac 构建引擎 `build/hengevm`，`make test` 会运行它的测试。

## 许可

GPL-2.0-or-later。Henge 编译进了 usbmuxd（GPLv2 或 GPLv3）以及来自 Husk 的代码（GPL-2.0-or-later），因此发布的二进制属于 GPL 合并作品。它不能上架 App Store。详见 [docs/licensing.md](docs/licensing.md)。

macOS 和 Mac 的启动 ROM 属于 Apple，不属于 Henge。安装时 Henge 会从 Apple 下载这两者。
