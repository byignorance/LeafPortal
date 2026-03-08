# Notion Hub Feature Plan

## Goal

- Add a new feature named `노션 보기` alongside existing portal tools such as `Render Notification` and `WakeUp Leaf`.
- Show the `Project` database as the top-level list.
- Support app-defined project view modes that mirror the current Notion usage pattern:
  - 진행상태별 보기
  - 프로젝트 오너별
  - 내가 참여중인 프로젝트
  - 통합정보 보기
- When entering a project, show linked content from:
  - `To-do`
  - `Document`
  - `Memo`

## Existing App Structure

### Portal shell

- `Portal/PortalRootView.swift`
  - Owns the sidebar, hero header, main section router, footer.
  - New portal feature sections are wired here through `PortalSection`.
- `Portal/PortalCoreModels.swift`
  - Holds `PortalSection` and shared portal-level enums/models.
- `Portal/PortalOverviewToolsSection.swift`
  - Shows compact launcher cards on the overview screen.

### Existing feature pattern

- `Render Notification`
  - State is heavily embedded in `PortalViewModel.swift`.
  - This is not a good pattern to extend for a new data-heavy feature.
- `WakeUp Leaf`
  - Uses feature-local files such as:
    - `Features/SleepGuard/SleepGuardManager.swift`
    - `Features/SleepGuard/SleepGuardSectionView.swift`
  - This is the better pattern for `노션 보기`.

### Shared layers

- `Shared/Auth/PortalAuthManager.swift`
  - Google sign-in state.
- `Shared/Cloud/PortalCloudSyncCoordinator.swift`
  - Syncs app settings to Firestore.
  - Current scope is portal settings plus sleep guard settings.
  - Notion browsing should not be forced into this layer in v1.

## Important Notion API Constraint

- Notion API does not expose saved database view definitions for app reuse.
- The app cannot read and clone the exact Notion view modes directly.
- Therefore, `노션 보기` should implement app-defined view modes that mimic the team workflow using filters/sorts on the `Project` data source.

## Recommended Feature Structure

- `Features/NotionHub/NotionHubModels.swift`
  - Domain models for projects and linked items.
- `Features/NotionHub/NotionHubViewModel.swift`
  - Screen state, loading state, selected project, current view mode.
- `Features/NotionHub/NotionHubSectionView.swift`
  - Main container for project list and project detail.
- `Features/NotionHub/NotionProjectListView.swift`
  - Project list with view mode picker, search, refresh, and cards.
- `Features/NotionHub/NotionProjectDetailView.swift`
  - Selected project detail with `To-do`, `Document`, `Memo`.
- `Features/NotionHub/NotionHubService.swift`
  - Data loading boundary for Notion-backed content.
- `Features/NotionHub/NotionHubMocks.swift`
  - Local preview/test data for UI-first development.

## Proposed Data Model

- `NotionProjectSummary`
  - `id`
  - `title`
  - `status`
  - `owners`
  - `participants`
  - `dueDate`
  - `clientTags`
  - `summary`
  - `currentSituation`
- `NotionProjectDetail`
  - `project`
  - `todos`
  - `documents`
  - `memos`
- `NotionTaskItem`
  - `id`
  - `title`
  - `status`
  - `assignees`
  - `dueDate`
  - `startDate`
  - `dDayText`
- `NotionDocumentItem`
  - `id`
  - `title`
  - `status`
  - `author`
  - `category`
  - `date`
  - `priority`
  - `summary`
- `NotionMemoItem`
  - `id`
  - `title`
  - `status`
  - `date`
  - `category`
  - `priority`
  - `summary`
  - `isExternallyShared`

## Mapping to Current Notion Schema

### Project

- title: `Name`
- status: `Status`
- owners: `Project Owner`
- participants: `담당자`, `진행 담당자`
- dueDate: `마감기한`
- summary: `요약`
- currentSituation: `현재 상황`
- clientTags: `클라이언트`

### To-do

- title: `Name`
- project relation: `🎯 Project`
- document relation: `📝 Document`
- memo relation: `🗒️ Memo`
- assignees: `Assigned To`
- dueDate: `Due date`
- startDate: `Start Date`
- status: `Status`
- derived urgency: `D-day`

### Document

- title: `Name`
- project relation: `🎯 Project`
- todo relation: `✅ To-do`
- author: `작성자`
- date: `날짜`
- dueDate: `Due date`
- category: `분류(내용)`
- priority: `priority`
- summary: `요약`
- status: `Status`

### Memo

- title: `이름`
- project relation: `🎯 Project`
- todo relation: `✅ To-do`
- date: `날짜`
- dueDate: `Due date`
- category: `분류(내용)`
- priority: `priority`
- summary: `요약`
- externallyShared: `외부공유여부`
- status: `Status`

## UI Structure

### Sidebar

- Add `노션 보기` as a new `PortalSection`.
- Keep it in the `도구` group beside existing features.

### Overview card

- Add a compact launcher card in `PortalOverviewToolsSection.swift`.
- The card should open `노션 보기` and show:
  - selected project view mode
  - project count
  - refresh action

### Main feature screen

- Left area or top area:
  - view mode picker
  - search field
  - refresh button
- Main list:
  - project cards
  - either grouped board-like sections or dense list depending on selected mode
- Detail mode:
  - opening a project swaps to a detail layout
  - summary header
  - three linked sections:
    - `To-do`
    - `Document`
    - `Memo`

## App-defined View Modes

- `statusBoard`
  - mimic `진행상태별 보기`
  - group by `Status`
- `ownerBoard`
  - mimic `프로젝트 오너별`
  - group by `Project Owner`
- `mine`
  - mimic `내가 참여중인 프로젝트`
  - filter by signed-in user email/name mapped to owner or participant fields
- `overviewList`
  - mimic `통합정보 보기`
  - flat sortable list with richer summary rows

## Integration Points To Change

- `Portal/PortalCoreModels.swift`
  - add `.notionHub` to `PortalSection`
- `Portal/PortalRootView.swift`
  - add sidebar item
  - add section switch case
  - add hero title/subtitle/icon mapping
  - keep footer action disabled for this section
- `Portal/PortalOverviewToolsSection.swift`
  - add a compact launcher card
- `StudioLeafPortalApp.swift`
  - create and inject a dedicated `NotionHubViewModel`

## Service Boundary

### v1 UI-first

- Build UI against mock data first.
- Keep API behind a protocol so the app can run without live Notion access during layout work.

### Production path

- Do not ship the internal Notion secret inside the macOS client.
- Preferred long-term architecture:
  - app -> small backend proxy -> Notion API
- Since this repo has no backend yet, app code should be written to swap between:
  - mock service
  - direct development service
  - backend proxy service

## Recommended Implementation Order

1. Add `PortalSection.notionHub` and sidebar wiring.
2. Add feature folder and mock-backed models/view model.
3. Build `NotionHubSectionView` with project list and detail split.
4. Add app-defined project view modes.
5. Map current Notion schema into service models.
6. Replace mock service with live service or backend proxy.

## Scope For v1

- Read-only project browsing.
- Read-only linked `To-do`, `Document`, `Memo`.
- Manual refresh.
- Search and view-mode switching.
- No Notion write-back.
- No exact cloning of Notion saved database views.
