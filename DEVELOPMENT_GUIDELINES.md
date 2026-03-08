# studioLEAF Portal Development Guidelines

## Product Framing

- `studioLEAF Portal` is a portal app with multiple internal tools.
- Shared shell behavior belongs to the portal layer.
- Tool-specific behavior belongs to each feature module.
- Do not treat the app as one monolithic utility screen.

## Canonical Naming Policy

- App display name: `studioLEAF Portal`
- Local/Xcode project identifier may remain `StudioLeafPortal` until there is an explicit rename pass.
- Shared shell code uses the `Portal*` prefix.
- Internal tool code uses the tool name directly.

Canonical tool names:

- `Overview`
- `Project Hub`
- `Team Messenger`
- `Notion Connector`
- `Render Notification`
- `WakeUp Leaf`
- `Activity`
- `Settings`
- `Icon Management`

Canonical code names:

- `Portal`
- `ProjectArchive`
- `ProjectChat`
- `NotionHub`
- `RenderNotification`
- `SleepGuard`
- `IconManagement`

Stable internal identifiers may remain unchanged if already used in persisted data, Firestore collection names, or file paths. In particular:

- `projectArchives` may continue to back `Project Hub`
- `ProjectChat` code may continue to back `Team Messenger`
- `NotionHub` code may continue to back `Notion Connector`

Avoid these mixed display variants in new work:

- `Render Noti`
- `Project Archive`
- `프로젝트 아카이브`
- `Project Chat`
- `프로젝트 채팅`
- `Notion Hub`
- `노션 보기`
- multiple display names for the same feature across enum cases, labels, and state variables

## File Naming

- 모든 새 파일은 `기능명 + 역할명` 형식으로 만든다.
- 공통 포털 레이어는 `Portal*` 접두사를 사용한다.
- 기능 전용 파일은 기능명을 앞에 둔다.
- 예시:
  - `PortalRootView.swift`
  - `PortalCoreModels.swift`
  - `RenderNotificationMonitorEngine.swift`
  - `RenderNotificationSettingsView.swift`
  - `PortalIconManagementSection.swift`

## Folder Rules

- `Portal/`: 앱 셸, 전역 모델, 전역 상태
- `Features/<FeatureName>/`: 기능 전용 UI, 엔진, 모델
- `Shared/`: 여러 기능이 함께 쓰는 UI 조각, 유틸리티

Feature folder names should follow canonical tool code names:

- `Features/RenderNotification/`
- `Features/SleepGuard/`
- `Features/NotionHub/`
- `Features/ProjectChat/`
- `Features/IconManagement/`

Do not create a new folder name if an existing canonical feature name already represents that tool.

## Design Reference Rule

- UI 수정이나 새 화면 개발 전에는 반드시 `/Users/sangjoonpark/0_local/main_work_macbook/mac_apps/StudioLeafPortal/design_guideline.md`를 먼저 확인한다.
- 구조 정책은 `DEVELOPMENT_GUIDELINES.md`, 화면 정책은 `design_guideline.md`를 기준으로 함께 적용한다.

## File Length Policy

- View 파일: 가능하면 `500`줄 이하
- ViewModel / Service / Engine 파일: 가능하면 `400`줄 이하
- 모델 전용 파일: `250`줄 이하
- 파일이 이 기준을 넘기기 시작하면 같은 턴에서 분리 후보를 먼저 검토한다.

## Build Safety Rules

- Swift에서 `Attribute 'private' can only be used in a non-local scope` 에러가 나오면 `private` 자체를 먼저 의심하지 말고, 바로 위쪽의 중괄호 짝과 함수/프로퍼티 종료 지점을 먼저 확인한다.
- `private var`, `private func`, `private struct` 선언 직전에 새 `if`, `switch`, `VStack`, `Group`, `Task`, 클로저 블록을 추가했다면 닫는 `}` 누락 여부를 우선 점검한다.
- 큰 `View` 파일에 새 섹션 블록을 삽입할 때는 기존 프로퍼티 하나의 끝을 명확히 닫은 뒤 다음 `private var`를 시작한다.
- Firestore 모델 파일에서 `QueryDocumentSnapshot`, `Timestamp`, `ListenerRegistration` 같은 타입을 쓰면 `FirebaseFirestore` import 유무를 먼저 확인한다.
- 빌드 에러가 `private`와 `Cannot find type 'QueryDocumentSnapshot'` 같이 동시에 나오면, 보통 `스코프 붕괴`와 `import 누락`을 분리해서 각각 확인한다.

## Split Rules

- 화면 섹션이 2개 이상으로 커지면 별도 `SectionView`로 분리한다.
- 기능 전용 상태와 공통 상태가 섞이면 모델과 엔진을 먼저 분리한다.
- 공통 설정 페이지에는 기능 전용 설정을 직접 넣지 않는다.
  - 기능 전용 설정은 해당 기능 페이지 내부에서 관리한다.
- 아이콘 관리 페이지는 `공통 포털`과 `기능별` 그룹으로 나눈다.

Additional split rules for this app:

- `PortalRootView` is shell-only. Tool-specific panels should live in feature views.
- `PortalViewModel` should keep cross-tool navigation and shared app state only.
- Monitoring logic, chat logic, sleep logic, and notion logic should not accumulate in the same file once they have stable module homes.
- Placeholder actions should be marked clearly in code and UI until implemented.

## Current Baseline

- `Render Notification` 관련 설정과 동작은 기능 페이지에 유지한다.
- `환경설정`은 이후 기능이 늘어나도 공통 포털 정책과 탐색 역할만 담당한다.
- 새 기능 추가 시 `Features/<FeatureName>/` 폴더를 먼저 만든 뒤 구현을 시작한다.
- UI 작업은 `design_guideline.md`를 먼저 참고한 뒤 진행한다.
- 구조 및 용어 점검 결과는 `ARCHITECTURE_REVIEW_2026-03-07.md`를 함께 참고한다.
