import SwiftUI
import UIKit

/// One external display scene (UIResponder makes it main-actor).
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate, ExternalScreen {
    /// Names this display's view to DisplayRouter, so one display going away leaves the others alone.
    let surface = UUID()
    var window: UIWindow?
    private var windowScene: UIWindowScene?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        windowScene = scene
        let mode = scene.screen.currentMode
        HengeLog.log("display", "已连接外接显示器：\(Int(scene.screen.nativeBounds.width))x\(Int(scene.screen.nativeBounds.height)) px，"
                   + "模式 \(mode.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "未知")，"
                   + "缩放 \(scene.screen.nativeScale)，\(scene.screen.maximumFramesPerSecond) Hz")
        LegacyExternalDisplay.shared.connect(self)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        HengeLog.log("display", "外接显示器已断开")
        LegacyExternalDisplay.shared.disconnect(self)
        windowScene = nil
    }

    func showMac(_ presentation: MacPresentation) {
        guard let windowScene else { return }
        let window = self.window ?? UIWindow(windowScene: windowScene)
        window.backgroundColor = .black
        window.rootViewController = UIHostingController(rootView: ExternalMacDisplay(presentation: presentation, surface: surface))
        window.isHidden = false
        self.window = window
        HengeLog.log("display", "Mac 已显示在外接显示器上")
    }

    /// Takes the Mac off this display: no window of ours, so iOS mirrors the phone (or the display is gone).
    func stopMac() {
        guard let window else { return }
        window.rootViewController = nil // lets SwiftUI take the screen view down, which detaches its layer
        window.isHidden = true
        self.window = nil
        HengeLog.log("display", "Mac 已离开外接显示器")
    }
}
