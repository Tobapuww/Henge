import SwiftUI

struct SettingsView: View {
    @ObservedObject private var jit = JITCoordinator.shared
    @AppStorage(JITCoordinator.autoEnableKey) private var jitAtLaunch = false
    @AppStorage(HardwareMouse.speedKey) private var mouseSpeed = 1.0
    @AppStorage(HardwareMouse.reverseKey) private var reverseScrolling = false
    @AppStorage(HardwareMouse.scrollSpeedKey) private var scrollSpeed = 0.3
    @AppStorage(EngineTuning.refreshKey) private var refreshRate = 60
    @AppStorage(EngineTuning.fastFlushKey) private var fastFlush = true
    @AppStorage(EngineTuning.wfiSpinKey) private var wfiSpin = false
    @AppStorage(EngineTuning.superblocksKey) private var superblocks = false

    var body: some View {
        NavigationStack {
            Form {
                Section("JIT") {
                    LabeledContent("状态", value: JITBootstrap.ready ? "已开启" : "已关闭")
                    Picker("方式", selection: $jit.method) {
                        ForEach(JITMethod.allCases) { Text($0.title).tag($0) }
                    }
                    Text(jit.method == .automatic ? jit.automaticDescription : "Henge 正在使用「\(jit.method.title)」。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("设置 JIT") { jit.showSetup = true }
                    Toggle("打开 Henge 时自动开启 JIT", isOn: $jitAtLaunch)
                    if jitAtLaunch {
                        Text("LocalDevVPN 没开时，Henge 会先连上它，然后再回到这里。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    LabeledContent("代码区", value: "\(JITBootstrap.jitBytes >> 20) MB，每次启动只申请一次")
                }
                .listRowBackground(Desk.card)
                Section("内存") {
                    LabeledContent("额外内存", value: Entitlements.increasedMemory ? "已开启" : "已关闭")
                    LabeledContent("Henge 的上限", value: ByteText.string(UInt64(Entitlements.memoryLimitAtLaunch)))
                    LabeledContent("Henge 可用", value: ByteText.string(UInt64(henge_available_memory())))
                    Text(Entitlements.increasedMemory
                         ? "开启 JIT 后，Mac 的内存不再计入这个上限。如果 iOS 拒绝这样做，就改用可用存储空间。"
                         : "这次安装没有带上“更高内存上限”的授权文件。请用带有该授权的证书重新安装 Henge。如果重装会覆盖 App 的数据，请先把你的 Mac 导出。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                if Device.isPad {
                    Section("鼠标与触控板") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("指针速度")
                            Slider(value: $mouseSpeed, in: 0.5...3)
                        }
                        Toggle("反向滚动", isOn: $reverseScrolling)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("滚动速度")
                            Slider(value: $scrollSpeed, in: 0.1...1.5)
                        }
                        Text("妙控键盘或蓝牙鼠标可以移动 Mac 的指针。指针速度的改动会在下次启动 Mac 时生效，滚动速度的改动则立即生效。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .listRowBackground(Desk.card)
                }
                Section("性能") {
                    Picker("Mac 刷新率", selection: $refreshRate) {
                        Text("60 Hz").tag(60)
                        Text("120 Hz").tag(120)
                    }
                    .pickerStyle(.segmented)
                    Toggle("更快的磁盘写入", isOn: $fastFlush)
                    Toggle("更快地从空闲中唤醒", isOn: $wfiSpin)
                    Toggle("超级块（实验性）", isOn: $superblocks)
                    Text("60 Hz 能把模拟 CPU 的更多时间留给应用。更快的磁盘写入不等待完整同步就确定顺序，但突然断电可能丢掉最后几次写入。更快地从空闲中唤醒会让空闲的 CPU 在 50 µs 内持续查看是否有新工作，代价是稍微多耗一点电。超级块让翻译后的代码越过条件分支继续执行。改动会在下次启动 Mac 时生效。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .listRowBackground(Desk.card)
                Section("日志") {
                    ShareLink(item: HengeLog.logFileURL) { Label("分享 henge.log", systemImage: "square.and.arrow.up") }
                }
                .listRowBackground(Desk.card)
            }
            .scrollContentBackground(.hidden)
            .background(Desk.page)
            .navigationTitle("设置")
        }
    }
}
