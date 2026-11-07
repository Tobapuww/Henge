# Henge 的工作原理

一台不需要 hypervisor 的虚拟 Mac：arm64 客户机代码通过 arm64 到 arm64 的 JIT
运行，而不是借助硬件虚拟化，因此同一套引擎也能跑在 iOS 上——在 iOS 上应用无权访问
hypervisor。引擎在 Mac 上构建和测试（`build/hengevm`），并链接进 iPhone 应用
（`make ios-lib`）。

## 目录结构

- `core/`：客户机 CPU 状态、块翻译器、软件 MMU 以及异常处理。
- `devices/`：虚拟 Mac 的各种设备（中断控制器、定时器、UART、RTC、
  配置区、AES、带 virtio 块设备的 PCIe、网络、输入、声音与 USB，
  以及虚拟 GPU）。
- `host/`：引擎外围的运行环境（内存、JIT 区域、磁盘文件、
  安装与 USB 的中间层，以及 Mac 上的命令行工具）。
- `ios/`：iPhone 应用。参见 [ios/README.md](../ios/README.md)。
- `tests/`：在 Mac 上运行的指令级和块级测试。
- `third_party/`：来自上游源码的恢复所需组件栈。参见
  [licensing.md](licensing.md)。

## 翻译器如何工作

客户机与宿主都是 arm64，所以大多数客户机指令会被原样复制进翻译块。
只有以下几类会被改写：

- 加载与存储，它们经过客户机 MMU（内联 TLB，未命中及设备访问走慢速路径）；
- PC 相对指令与分支，会把客户机 PC 填进去；
  同页分支直接链接到目标块，条件分支也一样，跨页分支则要确认该页仍然映射着同一段代码。
  间接分支经过一个小缓存，未命中时回落到调度器，
  返回则走每 CPU 的返回表；
- 系统寄存器访问、异常，以及会影响客户机状态的屏障指令，这些会调用辅助函数；
- 指针认证指令，会变成剥离操作或空操作，因为宿主的密钥不可能是客户机的；
- 任何用到翻译器保留寄存器的指令；这些寄存器改放在客户机上下文中保存。
  客户机的 x6、x7、x15、x18 和 x28 保存在 CPU 上下文里，
  因此宿主的 x6、x7 和 x15 可作空闲暂存使用。

每个块都分为热路径和冷路径两部分，这样很少走到的路径不会夹在常走的路径中间。

客户机与宿主都使用 16 KB 页，因此客户机内存可以直接映射到宿主页上。

## 设备模型

这台机器遵循 QEMU 开源 `vmapple` 机型（QEMU 中的 hw/vmapple，GPL-2.0-or-later）
的内存布局与设备。那份代码是设备行为的参考，`devices/aes.c` 的命令与寄存器布局
就取自其中。这里没有任何内容来自 Virtualization.framework。

## 图形

macOS 通过 Apple 的半虚拟化 GPU 绘制。iOS 没有 ParavirtualizedGraphics
框架，因此由 `devices/pvg_lite.c` 接收客户机的命令流，
再由 `devices/pvg_metal.m` 用 Metal 重放。

## 启动 ROM

虚拟 Mac 运行的第一段代码是 Apple 的 AVPBooter，它负责启动 macOS；如果是安装，
它会在 DFU 模式下等待。它位于 macOS 的系统镜像里，而从 macOS 15 起这些镜像都是
加密的，但 Apple 的 macOS 14.6.1 恢复镜像中的那个没有加密，而且它的 ROM 能运行
更新版本的系统。`ios/Henge/BootROM.swift` 从 Apple 获取它：该文件属于那个镜像中
一个压缩块的一部分，因此一次不到 1 兆字节的请求就能取到全部内容。取回之后，
它用 SHA-256 哈希校验结果。全程不做任何解密。

## 共享

`host/share.c` 是一个小型 WebDAV 服务器，因为 macOS 内置了 WebDAV 客户端。
客户机通过 10.0.2.4 访问它，用户态网络会把这个地址接到 App 存储里的一个
Unix socket：没有开放任何 TCP 端口，因此设备上的其他 App 无法连进来。
在 `/.henge/` 下它还提供剪贴板，以及安装 `tools/henge-agent.m` 所需的内容——
那是一个在 macOS 内以 LaunchAgent 运行的小辅助程序，会把该文件夹挂载到 `~/Henge`
并跟随剪贴板。App 只键入设置命令，从不按 Return：它看不到 Mac 上是谁在接收键盘输入。

## 安装 macOS（无需 Mac）

`hengevm --install IPSW`（以及 iOS App 里的“安装 macOS”）会像
Virtualization.framework 的安装器那样，把 macOS 装到一台空白机器上：启动 ROM
以 DFU 模式启动（配置 `run_installer`）并作为一个 USB 设备出现，然后通过这条链路
执行标准的恢复流程。Apple 的签名服务器会像对待任何 Mac 一样，按这台机器的 ECID
对启动链做个性化处理；宿主上不会解密或修改任何东西（加密镜像按原样送给客户机，
由恢复系统自己索取密钥；宿主只负责获取它指定的 URL）。

- USB 端口：Apple 的 virtio USB 设备控制器，内核看到的是 PCI 0x106b:0x1a01
  （`AppleVirtIOUSBDeviceController`），而 AVPBooter 和 iBoot 用的是启动 ROM
  bdif MMIO 传输的通道 0x100000（devices/virtio_usb.c、devices/bdif.c）。
  请求（宿主到客户机）携带 {u32 len, u8 endpoint, u8 type} 以及数据；
  响应则是 {u8 type, u8 endpoint} 以及数据。
- 宿主一侧：libirecovery、usbmuxd 和 idevicerestore（third_party 中的上游源码；
  其中针对启动 ROM 的漏洞利用被去掉了）链接到 host/libusb_shim.c——那是一个
  libusb，它唯一的设备就是该端口。usbmuxd 以 16 KB 为单位传输（每个请求在设备侧
  就是一次读取），而 ASR 会等待慢速磁盘。
- iOS：tools/build_ios_restore.sh 构建同一套组件栈（其中 libplist、
  libimobiledevice、libtatsu、libzip、mbedtls 仅用于编译），
  并由 host/curl_shim.m 把 libcurl 的 easy API 架在 NSURLSession 之上。
