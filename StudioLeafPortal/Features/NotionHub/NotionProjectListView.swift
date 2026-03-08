import SwiftUI

struct NotionProjectListView: View {
    @ObservedObject var viewModel: NotionHubViewModel
    let service: any NotionHubService
    let onSelectProject: (NotionProjectSummary) -> Void
    let isWebSessionConnected: Bool
    let onTapWebSession: () -> Void
    @State private var expandedPreviewKeys: Set<String> = []
    @State private var selectedLinkedItem: NotionProjectSelectedLinkedItem?

    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)
    private let mutedText = Color(red: 0.34, green: 0.41, blue: 0.53)
    private let surfaceColor = Color(red: 0.96, green: 0.97, blue: 0.97)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            if viewModel.isLoadingProjects && viewModel.projects.isEmpty {
                ProgressView("프로젝트 불러오는 중")
                    .tint(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if viewModel.groupedProjects.allSatisfy({ $0.projects.isEmpty }) {
                emptyState
            } else if boardMode {
                boardLayout
            } else {
                listLayout
            }
        }
        .sheet(item: $selectedLinkedItem, onDismiss: {
            Task { await viewModel.reload() }
        }) { item in
            NotionLinkedItemDetailSheet(item: item, service: service)
        }
    }

    private var boardMode: Bool {
        viewModel.viewMode == .statusBoard || viewModel.viewMode == .ownerBoard
    }

    private var header: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(NotionProjectViewMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            viewModel.viewMode = mode
                        }
                    } label: {
                        Text(mode.rawValue)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(viewModel.viewMode == mode ? .white : Color.black.opacity(0.45))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(viewModel.viewMode == mode ? themeColor : Color.black.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.03))
            )

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(themeColor.opacity(0.7))

                TextField("프로젝트, 담당자, 요약 검색", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))

                Spacer(minLength: 8)

                Button {
                    Task { await viewModel.reload() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                        Text("새로고침")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(themeColor)
                }
                .buttonStyle(.plain)

                Text("\(viewModel.filteredProjects.count)개")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.48))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(surfaceColor)
            )

            Button {
                onTapWebSession()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isWebSessionConnected ? "link.circle.fill" : "lock.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isWebSessionConnected ? themeColor : Color.black.opacity(0.62))

                    Text(isWebSessionConnected ? "웹뷰 연동 중" : "웹뷰 미리보기를 위해 로그인이 필요합니다")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(isWebSessionConnected ? themeColor : Color.black.opacity(0.68))
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(isWebSessionConnected ? themeColor.opacity(0.08) : Color.black.opacity(0.04))
                )
            }
            .buttonStyle(.plain)
        }
    }


    private var boardLayout: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(viewModel.groupedProjects) { group in
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 4) {
                                if viewModel.viewMode == .statusBoard {
                                    statusHeaderBadge("\(group.title)(\(group.projects.count))", statusKey: group.title)
                                } else {
                                    Text(group.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.82))
                                    Text(group.subtitle)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(mutedText)
                                }
                            }

                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(alignment: .leading, spacing: 14) {
                                    ForEach(group.projects) { project in
                                        projectCard(project)
                                    }
                                }
                                .padding(.trailing, 4)
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .padding(18)
                        .frame(width: 320, height: max(geometry.size.height - 8, 260), alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var listLayout: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(viewModel.groupedProjects) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        Text(group.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.8))

                        ForEach(group.projects) { project in
                            projectRow(project)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func projectCard(_ project: NotionProjectSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                if let emoji = project.emoji {
                    Text(emoji)
                        .font(.system(size: 24))
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColor)
                }

                Spacer()

                if let dueDate = project.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.4))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.85))
                    .lineLimit(2)

                if !project.summary.isEmpty {
                    Text(project.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(mutedText)
                        .lineLimit(2)
                }
            }

            HStack(spacing: -6) {
                ForEach(project.owners.prefix(3)) { owner in
                    NotionAvatarView(member: owner, size: 20)
                }
                if !project.participants.isEmpty {
                    ForEach(project.participants.prefix(3)) { participant in
                        if !project.owners.contains(where: { $0.id == participant.id }) {
                            NotionAvatarView(member: participant, size: 20)
                        }
                    }
                }

                Spacer()

                if !project.clientTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(project.clientTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.62))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            linkedPreviewSections(project)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .notionCardStyle(isSelected: viewModel.selectedProjectID == project.id, themeColor: themeColor)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelectProject(project)
        }
    }

    private func projectRow(_ project: NotionProjectSummary) -> some View {
        Button {
            onSelectProject(project)
        } label: {
            HStack(alignment: .center, spacing: 16) {
                if let emoji = project.emoji {
                    Text(emoji)
                        .font(.system(size: 20))
                        .frame(width: 24)
                } else {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundStyle(themeColor.opacity(0.5))
                        .frame(width: 24)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(project.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.8))
                        statusBadge(project.status)
                    }

                    if !project.currentSituation.isEmpty {
                        Text(project.currentSituation)
                            .font(.system(size: 12))
                            .foregroundStyle(mutedText)
                            .lineLimit(1)
                    }
                }

                Spacer()
                
                HStack(spacing: -4) {
                    ForEach(project.owners.prefix(2)) { owner in
                        NotionAvatarView(member: owner, size: 18)
                    }
                }

                if let dueDate = project.dueDate {
                    Text(dueDate.formatted(date: .numeric, time: .omitted))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.4))
                        .frame(width: 60, alignment: .trailing)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .notionCardStyle(isSelected: viewModel.selectedProjectID == project.id, themeColor: themeColor)
        }
        .buttonStyle(.plain)
    }

    private func personLine(title: String, people: [NotionPersonChip]) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.42))

            Text(people.map(\.name).joined(separator: ", "))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.66))
                .lineLimit(1)
        }
    }

    private func statusBadge(_ title: String) -> some View {
        let style = statusStyle(for: title)

        return Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(style.background)
            )
    }

    private func statusHeaderBadge(_ title: String, statusKey: String? = nil) -> some View {
        let style = statusStyle(for: statusKey ?? title)

        return Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(
                Capsule()
                    .fill(style.background)
            )
    }

    private func statusStyle(for title: String) -> (foreground: Color, background: Color) {
        switch title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "base":
            return (statusColor("6B6B6B"), statusColor("F0EEEB"))
        case "waiting":
            return (statusColor("9A6A00"), statusColor("F8E7B8"))
        case "in progress", "inprogress":
            return (statusColor("2166B5"), statusColor("DCEBFB"))
        case "editing":
            return (statusColor("B86219"), statusColor("F8E3D3"))
        case "delayed":
            return (statusColor("7E1F24"), statusColor("F4D8DB"))
        case "project done", "done":
            return (statusColor("29724A"), statusColor("DDEEE4"))
        default:
            return (themeColor, themeColor.opacity(0.08))
        }
    }

    private func statusColor(_ hex: String) -> Color {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&int)

        let red = Double((int >> 16) & 0xFF) / 255
        let green = Double((int >> 8) & 0xFF) / 255
        let blue = Double(int & 0xFF) / 255
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("조건에 맞는 프로젝트가 없습니다.")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.72))
            Text("검색어를 바꾸거나 다른 뷰 모드로 전환해 보세요.")
                .font(.system(size: 13))
                .foregroundStyle(mutedText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding(.vertical, 60)
    }

    @ViewBuilder
    private func linkedPreviewSections(_ project: NotionProjectSummary) -> some View {
        let preview = project.linkedPreview
        let groups: [AnyView] = [
            previewGroup(
                key: "\(project.id)-todo",
                items: preview.todos.map(NotionProjectSelectedLinkedItem.task)
            ),
            previewGroup(
                key: "\(project.id)-document",
                items: preview.documents.map(NotionProjectSelectedLinkedItem.document)
            ),
            previewGroup(
                key: "\(project.id)-memo",
                items: preview.memos.map(NotionProjectSelectedLinkedItem.memo)
            )
        ].compactMap { $0 }

        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Divider()
                    .overlay(Color.black.opacity(0.06))

                ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider()
                            .overlay(Color.black.opacity(0.05))
                    }
                    group
                }
            }
        }
    }

    private func previewGroup(
        key: String,
        items: [NotionProjectSelectedLinkedItem]
    ) -> AnyView? {
        guard !items.isEmpty else { return nil }

        let isExpanded = expandedPreviewKeys.contains(key)
        let visibleItems = isExpanded ? items : Array(items.prefix(3))
        let hiddenCount = max(items.count - 3, 0)

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                ForEach(visibleItems) { item in
                    Button {
                        selectedLinkedItem = item
                    } label: {
                        previewRow(
                            emoji: previewEmoji(for: item),
                            title: item.title
                        )
                    }
                    .buttonStyle(.plain)
                }

                if hiddenCount > 0 {
                    Button {
                        togglePreviewExpansion(for: key)
                    } label: {
                        Text(isExpanded ? "접기" : "더보기 \(hiddenCount)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(themeColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        )
    }

    private func previewRow(
        emoji: String,
        title: String
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(emoji)
                .font(.system(size: 13))
                .frame(width: 16, alignment: .center)

            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.72))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.028))
        )
    }

    private func togglePreviewExpansion(for key: String) {
        if expandedPreviewKeys.contains(key) {
            expandedPreviewKeys.remove(key)
        } else {
            expandedPreviewKeys.insert(key)
        }
    }

    private func previewEmoji(for item: NotionProjectSelectedLinkedItem) -> String {
        switch item {
        case .task(let task):
            return task.emoji ?? "✅"
        case .document(let document):
            return document.emoji ?? "📄"
        case .memo(let memo):
            return memo.emoji ?? "📝"
        }
    }
}

private struct WrapTagLayout: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.62))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
        }
    }
}
