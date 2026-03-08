import Combine
import Foundation

@MainActor
final class NotionHubViewModel: ObservableObject {
    @Published var viewMode: NotionProjectViewMode = .statusBoard
    @Published var searchText = ""
    @Published private(set) var projects: [NotionProjectSummary] = []
    @Published private(set) var selectedProjectID: String?
    @Published private(set) var selectedProjectDetail: NotionProjectDetail?
    @Published private(set) var isLoadingProjects = false
    @Published private(set) var isLoadingDetail = false
    @Published var splitOrientation: SplitOrientation = .horizontal
    @Published var splitRatio: CGFloat = 0.35 // Initial 35% list, 65% detail
    @Published private(set) var errorMessage: String?

    enum SplitOrientation: String, CaseIterable {
        case horizontal = "좌우 분할"
        case vertical = "상하 분할"
    }

    private let service: NotionHubService
    private var currentMemberName: String?

    init(
        service: NotionHubService,
        currentMemberName: String? = nil
    ) {
        self.service = service
        self.currentMemberName = currentMemberName
    }

    func updateCurrentMember(name: String?) {
        currentMemberName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredProjects: [NotionProjectSummary] {
        projects.filter { project in
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return true }

            let haystack = [
                project.title,
                project.status,
                project.summary,
                project.currentSituation
            ] + project.clientTags + project.owners.map(\.name) + project.participants.map(\.name)

            return haystack.joined(separator: " ").localizedCaseInsensitiveContains(query)
        }
    }

    var groupedProjects: [NotionProjectGroup] {
        switch viewMode {
        case .statusBoard:
            return grouped(
                titleForProject: { $0.status },
                subtitleForProjects: { "\($0.count)개 프로젝트" },
                titleSort: compareStatusGroups
            )
        case .ownerBoard:
            return grouped(
                titleForProject: { $0.owners.first?.name ?? "오너 미지정" },
                subtitleForProjects: { "\($0.count)개 프로젝트" }
            )
        }
    }

    var selectedProjectSummary: NotionProjectSummary? {
        projects.first { $0.id == selectedProjectID }
    }

    var detailService: any NotionHubService {
        service
    }

    func loadProjects(forceRefresh: Bool = false) async {
        guard !isLoadingProjects else { return }

        isLoadingProjects = true
        errorMessage = nil
        defer { isLoadingProjects = false }

        do {
            let loadedProjects = try await service.fetchProjects(forceRefresh: forceRefresh)
            projects = loadedProjects
            selectedProjectDetail = nil
            let previousSelection = selectedProjectID

            if loadedProjects.isEmpty {
                selectedProjectID = nil
                return
            }

            if let previousSelection,
               loadedProjects.contains(where: { $0.id == previousSelection }) {
                selectedProjectID = previousSelection
            } else {
                selectedProjectID = nil
            }

            if let selectedProjectID {
                await loadProjectDetail(projectID: selectedProjectID, forceRefresh: forceRefresh)
            }
        } catch {
            selectedProjectDetail = nil
            errorMessage = error.localizedDescription
        }
    }

    func selectProject(_ project: NotionProjectSummary) async {
        guard selectedProjectID != project.id else { return }
        selectedProjectID = project.id
        await loadProjectDetail(projectID: project.id, forceRefresh: false)
    }

    func clearSelection() {
        selectedProjectID = nil
        selectedProjectDetail = nil
    }

    func reload() async {
        await loadProjects(forceRefresh: true)
    }

    private func loadProjectDetail(projectID: String, forceRefresh: Bool) async {
        guard !isLoadingDetail else { return }

        isLoadingDetail = true
        errorMessage = nil
        defer { isLoadingDetail = false }

        do {
            selectedProjectDetail = try await service.fetchProjectDetail(
                projectID: projectID,
                forceRefresh: forceRefresh
            )
        } catch {
            selectedProjectDetail = nil
            errorMessage = error.localizedDescription
        }
    }
    private func grouped(
        titleForProject: (NotionProjectSummary) -> String,
        subtitleForProjects: ([NotionProjectSummary]) -> String,
        titleSort: ((String, String) -> Bool)? = nil
    ) -> [NotionProjectGroup] {
        let groups = Dictionary(grouping: filteredProjects, by: titleForProject)
        let sortedTitles: [String]

        if let titleSort {
            sortedTitles = groups.keys.sorted(by: titleSort)
        } else {
            sortedTitles = groups.keys.sorted()
        }

        return sortedTitles.map { title in
            let projects = groups[title, default: []].sorted {
                ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
            }
            return NotionProjectGroup(
                title: title,
                subtitle: subtitleForProjects(projects),
                projects: projects
            )
        }
    }

    private func compareStatusGroups(_ lhs: String, _ rhs: String) -> Bool {
        let lhsPriority = statusPriority(for: lhs)
        let rhsPriority = statusPriority(for: rhs)

        if lhsPriority != rhsPriority {
            return lhsPriority < rhsPriority
        }

        return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }

    private func statusPriority(for status: String) -> Int {
        switch status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "base":
            return 0
        case "waiting":
            return 1
        case "in progress", "inprogress":
            return 2
        case "editing":
            return 3
        case "delayed":
            return 4
        default:
            return 100
        }
    }
}
