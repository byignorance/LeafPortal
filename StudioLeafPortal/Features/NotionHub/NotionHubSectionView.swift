import SwiftUI

struct NotionHubSectionView: View {
    @ObservedObject var viewModel: NotionHubViewModel
    @ObservedObject var oauthManager: NotionOAuthManager
    @ObservedObject private var webSessionManager = NotionWebSessionManager.shared

    @State private var isShowingWebLoginSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if viewModel.selectedProjectID == nil {
                    NotionProjectListView(
                        viewModel: viewModel,
                        service: viewModel.detailService,
                        onSelectProject: { project in
                            Task { await viewModel.selectProject(project) }
                        },
                        isWebSessionConnected: webSessionManager.hasSession,
                        onTapWebSession: {
                            isShowingWebLoginSheet = true
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    navigationBar
                        .padding(.bottom, 24)

                    NotionProjectDetailView(
                        detail: viewModel.selectedProjectDetail,
                        isLoading: viewModel.isLoadingDetail,
                        service: viewModel.detailService
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .task {
            guard viewModel.projects.isEmpty else { return }
            await viewModel.loadProjects()
        }
        .overlay(alignment: .topTrailing) {
            if let errorMessage = viewModel.errorMessage {
                errorMessageOverlay(errorMessage)
            }
        }
        .sheet(isPresented: $isShowingWebLoginSheet, onDismiss: {
            Task {
                await webSessionManager.refreshSessionStatus()
            }
        }) {
            NotionWebLoginSheet()
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 16) {
            if let selectedProject = viewModel.selectedProjectSummary, viewModel.selectedProjectID != nil {
                Button {
                    viewModel.clearSelection()
                } label: {
                    Label("프로젝트 목록", systemImage: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(themeColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(themeColor.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text("선택된 프로젝트")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.4))
                    Text(selectedProject.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.82))
                        .lineLimit(1)
                }

                Spacer()
            }
        }
    }

    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)

    private func errorMessageOverlay(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 0.78, green: 0.24, blue: 0.19))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, y: 2)
            )
            .padding(.top, 6)
    }
}

struct NotionHubSectionView_Previews: PreviewProvider {
    static var previews: some View {
        NotionHubSectionView(
            viewModel: NotionHubViewModel(
                service: NotionHubMockService(),
                currentMemberName: "박상준"
            ),
            oauthManager: NotionOAuthManager()
        )
        .padding(40)
        .frame(width: 1380, height: 860)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
    }
}
