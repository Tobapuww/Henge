# 色彩探针

逐阶段测量显示通路，让有关色彩的抱怨可以用数字来定论。事件与文件的参考说明见
`devices/pvg_colorprobe.h` 的头部注释。命令：`tools/colorprobe/probe.sh help`。

## 已知情况

- macOS 通过一块 1920x1080 的 RGBA16Float 表面（fourcc `RGhA`）显示它的桌面。
  使用带 gamma 的显示描述文件（sRGB、Display P3、Generic RGB）时，客户机在其中写入的是
  **显示编码后**的数值：CSS 灰色 128 到达时是 0.5020。2026-11-06 在运行
  macOS 15.6.1 的 iPhone 17 Pro 上测得。
- `hv_half_mode`（`devices/pvg_metal.m`）决定该表面如何呈现，三处都用到它
  （屏幕着色器、`half_to_byte`、快照）：`encoded`（默认）原样传递数值；`linear`
  会应用 sRGB 编码，也就是修复前的行为，只对线性描述文件（例如 ACES CG Linear）
  才正确。修复前的默认行为编码了两次，这正是屏幕发白的原因。
- 黑色、白色和纯色三原色经过任何传递函数都不变，所以判断时要用中间调的颜色。

## 步骤

1. **启动**：用 `probe.sh launch`。重新启动会猝然中断正在运行的客户机：请先让用户从苹果菜单
   关机。当 `probe.sh follow` 出现 `event=probe_start` 和 `event=color_mode` 时即为完成。
2. **显示已知颜色。** 在局域网上提供 `tools/colorprobe/testpage/`
   （`python3 -m http.server --bind <局域网 IP> --directory tools/colorprobe/testpage`，
   需先征得用户同意开放端口），并让用户在 Safari 中以 100% 缩放打开它。
   当用户说出所用的显示描述文件时即为完成。
3. **抓取**：用 `probe.sh capture`。当文件已取回，且日志中出现了该次抓取对应的
   `post_check` 行时即为完成。
4. **判定**：用 `python3 -I tools/colorprobe/swatches.py <抓取目录>`。当它说明客户机写入的是
   什么（编码或线性）、Henge 做了什么（直通或编码），且两者都与当时生效的模式一致时即为完成。
   若不一致，它会指出出问题的阶段；要做 A/B 对比，可用 `probe.sh mode linear|encoded`
   在线切换。

## 注意事项

- `probe.sh watch` 背后的 syslog 中转可能悄悄卡住。`Documents/henge.log` 才是权威记录：
  请用 `probe.sh follow` 或 `probe.sh log`。
- 指针是在屏幕着色器之后绘制的，所以 `post_check` 会报出一个指针大小的方块；
  `verdict=matches_except_pointer_sized_box` 属于通过。
- 抓取内容包含用户屏幕上显示的一切。请以数字进行分析；只有在数字无法回答时，
  才打开 PNG 预览。
