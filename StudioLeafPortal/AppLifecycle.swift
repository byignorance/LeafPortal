import AppKit
import FirebaseCore
import UserNotifications

extension Notification.Name {
    static let studioLeafPortalDidFinishLaunching = Notification.Name("StudioLeafPortal.AppLifecycle.didFinishLaunching")
}

@MainActor
final class AppLifecycle: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private weak var mainWindow: NSWindow?
    private weak var cloudSyncCoordinator: PortalCloudSyncCoordinator?
    private var isHandlingTerminationSync = false
    private var hasConfiguredNotificationCenter = false
    private var hasPostedLaunchReadyNotification = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func registerWindow() {
        mainWindow = NSApp.windows.first { $0.identifier?.rawValue == "main" } ?? NSApp.windows.first

        guard let window = mainWindow else {
            return
        }

        window.title = "studioLEAF Portal"
        window.identifier = NSUserInterfaceItemIdentifier("main")
        window.minSize = NSSize(width: 1100, height: 720)
        configureNotificationCenterIfNeeded()
    }

    func registerCloudSyncCoordinator(_ coordinator: PortalCloudSyncCoordinator) {
        cloudSyncCoordinator = coordinator
    }

    func openMainWindow() {
        if mainWindow == nil {
            registerWindow()
        }

        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        configureNotificationCenterIfNeeded()
    }

    private func configureNotificationCenterIfNeeded() {
        guard !hasConfiguredNotificationCenter else {
            if !hasPostedLaunchReadyNotification {
                hasPostedLaunchReadyNotification = true
                NotificationCenter.default.post(name: .studioLeafPortalDidFinishLaunching, object: nil)
            }
            return
        }

        hasConfiguredNotificationCenter = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            UNUserNotificationCenter.current().delegate = self

            if !self.hasPostedLaunchReadyNotification {
                self.hasPostedLaunchReadyNotification = true
                NotificationCenter.default.post(name: .studioLeafPortalDidFinishLaunching, object: nil)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isHandlingTerminationSync else {
            return .terminateLater
        }

        guard let cloudSyncCoordinator, cloudSyncCoordinator.hasPendingLocalChanges else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "동기화되지 않은 설정 변경 사항이 있습니다."
        alert.informativeText = "종료 전에 클라우드로 동기화할까요?"
        alert.addButton(withTitle: "동기화 후 종료")
        alert.addButton(withTitle: "동기화 없이 종료")
        alert.addButton(withTitle: "취소")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            isHandlingTerminationSync = true
            Task { @MainActor in
                let didSync = await cloudSyncCoordinator.syncPendingChangesBeforeTermination()
                isHandlingTerminationSync = false

                if didSync {
                    sender.reply(toApplicationShouldTerminate: true)
                } else {
                    let failureAlert = NSAlert()
                    failureAlert.alertStyle = .critical
                    failureAlert.messageText = "설정 동기화에 실패했습니다."
                    failureAlert.informativeText = "종료를 취소했습니다. 네트워크 또는 계정 상태를 확인한 뒤 다시 시도하세요."
                    failureAlert.addButton(withTitle: "확인")
                    failureAlert.runModal()
                    sender.reply(toApplicationShouldTerminate: false)
                }
            }
            return .terminateLater
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }
}
