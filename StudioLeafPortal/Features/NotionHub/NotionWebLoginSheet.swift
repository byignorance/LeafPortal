import SwiftUI

struct NotionWebLoginSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject private var webSessionManager = NotionWebSessionManager.shared
    @State private var loadFailed = false

    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)
    private let loginURL = URL(string: "https://www.notion.so/login")!

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(webSessionManager.hasSession ? Color.green.opacity(0.16) : Color.orange.opacity(0.16))
                        .frame(width: 10, height: 10)

                    Text(webSessionManager.hasSession ? "노션 웹 세션이 유지되고 있습니다." : "노션 웹 세션 로그인이 필요합니다.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.72))
                }

                Text("시스템 설정상 Google 버튼 로그인은 앱 내부 웹뷰에서 정상 진행되지 않을 수 있습니다. 이메일 입력 후 직접 로그인하거나 패스키 방식으로 진행해 주세요.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.black.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)

                NotionPageWebView(url: loginURL, loadFailed: $loadFailed)
                    .frame(minHeight: 620)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )

                if loadFailed {
                    Text("로그인 페이지를 불러오지 못했습니다. 네트워크 상태를 확인한 뒤 다시 시도해 주세요.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.19))
                }
            }
            .padding(24)
        }
        .frame(minWidth: 920, idealWidth: 1040, minHeight: 760, idealHeight: 860)
        .background(Color.white)
        .task {
            await webSessionManager.refreshSessionStatus()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Notion 웹뷰 로그인")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.82))
                Text("앱 내부 노션 페이지용 세션")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.42))
            }

            Spacer()

            Button {
                Task {
                    loadFailed = false
                    await webSessionManager.refreshSessionStatus()
                }
            } label: {
                Label("상태 확인", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(themeColor)

            Button {
                Task {
                    await webSessionManager.clearSession()
                    loadFailed = false
                }
            } label: {
                Label("세션 해제", systemImage: "trash")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.74, green: 0.22, blue: 0.18))

            Button {
                dismiss()
            } label: {
                Label("닫기", systemImage: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.black.opacity(0.65))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}
