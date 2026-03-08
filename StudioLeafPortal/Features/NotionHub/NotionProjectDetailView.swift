import SwiftUI
import WebKit

struct NotionProjectDetailView: View {
    let detail: NotionProjectDetail?
    let isLoading: Bool
    let service: any NotionHubService

    @State private var selectedLinkedItem: NotionProjectSelectedLinkedItem?

    private let themeColor = Color(red: 0.10, green: 0.18, blue: 0.14)
    private let mutedText = Color(red: 0.34, green: 0.41, blue: 0.53)
    private let surfaceColor = Color(red: 0.96, green: 0.97, blue: 0.97)

    var body: some View {
        Group {
            if isLoading {
                ProgressView("프로젝트 상세 불러오는 중")
                    .tint(themeColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let detail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header(detail.project)
                        linkedSection(
                            title: "To-do",
                            subtitle: "\(detail.todos.count)개 항목",
                            content: AnyView(taskList(detail.todos))
                        )
                        linkedSection(
                            title: "Document",
                            subtitle: "\(detail.documents.count)개 문서",
                            content: AnyView(documentList(detail.documents))
                        )
                        linkedSection(
                            title: "Memo",
                            subtitle: "\(detail.memos.count)개 메모",
                            content: AnyView(memoList(detail.memos))
                        )
                        if let notionURL = detail.project.notionURL {
                            linkedSection(
                                title: "프로젝트 원문",
                                subtitle: "브라우저에서 열기",
                                content: AnyView(projectBodyExternalLink(url: notionURL))
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                placeholder
            }
        }
        .sheet(item: $selectedLinkedItem) { item in
            NotionLinkedItemDetailSheet(item: item, service: service)
        }
    }

    private func header(_ project: NotionProjectSummary) -> some View {
        PortalCard(padding: 28) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    HStack(alignment: .top, spacing: 14) {
                        if let emoji = project.emoji {
                            Text(emoji)
                                .font(.system(size: 32))
                                .offset(y: 2)
                        } else {
                            Image(systemName: "folder")
                                .font(.system(size: 24))
                                .foregroundStyle(themeColor.opacity(0.6))
                                .frame(width: 32, height: 32)
                                .background(themeColor.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(project.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.black.opacity(0.85))

                            Text(project.currentSituation)
                                .font(.system(size: 13))
                                .foregroundStyle(mutedText)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 12) {
                        PortalTagPill(title: project.status, tint: themeColor, background: themeColor.opacity(0.08))

                        if let notionURL = project.notionURL {
                            Link(destination: notionURL) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.forward.square")
                                    Text("Notion")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(themeColor.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()
                    .overlay(Color.black.opacity(0.04))

                HStack(alignment: .top, spacing: 32) {
                    metadataColumnWithAvatars(title: "오너", members: project.owners)
                    metadataColumnWithAvatars(title: "참여", members: project.participants)
                    metadataColumn(
                        title: "마감일",
                        value: project.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "미지정"
                    )
                }
            }
        }
    }

    private func metadataColumnWithAvatars(title: String, members: [NotionPersonChip]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.4))

            if members.isEmpty {
                Text("미지정")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.7))
            } else {
                HStack(spacing: -6) {
                    ForEach(members.prefix(5)) { member in
                        NotionAvatarView(member: member, size: 24)
                    }
                    if members.count > 5 {
                        Text("+\(members.count - 5)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(mutedText)
                            .frame(width: 24, height: 24)
                            .background(surfaceColor)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metadataColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.42))
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.black.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func linkedSection(title: String, subtitle: String, content: AnyView) -> some View {
        PortalCard(padding: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.84))
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(mutedText)
                    }
                    Spacer()
                }

                content
            }
        }
    }

    private func projectBodyExternalLink(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("프로젝트 원문")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.45))
                Spacer()
                Link(destination: url) {
                    Label("노션에서 열기", systemImage: "arrow.up.forward.square")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(themeColor)
                }
                .buttonStyle(.plain)
            }

            Text("프로젝트 원문은 브라우저에서 직접 여는 방식으로 제공합니다. 앱 내부에서는 웹 세션 로그인을 다시 요구하지 않도록 임베드 웹뷰를 사용하지 않습니다.")
                .font(.system(size: 13))
                .foregroundStyle(mutedText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(rowBackground)
        }
    }

    private func taskList(_ items: [NotionTaskItem]) -> some View {
        VStack(spacing: 8) {
            if items.isEmpty {
                emptyRow("연결된 To-do가 없습니다.")
            } else {
                ForEach(items) { item in
                    Button {
                        selectedLinkedItem = .task(item)
                    } label: {
                        HStack(alignment: .center, spacing: 14) {
                            if let emoji = item.emoji {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(themeColor.opacity(0.4))
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.black.opacity(0.8))

                                HStack(spacing: 8) {
                                    infoBadge(item.status)

                                    if !item.assignees.isEmpty {
                                        HStack(spacing: -4) {
                                            ForEach(item.assignees.prefix(3)) { assignee in
                                                NotionAvatarView(member: assignee, size: 18)
                                            }
                                        }
                                    }
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(item.dDayText)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(themeColor)

                                if let dueDate = item.dueDate {
                                    Text(dueDate.formatted(.dateTime.month().day()))
                                        .font(.system(size: 10))
                                        .foregroundStyle(mutedText)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(rowBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func documentList(_ items: [NotionDocumentItem]) -> some View {
        VStack(spacing: 8) {
            if items.isEmpty {
                emptyRow("연결된 Document가 없습니다.")
            } else {
                ForEach(items) { item in
                    Button {
                        selectedLinkedItem = .document(item)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            if let emoji = item.emoji {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(themeColor.opacity(0.4))
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.8))

                                    if !item.priority.isEmpty && item.priority != "미지정" {
                                        Text(item.priority)
                                            .font(.system(size: 9, weight: .black))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(priorityColor(item.priority))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }

                                if !item.summary.isEmpty {
                                    Text(item.summary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(mutedText)
                                        .lineLimit(1)
                                }

                                HStack(spacing: 12) {
                                    if let author = item.author.first {
                                        HStack(spacing: 4) {
                                            NotionAvatarView(member: author, size: 16)
                                            Text(author.name)
                                                .font(.system(size: 11))
                                                .foregroundStyle(mutedText)
                                        }
                                    }

                                    if !item.categoryTags.isEmpty {
                                        Text(item.categoryTags.prefix(2).joined(separator: ", "))
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(themeColor.opacity(0.5))
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(rowBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func memoList(_ items: [NotionMemoItem]) -> some View {
        VStack(spacing: 8) {
            if items.isEmpty {
                emptyRow("연결된 Memo가 없습니다.")
            } else {
                ForEach(items) { item in
                    Button {
                        selectedLinkedItem = .memo(item)
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            if let emoji = item.emoji {
                                Text(emoji)
                                    .font(.system(size: 18))
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "note.text")
                                    .font(.system(size: 14))
                                    .foregroundStyle(themeColor.opacity(0.4))
                                    .frame(width: 24)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.8))
                                    Spacer()
                                    if item.isExternallyShared {
                                        HStack(spacing: 4) {
                                            Image(systemName: "globe")
                                            Text("외부공유")
                                        }
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.blue.opacity(0.8))
                                    }
                                }

                                if !item.summary.isEmpty {
                                    Text(item.summary)
                                        .font(.system(size: 12))
                                        .foregroundStyle(mutedText)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(rowBackground)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "high", "asap", "긴급":
            return .red.opacity(0.8)
        case "medium", "보통":
            return .orange.opacity(0.8)
        case "low", "낮음":
            return .blue.opacity(0.8)
        default:
            return themeColor.opacity(0.6)
        }
    }

    private func infoBadge(_ title: String) -> some View {
        PortalTagPill(title: title, tint: themeColor, background: themeColor.opacity(0.08))
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(rowBackground)
    }

    private var placeholder: some View {
        PortalCard(padding: 40) {
            VStack(spacing: 12) {
                Text("프로젝트를 선택하세요.")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.76))
                Text("선택한 프로젝트의 To-do, Document, Memo를 이 영역에 표시합니다.")
                    .font(.system(size: 13))
                    .foregroundStyle(mutedText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(surfaceColor)
    }
}
