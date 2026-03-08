import AppKit
import AVFoundation
import Combine
import Foundation
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class PortalViewModel: ObservableObject {
    @Published var selectedSection: PortalSection = .overview
    @Published var watchMode: WatchMode = .premiere {
        didSet {
            defaults.set(watchMode.rawValue, forKey: Keys.watchMode)
            if !hasCustomTargetApplicationName {
                targetApplicationName = watchMode.defaultApplicationName
            }
        }
    }
    @Published var detectionMode: DetectionMode = .simple {
        didSet {
            defaults.set(detectionMode.rawValue, forKey: Keys.detectionMode)
        }
    }
    @Published var targetKind: MonitorTargetKind = .folder {
        didSet {
            defaults.set(targetKind.rawValue, forKey: Keys.targetKind)
            if !isMonitoring {
                if let storedPath = defaults.string(forKey: pathDefaultsKey(for: targetKind)) {
                    selectedPath = URL(fileURLWithPath: storedPath)
                } else {
                    selectedPath = nil
                }
            }
        }
    }
    @Published var selectedPath: URL?
    @Published var targetApplicationName = "" {
        didSet {
            let trimmed = targetApplicationName.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != targetApplicationName {
                targetApplicationName = trimmed
                return
            }
            hasCustomTargetApplicationName = !trimmed.isEmpty && trimmed != watchMode.defaultApplicationName
            defaults.set(trimmed, forKey: Keys.targetApplicationName)
            adobeProcessSummary = trimmed.isEmpty ? "대상 프로그램 미지정" : "\(trimmed) 대기 중"
        }
    }
    @Published var status: MonitorState = .idle
    @Published var statusLine = "파일 또는 폴더를 선택한 뒤 감시를 시작하세요."
    @Published var detailLine = "Simple 또는 Advanced 모드를 선택하여 진행하세요."
    @Published var latestOutputName = "아직 감지된 렌더가 없습니다."
    @Published var inlineAlert: String?
    @Published var progressValue: Double = 0
    @Published var observedFileCount = 0
    @Published var lastActivityDate: Date?
    @Published var notificationEnabled = true {
        didSet { defaults.set(notificationEnabled, forKey: Keys.notificationEnabled) }
    }
    @Published var soundEnabled = true {
        didSet { defaults.set(soundEnabled, forKey: Keys.soundEnabled) }
    }
    @Published var preliminarySoundName = "system:Pop" {
        didSet { defaults.set(preliminarySoundName, forKey: Keys.preliminarySoundName) }
    }
    @Published var completionSoundName = "bundle:RenderDone" {
        didSet { defaults.set(completionSoundName, forKey: Keys.completionSoundName) }
    }
    @Published var messagesEnabled = false {
        didSet { defaults.set(messagesEnabled, forKey: Keys.messagesEnabled) }
    }
    @Published var messagesRecipient = "" {
        didSet {
            let trimmed = messagesRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed != messagesRecipient {
                messagesRecipient = trimmed
                return
            }
            defaults.set(trimmed, forKey: Keys.messagesRecipient)
        }
    }
    @Published var messagesServiceMode: MessagesServiceMode = .automatic {
        didSet { defaults.set(messagesServiceMode.rawValue, forKey: Keys.messagesServiceMode) }
    }
    @Published var messagesTemplate = "Render Notification: {target} 렌더 완료 ({time})" {
        didSet { defaults.set(messagesTemplate, forKey: Keys.messagesTemplate) }
    }
    @Published var discordEnabled = false {
        didSet { defaults.set(discordEnabled, forKey: Keys.discordEnabled) }
    }
    @Published var webhookURLString = "" {
        didSet { defaults.set(webhookURLString, forKey: Keys.webhookURL) }
    }
    let preliminaryAlertSeconds = 5
    let idleThresholdSeconds = 15
    let advancedCompletionSeconds = 3
    @Published var isMonitoring = false
    @Published var adobeProcessSummary = "Adobe 앱 미감지"
    @Published var runningApplicationNames: [String] = []
    @Published private(set) var recentTargetApplications: [String] = []
    @Published var activityLogs: [ActivityLogEntry] = []
    @Published private(set) var iconSelections: [PortalIconRole: String] = [:]
    @Published private(set) var customIconAssets: [CustomIconAsset] = []
    @Published var iconManagementMessage: String?
    @Published private(set) var hasCustomTargetApplicationName = false

    private enum Keys {
        static let watchMode = "StudioLeafPortal.watchMode"
        static let detectionMode = "StudioLeafPortal.detectionMode"
        static let targetKind = "StudioLeafPortal.targetKind"
        static let selectedFilePath = "StudioLeafPortal.selectedFilePath"
        static let selectedFolderPath = "StudioLeafPortal.selectedFolderPath"
        static let targetApplicationName = "StudioLeafPortal.targetApplicationName"
        static let notificationEnabled = "StudioLeafPortal.notificationEnabled"
        static let soundEnabled = "StudioLeafPortal.soundEnabled"
        static let preliminarySoundName = "StudioLeafPortal.preliminarySoundName"
        static let completionSoundName = "StudioLeafPortal.completionSoundName"
        static let messagesEnabled = "StudioLeafPortal.messagesEnabled"
        static let messagesRecipient = "StudioLeafPortal.messagesRecipient"
        static let messagesServiceMode = "StudioLeafPortal.messagesServiceMode"
        static let messagesTemplate = "StudioLeafPortal.messagesTemplate"
        static let discordEnabled = "StudioLeafPortal.discordEnabled"
        static let webhookURL = "StudioLeafPortal.webhookURL"
        static let iconSelectionPrefix = "StudioLeafPortal.iconSelection."
        static let customIconAssets = "StudioLeafPortal.customIconAssets"
        static let recentTargetApplications = "StudioLeafPortal.recentTargetApplications"
    }

    private let defaults = UserDefaults.standard
    private let monitorEngine = RenderNotificationMonitorEngine()
    private var audioPlayer: AVAudioPlayer?
    private var fadeOutTimer: Timer?
    private var activeAudioToken = UUID()
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        notificationEnabled = defaults.object(forKey: Keys.notificationEnabled) as? Bool ?? true
        soundEnabled = defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true
        preliminarySoundName = normalizedSystemSoundIdentifier(defaults.string(forKey: Keys.preliminarySoundName), fallback: "Pop")
        completionSoundName = normalizedCompletionSoundIdentifier(defaults.string(forKey: Keys.completionSoundName))
        messagesEnabled = defaults.object(forKey: Keys.messagesEnabled) as? Bool ?? false
        messagesRecipient = defaults.string(forKey: Keys.messagesRecipient) ?? ""
        if let rawMessagesServiceMode = defaults.string(forKey: Keys.messagesServiceMode),
           let savedMessagesServiceMode = MessagesServiceMode(rawValue: rawMessagesServiceMode) {
            messagesServiceMode = savedMessagesServiceMode
        }
        messagesTemplate = defaults.string(forKey: Keys.messagesTemplate) ?? messagesTemplate
        discordEnabled = defaults.bool(forKey: Keys.discordEnabled)
        webhookURLString = defaults.string(forKey: Keys.webhookURL) ?? ""
        if let rawMode = defaults.string(forKey: Keys.watchMode), let mode = WatchMode(rawValue: rawMode) {
            watchMode = mode
        }
        if let rawDetectionMode = defaults.string(forKey: Keys.detectionMode),
           let savedDetectionMode = DetectionMode(rawValue: rawDetectionMode) {
            detectionMode = savedDetectionMode
        }

        if let rawTargetKind = defaults.string(forKey: Keys.targetKind),
           let savedTargetKind = MonitorTargetKind(rawValue: rawTargetKind) {
            targetKind = savedTargetKind
        }

        let savedTargetApplicationName = defaults.string(forKey: Keys.targetApplicationName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        targetApplicationName = savedTargetApplicationName.isEmpty ? watchMode.defaultApplicationName : savedTargetApplicationName
        hasCustomTargetApplicationName = targetApplicationName != watchMode.defaultApplicationName
        recentTargetApplications = defaults.stringArray(forKey: Keys.recentTargetApplications) ?? []

        if let storedPath = defaults.string(forKey: pathDefaultsKey(for: targetKind)) {
            selectedPath = URL(fileURLWithPath: storedPath)
        }

        loadCustomIconAssets()
        loadIconSelections()
        refreshRunningApplications()

        bindMonitorCallbacks()
        appendLog(title: "StudioLeaf Portal 준비 완료", detail: "Render Notification이 대기 상태입니다.", kind: .success)
    }

    var selectedPathDisplay: String {
        if let selectedPath {
            return selectedPath.path
        }
        if detectionMode == .advanced {
            return "경로 없이 프로그램 활동만 추적할 수 있습니다."
        }
        return "선택된 경로가 없습니다."
    }

    var canStartWatching: Bool {
        if isMonitoring {
            return false
        }
        if detectionMode == .advanced {
            return !targetApplicationName.isEmpty
        }
        return selectedPath != nil
    }

    var monitoringDetailDescription: String {
        if detectionMode == .simple {
            return targetKind == .file
                ? "선택한 파일 하나의 변화를 기준으로 렌더 완료를 판정합니다."
                : "선택한 폴더 안 전체 파일의 변화를 기준으로 렌더 완료를 판정합니다."
        }

        if selectedPath == nil {
            return "\(targetApplicationName)의 CPU 사용이 렌더링 수준으로 올라간 뒤 \(advancedCompletionSeconds)초 이상 저활동이면 완료로 판정합니다."
        }

        let basis = targetKind == .file ? "선택한 파일 변화" : "선택한 폴더 전체 변화"
        return "\(basis)에 더해 \(targetApplicationName)의 CPU 활동도 함께 봅니다. CPU가 올라간 뒤 \(advancedCompletionSeconds)초 이상 저활동이면 완료로 판정합니다."
    }

    var prioritizedRunningApplications: [String] {
        var seen = Set<String>()
        var ordered: [String] = []

        let adobeApps = runningApplicationNames.filter { isAdobeRelated($0) }
        let others = runningApplicationNames.filter { !isAdobeRelated($0) }

        for name in recentTargetApplications + adobeApps + others {
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }

        return ordered
    }

    var adobeRunningApplications: [String] {
        prioritizedRunningApplications.filter(isAdobeRelated)
    }

    var otherRunningApplications: [String] {
        prioritizedRunningApplications.filter { !isAdobeRelated($0) }
    }

    func symbol(for role: PortalIconRole) -> String {
        switch selection(for: role) {
        case .system(let symbol):
            return symbol
        case .custom, .lucide:
            return role.defaultSymbol
        }
    }

    func updateSymbol(_ symbol: String, for role: PortalIconRole) {
        updateSelection(.system(symbol), for: role)
    }

    func updateLucide(_ lucideID: String, for role: PortalIconRole) {
        updateSelection(.lucide(lucideID), for: role)
    }

    func selection(for role: PortalIconRole) -> IconSelection {
        let stored = iconSelections[role] ?? encodedSelection(.system(role.defaultSymbol))
        if stored.hasPrefix("custom:"),
           let id = UUID(uuidString: String(stored.dropFirst("custom:".count))) {
            return .custom(id)
        }
        if stored.hasPrefix("lucide:") {
            return .lucide(String(stored.dropFirst("lucide:".count)))
        }
        if stored.hasPrefix("system:") {
            return .system(String(stored.dropFirst("system:".count)))
        }
        return .system(stored)
    }

    func customIcon(for role: PortalIconRole) -> CustomIconAsset? {
        guard case .custom(let id) = selection(for: role) else { return nil }
        return customIconAssets.first { $0.id == id }
    }

    func updateSelection(_ selection: IconSelection, for role: PortalIconRole) {
        let encoded = encodedSelection(selection)
        iconSelections[role] = encoded
        defaults.set(encoded, forKey: Keys.iconSelectionPrefix + role.rawValue)
    }

    func setDefaultIcon(for role: PortalIconRole) {
        updateSelection(.system(role.defaultSymbol), for: role)
    }

    func importCustomIcons() {
        let panel = NSOpenPanel()
        panel.title = "커스텀 아이콘 가져오기"
        panel.message = "PNG, JPG, PDF처럼 미리보기가 가능한 아이콘 파일을 선택하세요."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.png, .jpeg, .pdf]

        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                self?.appendCustomIcons(from: panel.urls)
            }
        }
    }

    func removeCustomIcon(_ asset: CustomIconAsset) {
        customIconAssets.removeAll { $0.id == asset.id }
        persistCustomIconAssets()

        for role in PortalIconRole.allCases where customIcon(for: role)?.id == asset.id {
            setDefaultIcon(for: role)
        }

        iconManagementMessage = "커스텀 아이콘을 제거했습니다."
    }

    func clearIconManagementMessage() {
        iconManagementMessage = nil
    }

    func previewSound(named name: String) {
        playSound(named: name)
    }

    var canSendMessagesTest: Bool {
        !messagesRecipient.isEmpty
    }

    func sendMessagesTest() {
        guard canSendMessagesTest else {
            inlineAlert = "Messages 테스트를 하려면 받는 사람을 먼저 입력하세요."
            return
        }

        let previewMessage = renderedMessagesBody(
            targetName: latestOutputName == "아직 감지된 렌더가 없습니다." ? "테스트 렌더" : latestOutputName,
            completedAt: Date()
        )

        Task {
            do {
                try await sendMessages(body: previewMessage)
                await MainActor.run {
                    appendLog(title: "Messages 테스트 전송 완료", detail: previewMessage, kind: .success)
                    inlineAlert = nil
                }
            } catch {
                await MainActor.run {
                    inlineAlert = messagesErrorText(from: error)
                    appendLog(title: "Messages 테스트 전송 실패", detail: error.localizedDescription, kind: .warning)
                }
            }
        }
    }

    func importPreliminarySound() {
        guard let url = selectLocalSoundFile() else {
            return
        }

        preliminarySoundName = SoundOption.localFileIdentifier(for: url)
        playSound(named: preliminarySoundName)
    }

    func importCompletionSound() {
        guard let url = selectLocalSoundFile() else {
            return
        }

        completionSoundName = SoundOption.localFileIdentifier(for: url)
        playSound(named: completionSoundName)
    }

    func refreshRunningApplications() {
        let names = NSWorkspace.shared.runningApplications
            .compactMap(\.localizedName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { $0 != "StudioLeafPortal" }
        runningApplicationNames = Array(Set(names)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    func selectTargetApplicationName(_ name: String) {
        targetApplicationName = name
        rememberTargetApplication(name)
    }

    func resetIconSelections() {
        for role in PortalIconRole.allCases {
            defaults.removeObject(forKey: Keys.iconSelectionPrefix + role.rawValue)
            iconSelections[role] = encodedSelection(.system(role.defaultSymbol))
        }
        appendLog(title: "아이콘 구성 초기화", detail: "기본 SF Symbols 구성이 복원되었습니다.", kind: .success)
        iconManagementMessage = "추천 아이콘 구성을 기본값으로 되돌렸습니다."
    }

    func selectTarget() {
        switch targetKind {
        case .file:
            let panel = NSSavePanel()
            panel.title = "감시할 파일 선택"
            panel.message = "특정 렌더 파일 하나만 추적하려면 파일 경로를 지정하세요."
            panel.nameFieldStringValue = "render-output.mp4"
            panel.canCreateDirectories = true
            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                Task { @MainActor in
                    self?.selectedPath = url
                    self?.persistPath(url)
                    self?.inlineAlert = nil
                }
            }
        case .folder:
            let panel = NSOpenPanel()
            panel.title = "감시할 폴더 선택"
            panel.message = "선택한 폴더 안의 파일 전체를 추적합니다."
            panel.canChooseDirectories = true
            panel.canChooseFiles = false
            panel.canCreateDirectories = true
            panel.begin { [weak self] response in
                guard response == .OK, let url = panel.url else { return }
                Task { @MainActor in
                    self?.selectedPath = url
                    self?.persistPath(url)
                    self?.inlineAlert = nil
                }
            }
        }
    }

    func openSelectedPath() {
        guard let selectedPath else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedPath])
    }

    func startWatching() {
        if detectionMode == .simple, selectedPath == nil {
            status = .warning
            inlineAlert = "감시를 시작하려면 먼저 대상 경로를 선택해야 합니다."
            return
        }

        if detectionMode == .advanced && targetApplicationName.isEmpty {
            status = .warning
            inlineAlert = "Advanced 모드에서는 추적할 프로그램 이름을 먼저 입력해야 합니다."
            return
        }

        if detectionMode == .advanced {
            rememberTargetApplication(targetApplicationName)
        }

        if notificationEnabled {
            requestNotificationPermissionIfNeeded()
        }

        inlineAlert = nil
        status = .monitoring
        statusLine = "감시가 시작되었습니다."
        detailLine = monitoringDetailDescription
        latestOutputName = selectedPath?.lastPathComponent ?? targetApplicationName
        progressValue = 0
        observedFileCount = 0
        lastActivityDate = nil
        isMonitoring = true

        monitorEngine.start(
            configuration: .init(
                mode: watchMode,
                detectionMode: detectionMode,
                targetApplicationName: targetApplicationName,
                targetKind: targetKind,
                targetURL: selectedPath,
                preliminaryThreshold: detectionMode == .simple ? TimeInterval(preliminaryAlertSeconds) : 0,
                completionThreshold: detectionMode == .simple ? TimeInterval(idleThresholdSeconds) : TimeInterval(advancedCompletionSeconds)
            )
        )

        let sessionLabel = selectedPath?.lastPathComponent ?? targetApplicationName
        appendLog(
            title: "감시 시작",
            detail: detectionMode == .advanced
                ? (selectedPath == nil ? "\(targetApplicationName) · 경로 없이 시작" : "\(sessionLabel) · \(targetApplicationName)")
                : sessionLabel,
            kind: .success
        )
        selectedSection = .renderNoti
    }

    func stopWatching() {
        monitorEngine.stop()
        isMonitoring = false
        status = .idle
        statusLine = "감시가 중지되었습니다."
        detailLine = "언제든지 다시 시작할 수 있습니다."
        progressValue = 0
        appendLog(title: "감시 중지", detail: selectedPath?.lastPathComponent ?? targetApplicationName, kind: .warning)
    }

    func clearLogs() {
        activityLogs.removeAll()
    }

    private func bindMonitorCallbacks() {
        monitorEngine.onProgress = { [weak self] progress in
            guard let self else { return }
            status = progress.preliminaryAlertSent ? .warning : .monitoring
            statusLine = progress.headline
            detailLine = progress.detail
            latestOutputName = progress.latestOutputName ?? progress.targetName
            progressValue = progress.progressValue
            observedFileCount = progress.observedFileCount
            lastActivityDate = progress.lastActivityDate
            adobeProcessSummary = progress.processSignal.summary
        }

        monitorEngine.onComplete = { [weak self] completion in
            guard let self else { return }
            Task { @MainActor in
                await self.handleCompletion(completion)
            }
        }

        monitorEngine.onPreliminaryAlert = { [weak self] alert in
            guard let self else { return }
            Task { @MainActor in
                self.handlePreliminaryAlert(alert)
            }
        }

        monitorEngine.onFailure = { [weak self] error in
            guard let self else { return }
            status = .error
            inlineAlert = error
            isMonitoring = false
            appendLog(title: "감시 오류", detail: error, kind: .error)
        }
    }

    private func handlePreliminaryAlert(_ alert: MonitorPreliminaryAlert) {
        status = .warning
        statusLine = "1차 알림을 보냈습니다."
        detailLine = "\(preliminaryAlertSeconds)초 동안 변화가 없어 잠정 정지 상태로 알렸습니다. \(idleThresholdSeconds)초까지 추가 변화가 없으면 확정 알림을 보냅니다."
        latestOutputName = alert.latestOutputName ?? alert.targetName

        let message = "1차 알림: \(alert.latestOutputName ?? alert.targetName) · \(formatter.string(from: alert.alertedAt))"

        if notificationEnabled {
            sendSystemNotification(title: "Render Notification", body: message)
        }

        if soundEnabled {
            playSound(named: preliminarySoundName)
        }

        appendLog(title: "1차 알림", detail: message, kind: .warning)
    }

    private func handleCompletion(_ completion: MonitorCompletion) async {
        isMonitoring = false
        status = .success
        statusLine = detectionMode == .advanced ? "렌더 완료를 감지했습니다." : "확정 알림을 보냈습니다."
        detailLine = detectionMode == .advanced
            ? "\(advancedCompletionSeconds)초 이상 저활동 상태가 유지되어 렌더 완료로 판정했습니다."
            : "\(idleThresholdSeconds)초 동안 변화가 없어 렌더 완료로 확정했습니다."
        progressValue = 1
        latestOutputName = completion.latestOutputName ?? completion.targetName

        let message = detectionMode == .advanced
            ? "렌더 완료 감지: \(completion.latestOutputName ?? completion.targetName) · \(formatter.string(from: completion.completedAt))"
            : "확정 알림: \(completion.latestOutputName ?? completion.targetName) · \(formatter.string(from: completion.completedAt))"

        if notificationEnabled {
            sendSystemNotification(title: "Render Notification", body: message)
        }

        if soundEnabled {
            playSound(named: completionSoundName)
        }

        appendLog(title: "렌더 완료", detail: message, kind: .success)

        if messagesEnabled, !messagesRecipient.isEmpty {
            do {
                try await sendMessages(body: renderedMessagesBody(
                    targetName: completion.latestOutputName ?? completion.targetName,
                    completedAt: completion.completedAt
                ))
                appendLog(
                    title: "Messages 전송 완료",
                    detail: "\(messagesRecipient) · \(completion.latestOutputName ?? completion.targetName)",
                    kind: .success
                )
            } catch {
                status = .warning
                inlineAlert = messagesErrorText(from: error)
                appendLog(title: "Messages 전송 실패", detail: error.localizedDescription, kind: .warning)
            }
        }

        if discordEnabled {
            appendLog(title: "Discord 연동 예정", detail: "선택됨 · Discord 채널은 아직 개발 전입니다.", kind: .warning)
        }
    }

    private func sendDiscordWebhook(message: String) async throws {
        guard let webhookURL = URL(string: webhookURLString), !webhookURLString.isEmpty else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["content": message])

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }

    private func sendMessages(body: String) async throws {
        let recipient = messagesRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recipient.isEmpty else {
            throw MessagesAutomationError.missingRecipient
        }

        let appleScript = """
        on run argv
            set targetHandle to item 1 of argv
            set messageBody to item 2 of argv
            set modeValue to item 3 of argv

            tell application "Messages"
                set chosenService to missing value
                if modeValue is "iMessagePreferred" then
                    try
                        set chosenService to 1st service whose service type = iMessage and enabled = true
                    end try
                else if modeValue is "smsIfAvailable" then
                    try
                        set chosenService to 1st service whose service type = SMS and enabled = true
                    end try
                    if chosenService is missing value then
                        try
                            set chosenService to 1st service whose service type = iMessage and enabled = true
                        end try
                    end if
                else
                    try
                        set chosenService to 1st service whose service type = iMessage and enabled = true
                    end try
                    if chosenService is missing value then
                        try
                            set chosenService to 1st service whose service type = SMS and enabled = true
                        end try
                    end if
                end if

                if chosenService is missing value then
                    try
                        set chosenService to 1st service whose enabled = true
                    end try
                end if

                if chosenService is missing value then error "사용 가능한 Messages 서비스가 없습니다."

                set targetBuddy to buddy targetHandle of chosenService
                send messageBody to targetBuddy
            end tell
        end run
        """

        var lastError: Error?
        for candidate in messagesRecipientCandidates(from: recipient) {
            do {
                try await runAppleScript(
                    appleScript,
                    arguments: [candidate, body, messagesModeArgument]
                )
                return
            } catch {
                lastError = error
            }
        }

        throw lastError ?? MessagesAutomationError.scriptFailed("Messages 전송 실패")
    }

    private func runAppleScript(_ source: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source] + arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorText = String(data: errorData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if process.terminationStatus == 0 {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(throwing: MessagesAutomationError.scriptFailed(errorText.isEmpty ? "Messages 전송 실패" : errorText))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func sendSystemNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func playSound(named name: String) {
        stopManagedAudio()

        if let option = SoundOption.option(for: name) {
            switch option.source {
            case .system:
                NSSound(named: NSSound.Name(option.name))?.play()
            case .bundled(let fileExtension):
                guard let url = bundledSoundURL(named: option.name, extension: fileExtension) else { return }
                playBundledSound(from: url)
            }
            return
        }

        if let url = SoundOption.localFileURL(from: name) {
            playBundledSound(from: url)
            return
        }

        if name.contains("/") {
            playBundledSound(from: URL(fileURLWithPath: name))
            return
        }

        NSSound(named: NSSound.Name(name))?.play()
    }

    func requestNotificationPermissionIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .sound, .alert]) { _, _ in }
    }

    private var messagesModeArgument: String {
        switch messagesServiceMode {
        case .automatic:
            return "automatic"
        case .iMessagePreferred:
            return "iMessagePreferred"
        case .smsIfAvailable:
            return "smsIfAvailable"
        }
    }

    private func messagesRecipientCandidates(from rawValue: String) -> [String] {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var candidates: [String] = []

        func appendCandidate(_ value: String) {
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            if !candidates.contains(normalized) {
                candidates.append(normalized)
            }
        }

        appendCandidate(trimmed)

        let digitsOnly = trimmed.filter(\.isNumber)
        if !digitsOnly.isEmpty {
            appendCandidate(digitsOnly)
        }

        if digitsOnly.hasPrefix("82"), digitsOnly.count >= 10 {
            appendCandidate("+" + digitsOnly)
        }

        if digitsOnly.hasPrefix("010"), digitsOnly.count == 11 {
            let domestic = "0" + String(digitsOnly.dropFirst(1))
            appendCandidate(domestic)
            appendCandidate("+82" + String(digitsOnly.dropFirst(1)))
        } else if digitsOnly.hasPrefix("10"), digitsOnly.count == 10 {
            appendCandidate("0" + digitsOnly)
            appendCandidate("+82" + digitsOnly)
        } else if digitsOnly.hasPrefix("0"), digitsOnly.count >= 9 {
            appendCandidate("+82" + String(digitsOnly.dropFirst(1)))
        }

        return candidates
    }

    private func renderedMessagesBody(targetName: String, completedAt: Date) -> String {
        let rendered = messagesTemplate
            .replacingOccurrences(of: "{target}", with: targetName)
            .replacingOccurrences(of: "{time}", with: formatter.string(from: completedAt))
            .replacingOccurrences(of: "{app}", with: "Render Notification")

        return rendered.isEmpty ? "Render Notification: \(targetName) 렌더 완료 (\(formatter.string(from: completedAt)))" : rendered
    }

    private func messagesErrorText(from error: Error) -> String {
        if let messagesError = error as? MessagesAutomationError {
            return messagesError.userMessage
        }

        return "Messages 전송에 실패했습니다. Messages 앱 로그인 상태와 자동화 권한을 확인하세요."
    }

    private func bundledSoundURL(named name: String, extension fileExtension: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: fileExtension)
            ?? Bundle.main.url(forResource: name, withExtension: fileExtension, subdirectory: "Sound")
    }

    private func playBundledSound(from url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            audioPlayer = player
            let token = UUID()
            activeAudioToken = token

            if player.duration > 15 {
                scheduleFadeOut(for: token, startAfter: 15)
            }
        } catch {
            NSSound.beep()
        }
    }

    private func scheduleFadeOut(for token: UUID, startAfter delay: TimeInterval) {
        fadeOutTimer?.invalidate()
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fadeOutCurrentAudio(ifTokenMatches: token, duration: 2)
            }
        }
    }

    private func fadeOutCurrentAudio(ifTokenMatches token: UUID, duration: TimeInterval) {
        guard activeAudioToken == token, let player = audioPlayer else { return }
        let startingVolume = player.volume
        player.setVolume(0, fadeDuration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak player] in
            player?.stop()
            player?.volume = startingVolume
        }
    }

    private func stopManagedAudio() {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        activeAudioToken = UUID()
        audioPlayer?.stop()
        audioPlayer = nil
    }

    private func normalizedSystemSoundIdentifier(_ value: String?, fallback: String) -> String {
        guard let value, !value.isEmpty else {
            return "system:\(fallback)"
        }
        if value.hasPrefix("system:") || value.hasPrefix("file:") {
            return value
        }
        return "system:\(value)"
    }

    private func normalizedCompletionSoundIdentifier(_ value: String?) -> String {
        guard let value, !value.isEmpty else {
            return "bundle:RenderDone"
        }
        if value == "RenderDone" || value == "bundle:RenderDone" {
            return "bundle:RenderDone"
        }
        if value.hasPrefix("system:") || value.hasPrefix("bundle:") || value.hasPrefix("file:") {
            return value
        }
        return "system:\(value)"
    }

    private func selectLocalSoundFile() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "사운드 파일 선택"
        panel.message = "MP3, WAV, M4A 같은 로컬 사운드 파일을 선택하세요."
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.audio]

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func appendLog(title: String, detail: String, kind: ActivityLogEntry.Kind) {
        activityLogs.insert(
            ActivityLogEntry(title: title, detail: detail, timestamp: Date(), kind: kind),
            at: 0
        )
        if activityLogs.count > 50 {
            activityLogs = Array(activityLogs.prefix(50))
        }
    }

    private func rememberTargetApplication(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var updated = recentTargetApplications.filter {
            $0.localizedCaseInsensitiveCompare(trimmed) != .orderedSame
        }
        updated.insert(trimmed, at: 0)
        recentTargetApplications = Array(updated.prefix(5))
        defaults.set(recentTargetApplications, forKey: Keys.recentTargetApplications)
    }

    private func isAdobeRelated(_ name: String) -> Bool {
        let lowercased = name.lowercased()
        return lowercased.contains("adobe")
            || lowercased.contains("premiere")
            || lowercased.contains("encoder")
            || lowercased.contains("after effects")
    }

    private func persistPath(_ url: URL) {
        defaults.set(url.path, forKey: pathDefaultsKey(for: targetKind))
    }

    private func pathDefaultsKey(for targetKind: MonitorTargetKind) -> String {
        switch targetKind {
        case .file:
            return Keys.selectedFilePath
        case .folder:
            return Keys.selectedFolderPath
        }
    }

    private func loadIconSelections() {
        var selections: [PortalIconRole: String] = [:]
        for role in PortalIconRole.allCases {
            let key = Keys.iconSelectionPrefix + role.rawValue
            selections[role] = defaults.string(forKey: key) ?? encodedSelection(.system(role.defaultSymbol))
        }
        iconSelections = selections
    }

    private func appendCustomIcons(from urls: [URL]) {
        let existingPaths = Set(customIconAssets.map(\.path))
        let newAssets = urls
            .filter { !existingPaths.contains($0.path) }
            .map { url in
                CustomIconAsset(
                    id: UUID(),
                    name: url.deletingPathExtension().lastPathComponent,
                    path: url.path
                )
            }

        guard !newAssets.isEmpty else {
            iconManagementMessage = "새로 추가된 아이콘이 없습니다."
            return
        }

        customIconAssets.append(contentsOf: newAssets)
        customIconAssets.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        persistCustomIconAssets()
        iconManagementMessage = "\(newAssets.count)개의 커스텀 아이콘을 추가했습니다."
    }

    private func loadCustomIconAssets() {
        guard let data = defaults.data(forKey: Keys.customIconAssets),
              let decoded = try? JSONDecoder().decode([CustomIconAsset].self, from: data) else {
            customIconAssets = []
            return
        }
        customIconAssets = decoded
    }

    private func persistCustomIconAssets() {
        guard let data = try? JSONEncoder().encode(customIconAssets) else { return }
        defaults.set(data, forKey: Keys.customIconAssets)
    }

    private func encodedSelection(_ selection: IconSelection) -> String {
        switch selection {
        case .system(let symbol):
            return "system:\(symbol)"
        case .custom(let id):
            return "custom:\(id.uuidString)"
        case .lucide(let lucideID):
            return "lucide:\(lucideID)"
        }
    }

    func makeCloudSettings() -> PortalCloudPortalSettings {
        PortalCloudPortalSettings(
            watchMode: watchMode.rawValue,
            detectionMode: detectionMode.rawValue,
            targetKind: targetKind.rawValue,
            targetApplicationName: targetApplicationName,
            notificationEnabled: notificationEnabled,
            soundEnabled: soundEnabled,
            preliminarySoundName: cloudSafeSoundIdentifier(preliminarySoundName, fallback: "system:Pop"),
            completionSoundName: cloudSafeSoundIdentifier(completionSoundName, fallback: "bundle:RenderDone"),
            messagesEnabled: messagesEnabled,
            messagesRecipient: messagesRecipient,
            messagesServiceMode: messagesServiceMode.rawValue,
            messagesTemplate: messagesTemplate,
            discordEnabled: discordEnabled,
            webhookURLString: webhookURLString,
            iconSelections: Dictionary(uniqueKeysWithValues: iconSelections.map { ($0.key.rawValue, $0.value) }),
            recentTargetApplications: recentTargetApplications
        )
    }

    func applyCloudSettings(_ settings: PortalCloudPortalSettings) {
        watchMode = WatchMode(rawValue: settings.watchMode) ?? .premiere
        detectionMode = DetectionMode(rawValue: settings.detectionMode) ?? .simple
        targetKind = MonitorTargetKind(rawValue: settings.targetKind) ?? .folder
        targetApplicationName = settings.targetApplicationName.isEmpty
            ? watchMode.defaultApplicationName
            : settings.targetApplicationName
        notificationEnabled = settings.notificationEnabled
        soundEnabled = settings.soundEnabled
        preliminarySoundName = normalizedSystemSoundIdentifier(settings.preliminarySoundName, fallback: "Pop")
        completionSoundName = normalizedCompletionSoundIdentifier(settings.completionSoundName)
        messagesEnabled = settings.messagesEnabled
        messagesRecipient = settings.messagesRecipient
        messagesServiceMode = MessagesServiceMode(rawValue: settings.messagesServiceMode) ?? .automatic
        messagesTemplate = settings.messagesTemplate
        discordEnabled = settings.discordEnabled
        webhookURLString = settings.webhookURLString
        recentTargetApplications = settings.recentTargetApplications
        defaults.set(recentTargetApplications, forKey: Keys.recentTargetApplications)

        var updatedSelections: [PortalIconRole: String] = [:]
        for role in PortalIconRole.allCases {
            let selection = settings.iconSelections[role.rawValue] ?? encodedSelection(.system(role.defaultSymbol))
            updatedSelections[role] = selection
            defaults.set(selection, forKey: Keys.iconSelectionPrefix + role.rawValue)
        }
        iconSelections = updatedSelections
    }

    private func cloudSafeSoundIdentifier(_ value: String, fallback: String) -> String {
        value.hasPrefix(SoundOption.localFilePrefix) ? fallback : value
    }
}

private enum MessagesAutomationError: LocalizedError {
    case missingRecipient
    case scriptFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingRecipient:
            return "받는 사람이 지정되지 않았습니다."
        case .scriptFailed(let reason):
            return reason
        }
    }

    var userMessage: String {
        switch self {
        case .missingRecipient:
            return "Messages 전송을 하려면 받는 사람을 먼저 입력하세요."
        case .scriptFailed(let reason):
            if reason.contains("Not authorized") || reason.contains("권한") {
                return "Messages 자동화 권한이 필요합니다. 시스템 설정에서 StudioLeaf Portal의 자동화를 허용하세요."
            }
            if reason.contains("사용 가능한 Messages 서비스가 없습니다.") {
                return "이 Mac의 Messages 앱 로그인 상태를 확인하세요."
            }
            return "Messages 전송에 실패했습니다. Messages 앱 로그인 상태와 자동화 권한을 확인하세요."
        }
    }
}
