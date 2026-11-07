# 许可

Henge 采用 GPL-2.0-or-later（[LICENSE](../LICENSE)）。发布的二进制属于 GPL 合并
作品，因为其中编译进了 usbmuxd 和来自 Husk 的代码，所以它不能上架 App Store。

| 代码 | 许可 | 位置 |
| --- | --- | --- |
| Henge | GPL-2.0-or-later | `core/`、`devices/`、`host/`、`ios/`、`tools/` |
| 来自 Husk 的代码 | GPL-2.0-or-later | `ios/Henge/JIT/`、`HengeLog.swift`、`Native/henge-ios-jit.*`、`henge-brk.S`、`HengeJITHelper/` |
| QEMU 的 vmapple AES 设备（作为参考） | GPL-2.0-or-later | `devices/aes.c` |
| QEMU 的 `tcg-apple-jit.h` | LGPL-2.1-or-later | `ios/Henge/Native/` |
| usbmuxd | GPL-2.0 或 GPL-3.0 | `third_party/usbmuxd` |
| idevicerestore | LGPL（见下文） | `third_party/idevicerestore` |
| libimobiledevice、libplist | LGPL-2.1，其工具为 GPL-2.0 | `third_party/` |
| libimobiledevice-glue、libirecovery、libtatsu、libusbmuxd | LGPL-2.1 | `third_party/` |
| libzip | BSD | `third_party/libzip` |
| Mbed TLS | Apache-2.0 或 GPL-2.0-or-later | `third_party/mbedtls` |
| StikJIT（Bitrise 构建会应用 `ci/stikjit-high-address.patch`） | MPL-2.0 | `ios/Henge/Resources/legal/` |
| idevice | MIT | `ios/Henge/Resources/legal/` |
| 配对库的 Rust crate | 各 crate 单独列明 | `ios/Henge/Resources/legal/LICENSES-rppairing-crates.txt` |
| libslirp、pcre2 | BSD | 由 Husk 预编译提供 |
| glib、libintl | LGPL-2.1-or-later | 由 Husk 预编译提供 |

idevicerestore 的 `COPYING` 文件是 LGPL-3.0，而其源码头部写的是 LGPL-2.1 或更高。
如果以 `COPYING` 为准，则合并后的二进制为 GPL-3.0，而 GPL-2.0-or-later 是允许这样做的。

## 不在此列

以下内容属于 Apple，上述任何许可都不适用于它们：

- **macOS**：Henge 会在安装时从 Apple 下载。
- **启动 ROM**：`AVPBooter.vmapple2.bin`。安装时 Henge 会在设备上从 Apple 的
  macOS 14.6.1 恢复镜像中获取它。它不在本仓库中，也不在 App 内。

导出的 Mac 就是那台 Mac 的一份副本，因此它的文件夹里含有 macOS 和该 ROM，
用 `tools/export_ios.sh` 制作的文件夹也一样。这些文件夹仅供你在自己的设备上使用，
不要用于分享。
