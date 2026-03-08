import Foundation

@MainActor
enum NotionHubMocks {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func date(_ value: String) -> Date {
        formatter.date(from: value) ?? .now
    }

    private static let park = NotionPersonChip(name: "박상준", email: "byignorance@gmail.com", photoURL: "https://api.dicebear.com/7.x/notionists/svg?seed=Park")
    private static let byun = NotionPersonChip(name: "변현승", email: "hello@studioleaf.kr", photoURL: "https://api.dicebear.com/7.x/notionists/svg?seed=Byun")
    private static let yu = NotionPersonChip(name: "유하연", photoURL: "https://api.dicebear.com/7.x/notionists/svg?seed=Yu")
    private static let sung = NotionPersonChip(name: "성유진", photoURL: "https://api.dicebear.com/7.x/notionists/svg?seed=Sung")

    static let projects: [NotionProjectSummary] = [
        NotionProjectSummary(
            id: "project-toss",
            title: "토스증권 채용 콘텐츠",
            emoji: "📈",
            status: "Editing",
            owners: [byun],
            participants: [byun, park],
            dueDate: date("2026-03-18"),
            clientTags: ["토스증권"],
            summary: "브랜딩 톤을 유지하면서 채용 메시지와 영상 산출물을 정리하는 프로젝트.",
            currentSituation: "편집 마감 직전 단계이며 주요 피드백 반영이 진행 중입니다.",
            notionURL: URL(string: "https://www.notion.so/example/project-toss"),
            linkedPreview: .empty
        ),
        NotionProjectSummary(
            id: "project-hana",
            title: "하나 소셜벤처 소상공인 프로젝트",
            emoji: "🌱",
            status: "In progress",
            owners: [park],
            participants: [park, byun, yu],
            dueDate: date("2026-03-24"),
            clientTags: ["유디임팩트_하나금융그룹"],
            summary: "현장 촬영과 후반 제작이 동시에 진행되는 인터뷰 중심 프로젝트.",
            currentSituation: "촬영 일정과 러프컷 리뷰가 병행되고 있습니다.",
            notionURL: URL(string: "https://www.notion.so/example/project-hana"),
            linkedPreview: .empty
        ),
        NotionProjectSummary(
            id: "project-kakao",
            title: "카카오테크캠퍼스2025",
            emoji: "💻",
            status: "Delayed",
            owners: [park],
            participants: [park, byun, sung],
            dueDate: date("2026-04-03"),
            clientTags: ["카카오"],
            summary: "교육 프로그램 발표 자료와 행사 현장 결과물을 묶어 운영하는 장기 프로젝트.",
            currentSituation: "외부 일정 변경으로 일부 산출이 다음 주로 미뤄졌습니다.",
            notionURL: URL(string: "https://www.notion.so/example/project-kakao"),
            linkedPreview: .empty
        ),
        NotionProjectSummary(
            id: "project-portfolio",
            title: "스튜디오 리프 포트폴리오 정리",
            emoji: "📁",
            status: "Waiting",
            owners: [yu],
            participants: [yu, park],
            dueDate: date("2026-03-28"),
            clientTags: ["내부"],
            summary: "기존 포트폴리오를 정리하고 아카이브 구조를 표준화하는 내부 프로젝트.",
            currentSituation: "자료 수집이 진행 중이며 새 기준안 검토를 기다리고 있습니다.",
            notionURL: URL(string: "https://www.notion.so/example/project-portfolio"),
            linkedPreview: .empty
        )
    ]

    static let details: [String: NotionProjectDetail] = [
        "project-toss": NotionProjectDetail(
            project: projects[0],
            todos: [
                NotionTaskItem(
                    id: "task-toss-1",
                    title: "최종 인트로 컷 정리",
                    emoji: "🎬",
                    status: "Editing",
                    assignees: [byun],
                    dueDate: date("2026-03-10"),
                    startDate: date("2026-03-07"),
                    dDayText: "D-3",
                    notionURL: URL(string: "https://www.notion.so/example/task-toss-1")
                ),
                NotionTaskItem(
                    id: "task-toss-2",
                    title: "자막 오탈자 확인",
                    emoji: "🔡",
                    status: "Waiting",
                    assignees: [park],
                    dueDate: date("2026-03-11"),
                    startDate: date("2026-03-09"),
                    dDayText: "D-4",
                    notionURL: URL(string: "https://www.notion.so/example/task-toss-2")
                )
            ],
            documents: [
                NotionDocumentItem(
                    id: "doc-toss-1",
                    title: "촬영 구성안 V3",
                    emoji: "📝",
                    status: "Done",
                    author: [park],
                    categoryTags: ["기획"],
                    date: date("2026-03-03"),
                    dueDate: date("2026-03-05"),
                    priority: "high",
                    summary: "최종 스토리보드와 인터뷰 질문 구조가 반영된 문서입니다.",
                    notionURL: URL(string: "https://www.notion.so/example/doc-toss-1")
                ),
                NotionDocumentItem(
                    id: "doc-toss-2",
                    title: "편집 가이드라인",
                    emoji: "🎨",
                    status: "In progress",
                    author: [byun],
                    categoryTags: ["후반"],
                    date: date("2026-03-07"),
                    dueDate: date("2026-03-12"),
                    priority: "medium",
                    summary: "색보정과 B-roll 삽입 기준을 정리하는 중입니다.",
                    notionURL: URL(string: "https://www.notion.so/example/doc-toss-2")
                )
            ],
            memos: [
                NotionMemoItem(
                    id: "memo-toss-1",
                    title: "클라이언트 수정 요청",
                    emoji: "🚨",
                    status: "Open",
                    date: date("2026-03-07"),
                    dueDate: date("2026-03-09"),
                    categoryTags: ["피드백"],
                    priority: "high",
                    summary: "인트로 타이포 속도와 마지막 CTA 문구 수정 요청이 들어왔습니다.",
                    isExternallyShared: true,
                    notionURL: URL(string: "https://www.notion.so/example/memo-toss-1")
                )
            ]
        ),
        "project-hana": NotionProjectDetail(
            project: projects[1],
            todos: [
                NotionTaskItem(
                    id: "task-hana-1",
                    title: "전주 촬영 일정 확정",
                    emoji: "🗺️",
                    status: "In progress",
                    assignees: [park, byun],
                    dueDate: date("2026-03-14"),
                    startDate: date("2026-03-08"),
                    dDayText: "D-7",
                    notionURL: URL(string: "https://www.notion.so/example/task-hana-1")
                ),
                NotionTaskItem(
                    id: "task-hana-2",
                    title: "러프컷 내부 리뷰",
                    emoji: "👀",
                    status: "Waiting",
                    assignees: [yu],
                    dueDate: date("2026-03-15"),
                    startDate: date("2026-03-12"),
                    dDayText: "D-8",
                    notionURL: URL(string: "https://www.notion.so/example/task-hana-2")
                )
            ],
            documents: [
                NotionDocumentItem(
                    id: "doc-hana-1",
                    title: "현장 체크리스트",
                    emoji: "📋",
                    status: "Done",
                    author: [park],
                    categoryTags: ["운영"],
                    date: date("2026-03-05"),
                    dueDate: date("2026-03-06"),
                    priority: "medium",
                    summary: "현장 촬영 체크포인트와 출연자 동선이 정리되어 있습니다.",
                    notionURL: URL(string: "https://www.notion.so/example/doc-hana-1")
                )
            ],
            memos: [
                NotionMemoItem(
                    id: "memo-hana-1",
                    title: "현장 변수 메모",
                    emoji: "⚠️",
                    status: "Open",
                    date: date("2026-03-06"),
                    dueDate: nil,
                    categoryTags: ["현장"],
                    priority: "medium",
                    summary: "로케이션 이동 시간이 예상보다 길어질 수 있어 장비 반입 시간을 앞당겨야 합니다.",
                    isExternallyShared: false,
                    notionURL: URL(string: "https://www.notion.so/example/memo-hana-1")
                )
            ]
        ),
        "project-kakao": NotionProjectDetail(
            project: projects[2],
            todos: [
                NotionTaskItem(
                    id: "task-kakao-1",
                    title: "발표 영상 일정 재조정",
                    emoji: "📅",
                    status: "Delayed",
                    assignees: [park],
                    dueDate: date("2026-03-20"),
                    startDate: date("2026-03-10"),
                    dDayText: "D-13",
                    notionURL: URL(string: "https://www.notion.so/example/task-kakao-1")
                )
            ],
            documents: [],
            memos: [
                NotionMemoItem(
                    id: "memo-kakao-1",
                    title: "외부 일정 변경 반영",
                    emoji: "📢",
                    status: "Delayed",
                    date: date("2026-03-04"),
                    dueDate: nil,
                    categoryTags: ["일정"],
                    priority: "high",
                    summary: "주관사 일정 변경으로 현장 리허설과 발표 일정이 일주일 연기되었습니다.",
                    isExternallyShared: true,
                    notionURL: URL(string: "https://www.notion.so/example/memo-kakao-1")
                )
            ]
        ),
        "project-portfolio": NotionProjectDetail(
            project: projects[3],
            todos: [],
            documents: [
                NotionDocumentItem(
                    id: "doc-portfolio-1",
                    title: "포트폴리오 구조 제안서",
                    emoji: "🏗️",
                    status: "Waiting",
                    author: [yu],
                    categoryTags: ["내부"],
                    date: date("2026-03-02"),
                    dueDate: date("2026-03-19"),
                    priority: "low",
                    summary: "카테고리 재구성과 대표작 선정 기준을 정리한 초안입니다.",
                    notionURL: URL(string: "https://www.notion.so/example/doc-portfolio-1")
                )
            ],
            memos: []
        )
    ]
}
