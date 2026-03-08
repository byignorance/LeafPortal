import AVFoundation
import AppKit
import Combine
import Foundation
import IOKit.pwr_mgt
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class SleepGuardManager: NSObject, ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case duration = "시간 설정"
        case unlimited = "무제한"
        case appExit = "앱 종료까지"

        var id: String { rawValue }
    }

    struct AppCandidate: Identifiable, Hashable {
        let name: String
        let bundleId: String

        var id: String { bundleId }
    }

    @Published var mode: Mode = .duration {
        didSet { defaults.set(mode.rawValue, forKey: Keys.mode) }
    }
    @Published var durationMinutes: Int = 30 {
        didSet { defaults.set(durationMinutes, forKey: Keys.durationMinutes) }
    }
    @Published var selectedAppBundleId = "" {
        didSet {
            defaults.set(selectedAppBundleId, forKey: Keys.selectedAppBundleId)
            refreshSelectedAppName()
        }
    }
    @Published private(set) var selectedAppName = ""
    @Published private(set) var isKeepingAwake = false
    @Published private(set) var statusText = "대기 중"
    @Published private(set) var detailText = ""
    @Published private(set) var remainingText = ""
    @Published private(set) var logs: [String] = []
    @Published var isNotificationEnabled = true
    @Published var launchAtLoginEnabled = false
    @Published var startSoundName = "bundle:countStart"
    @Published var stopSoundName = "bundle:countEnd"

    private enum Keys {
        static let mode = "StudioLeafPortal.SleepGuard.mode"
        static let durationMinutes = "StudioLeafPortal.SleepGuard.durationMinutes"
        static let selectedAppBundleId = "StudioLeafPortal.SleepGuard.selectedAppBundleId"
        static let notificationEnabled = "StudioLeafPortal.SleepGuard.notificationEnabled"
        static let launchAtLoginEnabled = "StudioLeafPortal.SleepGuard.launchAtLoginEnabled"
        static let startSoundName = "StudioLeafPortal.SleepGuard.startSoundName"
        static let stopSoundName = "StudioLeafPortal.SleepGuard.stopSoundName"
        static let logs = "StudioLeafPortal.SleepGuard.logs"
    }

    private let defaults = UserDefaults.standard
    private let oneDaySeconds = 24 * 60 * 60
    private let assertionName = "com.byignorance.leafportal.sleepguard.preventsleep" as CFString
    private let maxLogLines = 120
    private var assertionID: IOPMAssertionID = 0
    private var timer: Timer?
    private var endDate: Date?
    private var appObserver: NSObjectProtocol?
    private var targetBundleId: String?
    private var audioPlayer: AVAudioPlayer?

    override init() {
        super.init()
        restoreSettings()
        refreshSelectedAppName()
    }

    var currentModeSummary: String {
        switch mode {
        case .duration:
            return "\(max(1, durationMinutes))분 동안 절전 방지를 유지합니다."
        case .unlimited:
            return "최대 24시간 동안 절전 방지를 유지합니다."
        case .appExit:
            return selectedAppName.isEmpty
                ? "선택한 앱이 종료될 때까지 절전 방지를 유지합니다."
                : "\(selectedAppName) 종료 시 자동으로 중지합니다."
        }
    }

    var activeSessionSummary: String {
        if !isKeepingAwake {
            return currentModeSummary
        }

        switch mode {
        case .duration:
            return remainingText.isEmpty ? "시간 기준 세션이 활성화되었습니다." : "\(remainingText) 남음"
        case .unlimited:
            return "무제한 세션이 활성화되었습니다."
        case .appExit:
            return selectedAppName.isEmpty ? "대상 앱 종료를 기다리는 중입니다." : "\(selectedAppName) 종료 대기 중"
        }
    }

    var menuBarLabelText: String {
        if !remainingText.isEmpty {
            return remainingText
        }

        switch mode {
        case .duration:
            return isKeepingAwake ? "활성" : "대기"
        case .unlimited:
            return "무제한"
        case .appExit:
            return selectedAppName.isEmpty ? "앱 대기" : selectedAppName
        }
    }

    func candidateApps() -> [AppCandidate] {
        NSWorkspace.shared.runningApplications.compactMap { application in
            guard
                let bundleId = application.bundleIdentifier,
                let name = application.localizedName,
                application.activationPolicy == .regular,
                bundleId != Bundle.main.bundleIdentifier
            else {
                return nil
            }

            return AppCandidate(name: name, bundleId: bundleId)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func refreshSelectedAppName() {
        guard !selectedAppBundleId.isEmpty else {
            selectedAppName = ""
            return
        }

        selectedAppName = candidateApps().first { $0.bundleId == selectedAppBundleId }?.name ?? ""
    }

    @discardableResult
    func start() -> Bool {
        requestNotificationPermissionIfNeeded()

        switch mode {
        case .duration:
            return startForDuration(seconds: max(1, durationMinutes) * 60)
        case .unlimited:
            return startForDuration(seconds: oneDaySeconds)
        case .appExit:
            return startUntilAppTerminates(bundleId: selectedAppBundleId)
        }
    }

    func stop(reason: String = "사용자 중지") {
        clearTimer()
        removeObserver()

        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }

        isKeepingAwake = false
        endDate = nil
        targetBundleId = nil
        remainingText = ""
        statusText = reason
        detailText = "절전 방지가 중지되었습니다."
        appendLog("절전 방지 해제: \(reason)")
        sendNotification(title: "WakeUp Leaf", body: "절전 방지 해제: \(reason)")
        playSound(named: stopSoundName)
    }

    func clearLogs() {
        logs.removeAll()
        defaults.removeObject(forKey: Keys.logs)
        appendLog("절전 방지 로그 초기화")
    }

    func toggleNotification(enabled: Bool) {
        isNotificationEnabled = enabled
        defaults.set(enabled, forKey: Keys.notificationEnabled)
        if enabled {
            requestNotificationPermissionIfNeeded()
        }
        appendLog("알림 \(enabled ? "활성화" : "비활성화")")
    }

    func toggleLaunchAtLogin(enabled: Bool) {
        launchAtLoginEnabled = enabled
        defaults.set(enabled, forKey: Keys.launchAtLoginEnabled)
        applyLaunchAtLogin(enabled)
    }

    func setStartSound(_ name: String) {
        startSoundName = name
        defaults.set(name, forKey: Keys.startSoundName)
        playSound(named: name)
    }

    func setStopSound(_ name: String) {
        stopSoundName = name
        defaults.set(name, forKey: Keys.stopSoundName)
        playSound(named: name)
    }

    func importStartSound() {
        guard let url = selectLocalSoundFile() else {
            return
        }

        setStartSound(SoundOption.localFileIdentifier(for: url))
    }

    func importStopSound() {
        guard let url = selectLocalSoundFile() else {
            return
        }

        setStopSound(SoundOption.localFileIdentifier(for: url))
    }

    func previewSound(named name: String) {
        playSound(named: name)
    }

    private func restoreSettings() {
        if let rawMode = defaults.string(forKey: Keys.mode), let savedMode = Mode(rawValue: rawMode) {
            mode = savedMode
        }

        let storedDuration = defaults.integer(forKey: Keys.durationMinutes)
        if storedDuration > 0 {
            durationMinutes = storedDuration
        }

        selectedAppBundleId = defaults.string(forKey: Keys.selectedAppBundleId) ?? ""

        if let notificationEnabled = defaults.object(forKey: Keys.notificationEnabled) as? Bool {
            isNotificationEnabled = notificationEnabled
        }

        launchAtLoginEnabled = defaults.bool(forKey: Keys.launchAtLoginEnabled)
        startSoundName = normalizedWakeUpSoundIdentifier(
            defaults.string(forKey: Keys.startSoundName),
            fallback: "bundle:countStart"
        )
        stopSoundName = normalizedWakeUpSoundIdentifier(
            defaults.string(forKey: Keys.stopSoundName),
            fallback: "bundle:countEnd"
        )
        logs = defaults.stringArray(forKey: Keys.logs) ?? []
    }

    private func startForDuration(seconds: Int) -> Bool {
        guard acquireSleepAssertion() else {
            return false
        }

        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        scheduleTimer()
        targetBundleId = nil
        isKeepingAwake = true
        remainingText = format(seconds: seconds)
        statusText = "절전 방지 활성"
        detailText = "세션 동안만 메뉴바에 상태를 띄우고, 시간이 끝나면 자동으로 숨깁니다."
        appendLog("절전 방지 시작: 시간 모드 \(format(seconds: seconds))")
        sendNotification(title: "WakeUp Leaf", body: "절전 방지 시작: \(format(seconds: seconds))")
        playSound(named: startSoundName)
        return true
    }

    private func startUntilAppTerminates(bundleId: String) -> Bool {
        guard !bundleId.isEmpty else {
            statusText = "대상 앱을 먼저 선택하세요."
            detailText = "앱 종료 기준을 쓰려면 현재 실행 중인 앱을 하나 지정해야 합니다."
            appendLog("절전 방지 시작 실패: 앱 미선택")
            return false
        }

        let apps = candidateApps()
        guard let app = apps.first(where: { $0.bundleId == bundleId }) else {
            statusText = "선택한 앱이 실행 중이 아닙니다."
            detailText = "앱 목록을 새로고침한 뒤 다시 선택하세요."
            appendLog("절전 방지 시작 실패: 대상 앱 미실행")
            refreshSelectedAppName()
            return false
        }

        selectedAppBundleId = bundleId
        selectedAppName = app.name
        defaults.set(bundleId, forKey: Keys.selectedAppBundleId)

        guard acquireSleepAssertion() else {
            return false
        }

        endDate = nil
        isKeepingAwake = true
        remainingText = ""
        targetBundleId = bundleId
        statusText = "절전 방지 활성"
        detailText = "\(app.name) 종료를 기다리는 동안 메뉴바에서 상태를 확인할 수 있습니다."
        observeAppTermination()
        appendLog("절전 방지 시작: 앱 종료 감시 (\(app.name))")
        sendNotification(title: "WakeUp Leaf", body: "\(app.name) 종료 시까지 절전 방지를 유지합니다.")
        playSound(named: startSoundName)
        return true
    }

    private func acquireSleepAssertion() -> Bool {
        if isKeepingAwake {
            stop(reason: "재설정")
        }

        var newAssertionID: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            assertionName,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            statusText = "절전 방지 권한을 얻지 못했습니다."
            detailText = "시스템 assertion 획득 실패: \(result)"
            appendLog("절전 방지 시작 실패: kIOReturn \(result)")
            return false
        }

        assertionID = newAssertionID
        appendLog("시스템 절전 억제 assertion 획득")
        return true
    }

    private func scheduleTimer() {
        clearTimer()
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(handleTimerTick), userInfo: nil, repeats: true)
    }

    private func clearTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard isKeepingAwake, let endDate else {
            return
        }

        let remaining = Int(endDate.timeIntervalSinceNow)
        if remaining <= 0 {
            appendLog("설정 시간 만료로 절전 방지 자동 종료")
            stop(reason: "설정 시간 종료")
            return
        }

        remainingText = format(seconds: remaining)
    }

    @objc
    private func handleTimerTick() {
        tick()
    }

    private func observeAppTermination() {
        removeObserver()
        appObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                let bundleId = application.bundleIdentifier
            else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self, bundleId == self.targetBundleId else {
                    return
                }

                self.stop(reason: "\(application.localizedName ?? "대상 앱") 종료 후 자동 중지")
                self.appendLog("\(application.localizedName ?? "대상 앱") 종료 감지")
            }
        }
    }

    private func removeObserver() {
        if let appObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appObserver)
            self.appObserver = nil
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            statusText = "포털 앱 자동 실행은 macOS 13 이상에서만 지원됩니다."
            detailText = "현재 시스템에서는 StudioLeaf Portal 로그인 자동 실행을 사용할 수 없습니다."
            appendLog("포털 앱 로그인 자동 실행 미지원")
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
                appendLog("포털 앱 로그인 자동 실행 활성화")
            } else {
                try SMAppService.mainApp.unregister()
                appendLog("포털 앱 로그인 자동 실행 비활성화")
            }
        } catch {
            launchAtLoginEnabled = false
            defaults.set(false, forKey: Keys.launchAtLoginEnabled)
            statusText = "포털 앱 자동 실행 설정 실패"
            detailText = error.localizedDescription
            appendLog("포털 앱 로그인 자동 실행 설정 실패: \(error.localizedDescription)")
        }
    }

    private func requestNotificationPermissionIfNeeded() {
        guard isNotificationEnabled else {
            return
        }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
        }
    }

    private func sendNotification(title: String, body: String) {
        guard isNotificationEnabled else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func playSound(named name: String) {
        audioPlayer?.stop()
        audioPlayer = nil

        guard name != "none" else {
            return
        }

        if let option = SoundOption.option(for: name) {
            switch option.source {
            case .system:
                NSSound(named: NSSound.Name(option.name))?.play()
            case .bundled(let fileExtension):
                guard let url = bundledSoundURL(named: option.name, extension: fileExtension) else {
                    return
                }
                playAudio(from: url)
            }
            return
        }

        if let url = SoundOption.localFileURL(from: name) {
            playAudio(from: url)
            return
        }

        if name.contains("/") {
            playAudio(from: URL(fileURLWithPath: name))
        }
    }

    private func normalizedWakeUpSoundIdentifier(_ value: String?, fallback: String) -> String {
        guard let value, !value.isEmpty else {
            return fallback
        }

        if value.hasPrefix("system:") || value.hasPrefix("bundle:") || value.hasPrefix("file:") {
            return value
        }

        if value == "countStart" || value == "countEnd" {
            return "bundle:\(value)"
        }

        return "system:\(value)"
    }

    private func selectLocalSoundFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "WakeUp Leaf 사운드 선택"
        panel.message = "시작 또는 종료에 사용할 로컬 사운드 파일을 선택하세요."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func bundledSoundURL(named name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension)
            ?? Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Sound")
    }

    private func playAudio(from url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
        } catch {
            NSSound.beep()
        }
    }

    private func appendLog(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let now = formatter.string(from: Date())

        logs.insert("[\(now)] \(message)", at: 0)
        if logs.count > maxLogLines {
            logs.removeLast(logs.count - maxLogLines)
        }
        defaults.set(logs, forKey: Keys.logs)
    }

    private func format(seconds: Int) -> String {
        let total = max(0, seconds)
        let hour = total / 3600
        let minute = (total % 3600) / 60
        let second = total % 60

        if hour > 0 {
            return String(format: "%02d:%02d:%02d", hour, minute, second)
        }

        return String(format: "%02d:%02d", minute, second)
    }

    func makeCloudSettings() -> PortalCloudSleepGuardSettings {
        PortalCloudSleepGuardSettings(
            mode: mode.rawValue,
            durationMinutes: durationMinutes,
            isNotificationEnabled: isNotificationEnabled,
            startSoundName: cloudSafeWakeUpSoundIdentifier(startSoundName, fallback: "bundle:countStart"),
            stopSoundName: cloudSafeWakeUpSoundIdentifier(stopSoundName, fallback: "bundle:countEnd")
        )
    }

    func applyCloudSettings(_ settings: PortalCloudSleepGuardSettings) {
        mode = Mode(rawValue: settings.mode) ?? .duration
        durationMinutes = max(1, settings.durationMinutes)
        isNotificationEnabled = settings.isNotificationEnabled
        defaults.set(isNotificationEnabled, forKey: Keys.notificationEnabled)
        startSoundName = normalizedWakeUpSoundIdentifier(settings.startSoundName, fallback: "bundle:countStart")
        stopSoundName = normalizedWakeUpSoundIdentifier(settings.stopSoundName, fallback: "bundle:countEnd")
        defaults.set(startSoundName, forKey: Keys.startSoundName)
        defaults.set(stopSoundName, forKey: Keys.stopSoundName)
    }

    private func cloudSafeWakeUpSoundIdentifier(_ value: String, fallback: String) -> String {
        value.hasPrefix(SoundOption.localFilePrefix) ? fallback : value
    }
}
