import SwiftUI

struct PortalStatusBadge: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 12, weight: .bold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
        .foregroundStyle(Color.black.opacity(0.7))
    }
}

struct PortalSyncStatusPill: View {
    let state: PortalCloudSyncCoordinator.SyncState

    var body: some View {
        let status = syncStatus

        return HStack(spacing: 6) {
            Circle()
                .fill(status.tint)
                .frame(width: 6, height: 6)
            Text(status.title)
        }
        .font(.system(size: 11, weight: .bold))
        .foregroundStyle(status.tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(status.tint.opacity(0.1))
        )
    }

    private var syncStatus: (title: String, tint: Color) {
        switch state {
        case .idle:
            return ("대기", Color.black.opacity(0.45))
        case .pendingChanges:
            return ("변경 대기", Color(red: 0.86, green: 0.56, blue: 0.12))
        case .syncing:
            return ("동기화 중", Color(red: 0.86, green: 0.56, blue: 0.12))
        case .synced:
            return ("동기화됨", Color(red: 0.14, green: 0.62, blue: 0.38))
        case .failed:
            return ("오류", Color(red: 0.78, green: 0.24, blue: 0.19))
        }
    }
}

struct PortalTagPill: View {
    let title: String
    var tint: Color = Color.black.opacity(0.72)
    var background: Color = Color(red: 0.96, green: 0.97, blue: 0.97)

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(background)
            )
    }
}
