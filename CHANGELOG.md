# 更新日志

这个分支把 [Leviidev/Henge](https://github.com/Leviidev/Henge) 各个社区分支中的修复
汇集到一次构建里，并做了少量补充，主要面向 iPad（测试机型：iPad Pro M4）。
每项改动都在 git 历史中保留了原作者。

## 0.2.0 (100)

基于上游 `main` 的 b744a78。

### 显示色彩
- macOS 不再显得发白：半精度浮点的显示画面按 WindowServer 写入时的样子呈现，
  而不会被重复做一次 sRGB 编码。诊断用的色彩探针（`HV_COLOR_PROBE`）。
  —— [hungbenjamin402](https://github.com/hungbenjamin402/Henge)
- 针对 iPad 的 P3 面板做色彩匹配（Mac 的画面按 sRGB 标记），会话的“详情”里提供实时的
  *色彩匹配*、*线性色彩转换* 与 *亮度* 控制项。
  —— [sonnx0868](https://github.com/sonnx0868/Henge)

### iPad、妙控键盘与触控板
- 校准了妙控键盘的滚动，输入更顺滑，并在“详情”中显示设备的温度状态。
- iPad 上的指针更小、更锐利，并提供大小和锐利边缘两个开关。
- 视频平面按 IOSurface 的真实布局拷贝。
  —— 以上三项：[sonnx0868](https://github.com/sonnx0868/Henge)
- iPadOS 自带的隐藏键盘键会结束输入，让 Mac 重新占满整屏。
  —— [gavinnolan](https://github.com/gavinnolan/Henge)
- iPad 上 Mac 的屏幕模式：*视网膜*（面板的每一个像素，2 倍密度）、*性能优先*
  （约少 30% 的像素）、*适配这台 iPad* 与 *16:9*。视网膜为可选：它会消耗大量
  模拟 GPU 运算。
  —— 视网膜来自 [AdamLovattDevOps](https://github.com/AdamLovattDevOps/Henge)，性能优先来自 sonnx0868
- 支持 120 Hz ProMotion，8 GB 的 iPad 默认分配 4 GB 内存，另附采样分析器和 GPU
  命令跟踪／着色器导出工具。 —— [AdamLovattDevOps](https://github.com/AdamLovattDevOps/Henge)

### 外接显示器
- 在 iOS 27 之前（iOS 17–26）也能把 Mac 显示到外接屏幕上，拔掉显示器后画面回到
  设备上，并且断开一个显示器不会再让其他显示器卡住。
  —— [hungbenjamin402](https://github.com/hungbenjamin402/Henge)

### JIT
- 启动时若 LocalDevVPN 未开启，会先连接它。
  —— [braedonsaunders](https://github.com/braedonsaunders/Henge)（上游 PR #3）
- 蜂窝网络下的 JIT：会说明失败原因并重试，而不是一律归咎于 LocalDevVPN。
- 个人（免费）团队也能给应用签名：`HENGE_ENTITLEMENTS`。
  —— 以上两项：[hungbenjamin402](https://github.com/hungbenjamin402/Henge)

### 本分支新增
- **性能设置**（设置 → 性能），每次启动 Mac 时应用：
  - *Mac 刷新率*：默认 60 Hz。每一帧都要模拟并重放，所以 120 Hz 会让留给应用的
    CPU 减半；仍可选择 120 Hz。
  - *更快的磁盘写入*（默认开）：用 `F_BARRIERFSYNC` 取代完整的 `fsync`。
  - *更快地从空闲中唤醒*（默认关）：空闲的 CPU 在睡眠前会先查看 50 µs 是否有工作。
  - *超级块（实验性）*（默认关）：翻译后的代码越过条件分支继续执行。
  - `Documents/henge-env.txt` 仍然可以覆盖以上全部设置。
- **隐藏会话控制条**：键盘左侧的按钮可以隐藏 Mac 上方的控制条；三根手指轻点即可
  重新显示（前三次会有提示）。会话内会关闭 iPadOS 自带的三指撤销／复制／粘贴条，
  以免相互干扰。
- 合并时保留了 Xcode 27 的构建：内置 StikJIT 辅助程序和 Liquid Glass 图标都还在
  （m4 分支中会移除它们的 Xcode 16 改动没有被引入）。
- 显示名称改回 *Henge*；版本 0.2.0 (100)，以便侧载商店将其视为更新。

### 未包含
- `HV_GROUPS`（分组内存访问）：上游实测并没有更快，而且会更早占满 JIT 区域。

## 构建

与上游一致（参见 README）：Xcode 27、`xcodegen`、`meson`、带 `aarch64-apple-ios`
目标的 `rustup`，以及位于 `~/Documents/Coding/Husk` 的、已构建好的
[Husk](https://github.com/Leviidev/Husk)。Henge 只需要 Husk 的
`build_ios.sh libffi glib libslirp` 和 `build_rppairing_ios.sh`。
