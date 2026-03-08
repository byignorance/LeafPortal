import AppKit
import Darwin
import Foundation

final class RenderNotificationMonitorEngine {
    struct Configuration {
        let mode: WatchMode
        let detectionMode: DetectionMode
        let targetApplicationName: String
        let targetKind: MonitorTargetKind
        let targetURL: URL?
        let preliminaryThreshold: TimeInterval
        let completionThreshold: TimeInterval
    }

    private struct Snapshot {
        let signature: String
        let outputDetected: Bool
        let observedFileCount: Int
        let latestOutputName: String?
        let detail: String
    }

    private struct State {
        let configuration: Configuration
        var lastSignature: String?
        var lastActivityDate: Date?
        var hasObservedChange = false
        var latestOutputName: String?
        var preliminaryAlertSent = false
    }

    private struct ProcessSample {
        let totalCPUTime: UInt64
        let timestamp: Date
    }

    private let queue = DispatchQueue(label: "StudioLeafPortal.RenderMonitor")
    private let activeCPUThreshold = 2.0
    private let quietCPUThreshold = 1.0
    private var timer: DispatchSourceTimer?
    private var state: State?
    private var processSamples: [pid_t: ProcessSample] = [:]

    var onProgress: ((MonitorProgress) -> Void)?
    var onPreliminaryAlert: ((MonitorPreliminaryAlert) -> Void)?
    var onComplete: ((MonitorCompletion) -> Void)?
    var onFailure: ((String) -> Void)?

    func start(configuration: Configuration) {
        stop()

        let baseline = snapshot(for: configuration)
        var state = State(configuration: configuration)
        state.lastSignature = baseline.signature
        state.latestOutputName = baseline.latestOutputName
        self.state = state

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        state = nil
        processSamples.removeAll()
    }

    private func poll() {
        guard var state else {
            return
        }

        let now = Date()
        let snapshot = snapshot(for: state.configuration)
        let processSignal = detectProcesses(targetApplicationName: state.configuration.targetApplicationName)
        let isAdvanced = state.configuration.detectionMode == .advanced
        let isProcessDrivenSession = isAdvanced && state.configuration.targetURL == nil
        let processActive = processSignal.isRunning && processSignal.cpuUsage >= activeCPUThreshold

        if snapshot.signature != state.lastSignature {
            state.lastSignature = snapshot.signature
            state.lastActivityDate = snapshot.outputDetected ? now : state.lastActivityDate
            state.hasObservedChange = state.hasObservedChange || snapshot.outputDetected
            state.latestOutputName = snapshot.latestOutputName ?? state.latestOutputName
            if snapshot.outputDetected {
                state.preliminaryAlertSent = false
            }
            self.state = state
        } else {
            self.state = state
        }

        if isAdvanced, processActive {
            state.hasObservedChange = true
            state.lastActivityDate = now
            state.latestOutputName = state.configuration.targetApplicationName
            state.preliminaryAlertSent = false
            self.state = state
        }

        let idleDuration: TimeInterval
        if let lastActivityDate = state.lastActivityDate {
            idleDuration = now.timeIntervalSince(lastActivityDate)
        } else {
            idleDuration = 0
        }

        let headline: String
        let detail: String
        let shouldGateByProcess = isAdvanced

        if state.hasObservedChange {
            if state.preliminaryAlertSent {
                headline = "1차 알림 전송됨"
                detail = "\(Int(idleDuration))초 동안 변화 없음. \(Int(state.configuration.completionThreshold))초까지 추가 변화가 없으면 확정합니다."
            } else if shouldGateByProcess, processActive {
                headline = "대상 프로그램 활동 지속 감지"
                detail = isProcessDrivenSession
                    ? "\(processSignal.summary) · 렌더링 수준의 CPU 사용이 유지되고 있습니다."
                    : "\(snapshot.detail) · \(processSignal.summary)"
            } else {
                headline = "출력 파일 변화 감지됨"
                if isProcessDrivenSession {
                    detail = "\(processSignal.summary) · 프로그램 활동이 감지되어 렌더 세션으로 보고 있습니다."
                } else {
                    detail = shouldGateByProcess ? "\(snapshot.detail) · \(processSignal.summary)" : snapshot.detail
                }
            }
        } else {
            if shouldGateByProcess, processSignal.isRunning {
                headline = "대상 프로그램 활동 추적 중"
                detail = isProcessDrivenSession
                    ? "\(processSignal.summary) · 경로 없이 프로그램 활동만으로 렌더를 추적합니다."
                    : "\(processSignal.summary) · 아직 출력 파일 변화는 감지되지 않았습니다."
            } else {
                headline = "렌더 출력 대기 중"
                if isProcessDrivenSession {
                    detail = "대상 프로그램의 CPU 활동이 시작되기를 기다리는 중입니다."
                } else {
                    detail = state.configuration.targetKind == .file
                        ? "감시할 파일이 생성되거나 갱신되기를 기다리는 중입니다."
                        : "선택한 폴더 안에 파일이 생성되거나 갱신되기를 기다리는 중입니다."
                }
            }
        }

        let progress = MonitorProgress(
            mode: state.configuration.mode,
            detectionMode: state.configuration.detectionMode,
            targetKind: state.configuration.targetKind,
            targetURL: state.configuration.targetURL,
            targetName: state.configuration.targetURL?.lastPathComponent ?? state.configuration.targetApplicationName,
            isOutputDetected: state.hasObservedChange,
            latestOutputName: state.latestOutputName,
            observedFileCount: snapshot.observedFileCount,
            lastActivityDate: state.lastActivityDate,
            idleDuration: idleDuration,
            idleThreshold: state.configuration.completionThreshold,
            preliminaryAlertSent: state.preliminaryAlertSent,
            processSignal: processSignal,
            headline: headline,
            detail: detail
        )

        DispatchQueue.main.async {
            self.onProgress?(progress)
        }

        if state.hasObservedChange,
           !isAdvanced,
           !state.preliminaryAlertSent,
           idleDuration >= state.configuration.preliminaryThreshold,
           canAdvanceIdleDecision(for: state.configuration, processSignal: processSignal) {
            state.preliminaryAlertSent = true
            self.state = state

            let alert = MonitorPreliminaryAlert(
                targetName: state.configuration.targetURL?.lastPathComponent ?? state.configuration.targetApplicationName,
                latestOutputName: state.latestOutputName,
                alertedAt: now
            )

            DispatchQueue.main.async {
                self.onPreliminaryAlert?(alert)
            }
        }

        if state.hasObservedChange,
           idleDuration >= state.configuration.completionThreshold,
           canAdvanceIdleDecision(for: state.configuration, processSignal: processSignal) {
            let completion = MonitorCompletion(
                targetName: state.configuration.targetURL?.lastPathComponent ?? state.configuration.targetApplicationName,
                latestOutputName: state.latestOutputName,
                completedAt: now
            )

            stop()
            DispatchQueue.main.async {
                self.onComplete?(completion)
            }
        }
    }

    private func snapshot(for configuration: Configuration) -> Snapshot {
        guard let targetURL = configuration.targetURL else {
            return Snapshot(
                signature: "process-only",
                outputDetected: false,
                observedFileCount: 0,
                latestOutputName: nil,
                detail: "경로 없이 대상 프로그램 활동만 추적합니다."
            )
        }

        switch configuration.targetKind {
        case .file:
            return fileSnapshot(url: targetURL)
        case .folder:
            return folderSnapshot(url: targetURL)
        }
    }

    private func fileSnapshot(url: URL) -> Snapshot {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true
        else {
            return Snapshot(
                signature: "missing",
                outputDetected: false,
                observedFileCount: 0,
                latestOutputName: nil,
                detail: "\(url.lastPathComponent) 파일 생성 대기 중"
            )
        }

        let fileSize = values.fileSize ?? 0
        let modified = values.contentModificationDate ?? .distantPast
        let signature = "\(fileSize)-\(modified.timeIntervalSinceReferenceDate)"
        let sizeText = ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
        return Snapshot(
            signature: signature,
            outputDetected: true,
            observedFileCount: 1,
            latestOutputName: url.lastPathComponent,
            detail: "\(url.lastPathComponent) 갱신됨, 현재 크기 \(sizeText)"
        )
    }

    private func folderSnapshot(url: URL) -> Snapshot {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys)) else {
            return Snapshot(
                signature: "unreadable",
                outputDetected: false,
                observedFileCount: 0,
                latestOutputName: nil,
                detail: "선택한 폴더를 스캔할 수 없습니다."
            )
        }

        var totalSize: Int64 = 0
        var fileCount = 0
        var latestDate = Date.distantPast
        var latestName: String?

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else {
                continue
            }

            fileCount += 1
            totalSize += Int64(values.fileSize ?? 0)
            if let modified = values.contentModificationDate, modified > latestDate {
                latestDate = modified
                latestName = fileURL.lastPathComponent
            }
        }

        if fileCount == 0 {
            return Snapshot(
                signature: "empty",
                outputDetected: false,
                observedFileCount: 0,
                latestOutputName: nil,
                detail: "선택한 폴더에 파일이 기록되기를 기다리는 중입니다."
            )
        }

        let signature = "\(fileCount)-\(totalSize)-\(latestDate.timeIntervalSinceReferenceDate)"
        let sizeText = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        let detail = "감시 파일 \(fileCount)개, 총 용량 \(sizeText)"

        return Snapshot(
            signature: signature,
            outputDetected: true,
            observedFileCount: fileCount,
            latestOutputName: latestName,
            detail: detail
        )
    }

    private func detectProcesses(targetApplicationName: String) -> ProcessSignal {
        let trimmedName = targetApplicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return ProcessSignal(targetAppName: "", isRunning: false, cpuUsage: 0)
        }

        let matchingApps = NSWorkspace.shared.runningApplications.filter {
            ($0.localizedName ?? "").localizedCaseInsensitiveContains(trimmedName)
        }

        let pids = matchingApps.map(\.processIdentifier)
        let cpuUsage = recentCPUUsage(for: pids)
        return ProcessSignal(targetAppName: trimmedName, isRunning: !matchingApps.isEmpty, cpuUsage: cpuUsage)
    }

    private func canAdvanceIdleDecision(for configuration: Configuration, processSignal: ProcessSignal) -> Bool {
        guard configuration.detectionMode == .advanced else {
            return true
        }

        if !processSignal.isRunning {
            return true
        }

        return processSignal.cpuUsage < quietCPUThreshold
    }

    private func recentCPUUsage(for pids: [pid_t]) -> Double {
        let now = Date()
        var totalUsage = 0.0
        let activePIDs = Set(pids)
        processSamples = processSamples.filter { activePIDs.contains($0.key) }

        for pid in pids {
            guard let totalCPUTime = cumulativeCPUTime(for: pid) else { continue }

            defer {
                processSamples[pid] = ProcessSample(totalCPUTime: totalCPUTime, timestamp: now)
            }

            guard let previous = processSamples[pid] else { continue }

            let elapsedWallTime = now.timeIntervalSince(previous.timestamp)
            guard elapsedWallTime > 0 else { continue }

            let elapsedCPUTime = Double(totalCPUTime &- previous.totalCPUTime) / 1_000_000_000
            let usage = max(0, (elapsedCPUTime / elapsedWallTime) * 100)
            totalUsage += usage
        }

        return totalUsage
    }

    private func cumulativeCPUTime(for pid: pid_t) -> UInt64? {
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { reboundPointer in
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, reboundPointer)
            }
        }

        guard result == 0 else {
            return nil
        }

        return info.ri_user_time + info.ri_system_time
    }
}
