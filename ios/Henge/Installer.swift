import Foundation
import UIKit

/// A macOS restore image Apple publishes for virtual Macs (VirtualMac2,1).
struct MacOSRelease: Identifiable, Hashable {
    let id: String        // build
    let name: String
    let url: URL
    let bytes: Int64
    let note: String

    /// The builds offered, newest last. Apple's catalog (mesu.apple.com) only lists the newest;
    /// these are the same images from Apple's CDN, and Apple still signs them for virtual Macs.
    static let all: [MacOSRelease] = [
        MacOSRelease(id: "24G90", name: "macOS Sequoia 15.6.1",
                     url: URL(string: "https://updates.cdn-apple.com/2025SummerFCS/fullrestores/093-10809/CFD6DD38-DAF0-40DA-854F-31AAD1294C6F/UniversalMac_15.6.1_24G90_Restore.ipsw")!,
                     bytes: 16_035 << 20, note: "推荐：Henge 测试所用的版本。"),
        MacOSRelease(id: "25G83", name: "macOS Tahoe 26.6.2",
                     url: URL(string: "https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-75212/A2A24B94-1FC1-45A3-93F7-C51B02AF1F4D/UniversalMac_26.6.2_25G83_Restore.ipsw")!,
                     bytes: 18_856 << 20, note: "尚未在 Henge 上测试。"),
        MacOSRelease(id: "26B123", name: "macOS 27.2",
                     url: URL(string: "https://updates.cdn-apple.com/2026FallFCS/c9671975-52db-4fb5-9af2-00217169ba8d/UniversalMac_27.2_26B123_Restore.ipsw")!,
                     bytes: 24_409 << 20, note: "最新版本。尚未在 Henge 上测试。"),
    ]
}

/// Downloads a restore image and installs it on a new virtual Mac, on the
/// iPhone: the machine boots its ROM in DFU mode and the restore runs over its
/// USB port, as Virtualization.framework's installer does on a Mac.
@MainActor
final class Installer: NSObject, ObservableObject {
    static let shared = Installer()

    enum Phase: Equatable {
        case idle
        case downloading
        case preparing
        case installing
        case done(String)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var received: Int64 = 0
    @Published private(set) var expected: Int64 = 0
    @Published private(set) var step: Int = 0
    @Published private(set) var stepProgress: Double = 0
    @Published private(set) var machineName = ""

    private var session: URLSession?
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    nonisolated(unsafe) private var downloadTarget: URL? // set before the task starts, read by the delegate
    private var lastResumeData: Data?

    var busy: Bool {
        switch phase {
        case .downloading, .preparing, .installing: return true
        default: return false
        }
    }

    nonisolated static var imageDirectory: URL { Machines.root.appendingPathComponent("Restore images", isDirectory: true) }
    nonisolated static func imagePath(_ r: MacOSRelease) -> URL { imageDirectory.appendingPathComponent("\(r.id).ipsw") }

    /// The size of the image on this iPhone, if a whole one is there (the listed sizes are rounded).
    static func imageSize(_ r: MacOSRelease) -> Int64? {
        let values = try? imagePath(r).resourceValues(forKeys: [.fileSizeKey])
        guard let size = values?.fileSize, Int64(size) > r.bytes / 2 else { return nil }
        return Int64(size)
    }

    static func haveImage(_ r: MacOSRelease) -> Bool { imageSize(r) != nil }

    static func deleteImage(_ r: MacOSRelease) { try? FileManager.default.removeItem(at: imagePath(r)) }

    /// Free space an install takes: the new Mac's disk, and the download if it is not here yet.
    static func spaceNeeded(_ r: MacOSRelease) -> Int64 { (haveImage(r) ? 0 : r.bytes) + newMacBytes }
    private static let newMacBytes: Int64 = 24 << 30

    func reset() { if !busy { phase = .idle } }

    func start(_ release: MacOSRelease, name: String, ramMB: Int, cpus: Int, keepImage: Bool) {
        guard !busy else { return }
        machineName = name
        UIApplication.shared.isIdleTimerDisabled = true // the screen locking would suspend the download and the restore
        Task {
            defer { UIApplication.shared.isIdleTimerDisabled = false }
            var made: VirtualMac?
            do {
                try checkSpace(release)
                let rom = try await BootROM.file() // before the long download, so a problem shows up at once
                HengeLog.log("install", "启动 ROM 已就绪")
                let ipsw = try await download(release)
                phase = .preparing
                var mac = try prepare(name: name, ramMB: ramMB, rom: rom)
                mac.osName = release.name
                made = mac
                phase = .installing
                try await install(mac, ipsw: ipsw, cpus: cpus)
                Machines.shared.add(mac)
                if !keepImage { try? FileManager.default.removeItem(at: ipsw) }
                HengeLog.log("install", "\(name)：已安装 \(release.name)")
                phase = .done("\(release.name) 已安装到 \(name)。请先退出 Henge（从多任务中划掉它）再重新打开，然后点“开始”。")
            } catch {
                HengeLog.log("install", "失败：\(error.localizedDescription)")
                // A half-installed Mac is no use, and its disk can be many gigabytes. The download stays.
                if let made, henge_vm_state() != 1 { try? FileManager.default.removeItem(at: made.directory) }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func checkSpace(_ r: MacOSRelease) throws {
        let free = (try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]))?
            .volumeAvailableCapacityForImportantUsage ?? 0
        let needed = Self.spaceNeeded(r)
        if free > 0 && free < needed {
            throw message("这次安装大约需要 \(ByteText.string(UInt64(needed))) 可用空间，而这台\(Device.name)只剩 \(ByteText.string(UInt64(free)))。")
        }
    }

    // MARK: Download

    private func download(_ r: MacOSRelease) async throws -> URL {
        let dest = Self.imagePath(r)
        try FileManager.default.createDirectory(at: Self.imageDirectory, withIntermediateDirectories: true)
        Machines.excludeFromBackup(Self.imageDirectory)
        if Self.haveImage(r) {
            HengeLog.log("install", "使用已下载的 \(r.name)")
            return dest
        }
        phase = .downloading
        received = 0
        expected = r.bytes
        downloadTarget = dest
        HengeLog.log("install", "正在下载 \(r.url.absoluteString)")
        for attempt in 1...20 {
            do {
                return try await downloadOnce(r.url)
            } catch let error as URLError where error.code != .cancelled && attempt < 20 {
                lastResumeData = error.downloadTaskResumeData ?? lastResumeData
                HengeLog.log("install", "下载中断（\(error.localizedDescription)），正在续传")
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        throw message("下载一直失败。")
    }

    private func downloadOnce(_ url: URL) async throws -> URL {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 120
        cfg.timeoutIntervalForResource = 48 * 3600
        let s = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
        session = s
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<URL, Error>) in
            downloadContinuation = c
            let task = lastResumeData.map { s.downloadTask(withResumeData: $0) } ?? s.downloadTask(with: url)
            lastResumeData = nil
            task.resume()
        }
    }

    // MARK: The new machine

    private func prepare(name: String, ramMB: Int, rom: URL) throws -> VirtualMac {
        // A new machine identity, as VZMacMachineIdentifier makes one: a random ECID.
        let ecid = UInt64.random(in: 1 << 40 ..< 1 << 62)
        var mac = VirtualMac(name: name, ecid: ecid, seed: 0, ramMB: ramMB, diskBytes: 64 << 30)
        (mac.screenWidth, mac.screenHeight) = Device.fittingScreen
        let fm = FileManager.default
        try fm.createDirectory(at: mac.directory, withIntermediateDirectories: true)
        Machines.excludeFromBackup(Machines.root)
        try? fm.removeItem(at: mac.rom)
        try fm.copyItem(at: rom, to: mac.rom)
        guard fm.createFile(atPath: mac.disk.path, contents: nil) else { throw message("无法创建磁盘。") }
        let h = try FileHandle(forWritingTo: mac.disk)
        try h.truncate(atOffset: UInt64(64) << 30) // sparse: blocks are only used as macOS writes them
        try h.close()
        guard henge_make_aux(mac.aux.path) == 0 else { throw message("无法创建辅助存储。") }
        let info: [String: Any] = ["name": name, "ecid": ecid, "seed": 0, "ramMB": ramMB]
        try JSONSerialization.data(withJSONObject: info).write(to: mac.directory.appendingPathComponent("machine.json"))
        mac.diskBytes = 64 << 30
        HengeLog.log("install", "新的机器 \(name)：ECID \(ecid)，64 GB 磁盘")
        return mac
    }

    // MARK: The restore

    private func install(_ mac: VirtualMac, ipsw: URL, cpus: Int) async throws {
        guard JITBootstrap.ready else { throw message("请先开启 JIT：安装器要运行 Mac 自带的恢复系统，必须用到它。") }
        // The restore needs 2 GB, whatever the Mac is set to use afterwards.
        var restoring = mac
        restoring.ramMB = max(mac.ramMB, 2048)
        let ram = GuestMemory.prepare(restoring)
        guard ram >= 2048 else { throw message("安装还需要几 GB 可用空间来充当 Mac 的内存。") }
        let work = mac.directory.appendingPathComponent("restore", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        var buffer = [CChar](repeating: 0, count: 256)
        let rc = henge_vm_install(mac.rom.path, mac.disk.path, mac.aux.path, mac.ecid, ipsw.path, work.path, ram, Int32(cpus),
                                  &buffer, buffer.count)
        if rc != 0 { throw message(String(cString: buffer)) }
        while true {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            step = Int(henge_install_step())
            stepProgress = henge_install_progress()
            if step == 100 { break }
            if step == 101 { throw message("恢复失败。日志（“设置”，或 Documents/henge.log）里写了原因。") }
            if henge_vm_state() == 2 && step < 100 {
                // The restore ends with the machine restarting, and idevicerestore finishes a
                // little after; a stop with no result after that is a failure.
                for _ in 0..<90 where henge_install_step() < 100 { try await Task.sleep(nanoseconds: 1_000_000_000) }
                if henge_install_step() == 100 { break }
                throw message("恢复过程中机器停止了（\(String(cString: henge_vm_exit_reason()))）。")
            }
        }
        if henge_vm_state() == 1 { henge_vm_stop() }
        try? FileManager.default.removeItem(at: work)
    }

    static func stepName(_ step: Int) -> String {
        switch step {
        case 0: return "正在查找 Mac"
        case 1: return "正在启动安装器"
        case 2: return "正在写入 macOS"
        case 3: return "正在检查 macOS"
        case 4: return "正在安装固件"
        case 6, 7: return "正在安装系统文件"
        default: return "正在安装"
        }
    }

    private func message(_ text: String) -> NSError {
        NSError(domain: "Henge", code: 2, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

extension Installer: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                                totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            self.received = totalBytesWritten
            if totalBytesExpectedToWrite > 0 { self.expected = totalBytesExpectedToWrite }
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didResumeAtOffset fileOffset: Int64,
                                expectedTotalBytes: Int64) {
        Task { @MainActor in self.received = fileOffset }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The file is gone when this returns: move it now, on this thread.
        let target = self.downloadTarget
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        do {
            guard let target, status == 200 || status == 206 else {
                throw NSError(domain: "Henge", code: 3, userInfo: [NSLocalizedDescriptionKey: "Apple 的服务器返回了 \(status)。"])
            }
            try? FileManager.default.removeItem(at: target)
            try FileManager.default.moveItem(at: location, to: target)
            Task { @MainActor in
                self.downloadContinuation?.resume(returning: target)
                self.downloadContinuation = nil
            }
        } catch {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: error)
                self.downloadContinuation = nil
            }
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        Task { @MainActor in
            self.downloadContinuation?.resume(throwing: error)
            self.downloadContinuation = nil
        }
    }
}
