import Foundation

enum WatchMode: String, CaseIterable, Identifiable {
    case premiere = "Premiere Pro"
    case mediaEncoder = "Media Encoder"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .premiere:
            return "Premiere Pro 계열 이름을 기본값으로 제안합니다."
        case .mediaEncoder:
            return "Media Encoder 계열 이름을 기본값으로 제안합니다."
        }
    }

    var defaultApplicationName: String {
        rawValue
    }
}

enum DetectionMode: String, CaseIterable, Identifiable {
    case simple = "Simple"
    case advanced = "Advanced"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .simple:
            return "파일과 폴더 변화만 기준으로 완료를 판단합니다."
        case .advanced:
            return "파일 변화와 대상 프로그램 활동을 함께 보고 완료를 판단합니다."
        }
    }
}

enum MonitorTargetKind: String, CaseIterable, Identifiable {
    case file = "특정 파일"
    case folder = "폴더 전체"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .file:
            return "선택한 파일 하나만 추적합니다."
        case .folder:
            return "선택한 폴더 안의 파일 전체를 추적합니다."
        }
    }
}

enum MonitorState: Equatable {
    case idle
    case monitoring
    case success
    case warning
    case error

    var title: String {
        switch self {
        case .idle: return "대기"
        case .monitoring: return "감시 중"
        case .success: return "완료"
        case .warning: return "주의"
        case .error: return "오류"
        }
    }
}

struct ProcessSignal {
    let targetAppName: String
    let isRunning: Bool
    let cpuUsage: Double

    var summary: String {
        guard !targetAppName.isEmpty else {
            return "대상 프로그램 미지정"
        }
        if isRunning {
            return "\(targetAppName) 실행 중 · CPU \(String(format: "%.1f%%", cpuUsage))"
        }
        return "\(targetAppName) 미실행"
    }
}

struct MonitorProgress {
    let mode: WatchMode
    let detectionMode: DetectionMode
    let targetKind: MonitorTargetKind
    let targetURL: URL?
    let targetName: String
    let isOutputDetected: Bool
    let latestOutputName: String?
    let observedFileCount: Int
    let lastActivityDate: Date?
    let idleDuration: TimeInterval
    let idleThreshold: TimeInterval
    let preliminaryAlertSent: Bool
    let processSignal: ProcessSignal
    let headline: String
    let detail: String

    var progressValue: Double {
        guard idleThreshold > 0 else { return 0 }
        return min(max(idleDuration / idleThreshold, 0), 1)
    }
}

struct MonitorCompletion {
    let targetName: String
    let latestOutputName: String?
    let completedAt: Date
}

struct MonitorPreliminaryAlert {
    let targetName: String
    let latestOutputName: String?
    let alertedAt: Date
}
