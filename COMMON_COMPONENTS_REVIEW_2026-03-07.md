# studioLEAF Portal 공통 컴포넌트 / 모달 구조 점검

작성일: 2026-03-07
대상 폴더: `/Users/sangjoonpark/0_local/main_work_macbook/mac_apps/StudioLeafPortal`

## 결론

현재 포털은 "공통 UI가 전혀 없는 상태"는 아니다. 다만 공통 요소가 `각 화면 파일 내부 helper`로 갇혀 있어서, 재사용 이점은 적고 파일만 커지는 구조에 가깝다.

따라서 방향은 아래가 적절하다.

1. `전역 공통 모달 시스템`부터 크게 만들지는 않는다.
2. 먼저 `공통 UI 프리미티브`와 `공통 섹션 레이아웃`을 뽑는다.
3. 그 다음 `검색/선택/편집` 성격의 반복 sheet만 제한적으로 공통화한다.
4. `프로젝트 채팅`은 현재 수정 중이므로, 화면 구조를 억지로 공통화하지 말고 주변 공통 요소만 흡수한다.

즉, 웹앱처럼 `공통 팝업, 드롭다운, 리스트 셀, 카드 래퍼`를 두는 방향은 분명 개선 효과가 있다. 다만 지금 코드베이스에서는 `하나의 공통 모달 프레임워크`보다 `작은 공통 구성요소 + 큰 파일 분리`가 우선순위가 더 높다.

## 전체 판단

### 공통화가 도움이 되는 부분

- 카드형 섹션 래퍼
- 섹션 헤더
- 상태 pill / badge
- 보조/주 버튼 스타일
- 빈 상태 / 로딩 / 인라인 경고
- 검색 선택 sheet
- 계정 / 동기화 footer 블록

### 공통화 효과가 낮거나 지금 보류할 부분

- 기능별 복잡한 편집 sheet 전체
- 채팅 전용 방/메시지/검색 상호작용
- 노션 상세의 도메인 전용 뷰
- Render / WakeUp의 입력 로직 자체

이유는 현재 각 기능의 상태 모델과 인터랙션이 아직 다르고, 특히 채팅은 변경 중이라 뷰 구조를 서둘러 추상화하면 오히려 다시 풀어야 할 가능성이 높기 때문이다.

## 확인한 파일 규모

- `PortalRootView.swift`: 1772 lines
- `PortalOverviewToolsSection.swift`: 779 lines
- `PortalProjectChatSection.swift`: 2576 lines
- `PortalProjectArchiveSection.swift`: 601 lines
- `SleepGuardSectionView.swift`: 604 lines
- `PortalIconManagementSection.swift`: 578 lines
- `NotionProjectDetailView.swift`: 1329 lines

판단:

- 즉시 분리 필요:
  - `PortalProjectChatSection.swift`
  - `PortalRootView.swift`
- 분리 권장:
  - `NotionProjectDetailView.swift`
  - `PortalOverviewToolsSection.swift`
- 상황 보며 분리:
  - `PortalProjectArchiveSection.swift`
  - `SleepGuardSectionView.swift`
  - `PortalIconManagementSection.swift`

## 현재 보이는 구조적 문제

### 1. 공통 스타일이 파일 내부 private helper로 고립됨

이미 비슷한 요소가 여러 파일에 따로 있다.

- `PortalRootView.swift`: `softCard`, `heroHeader`, `sidebarGroup`, `syncPill`
- `PortalOverviewToolsSection.swift`: `compactPrimaryButton`, `compactSecondaryButton`, `squareIconButton`
- `SleepGuardSectionView.swift`: `softCard`, `secondaryButton`, `iconButton`
- `PortalProjectArchiveSection.swift`: `sectionCard`
- `PortalIconManagementSection.swift`: `sectionCard`, `secondaryButton`

이 구조의 문제는 다음과 같다.

- 스타일 일관성을 유지하기 어렵다.
- 한 화면에서 좋아 보인 버튼을 다른 화면에서 재사용하기 어렵다.
- 작은 UI 수정도 여러 파일을 각각 손봐야 한다.
- helper가 많아질수록 본문과 helper가 뒤섞여 파일이 비대해진다.

### 2. sheet / picker / menu는 반복되지만 패턴으로 정리되지 않음

다음 화면들에서 `sheet`, `Picker`, `Menu`, `contextMenu`가 반복된다.

- `PortalRootView.swift`
- `PortalProjectChatSection.swift`
- `PortalProjectArchiveSection.swift`
- `PortalIconManagementSection.swift`
- `NotionProjectDetailView.swift`
- `SleepGuardSectionView.swift`

하지만 지금은 각 기능이 자기 방식으로 구현하고 있다. 이 상태에서는 "공통 모달"을 만들어도 전부 흡수되진 않는다. 대신 아래처럼 범위를 좁히면 효과가 있다.

- `SearchPickerSheet`
- `EntitySelectionSheet`
- `ConfirmActionDialog`
- `InlineStatusBanner`

## 공통화 추천안

### A. 먼저 만들면 바로 이득인 공통 UI

추천 위치:

- `StudioLeafPortal/Shared/UI/`

추천 구성:

- `PortalCard.swift`
  - `softCard`
  - `sectionCard`
  - 카드 패딩 / radius / border / shadow를 variant로 통일
- `PortalButtons.swift`
  - `PrimaryButton`
  - `SecondaryButton`
  - `IconButton`
  - `CompactActionButton`
- `PortalBadge.swift`
  - 상태 pill
  - 숫자 pill
  - subtle tag
- `PortalStates.swift`
  - `EmptyStateView`
  - `LoadingStateView`
  - `InlineAlert`
  - `ErrorStateView`
- `PortalSectionHeader.swift`
  - title + subtitle + trailing action

이 5개만 정리해도 현재 중복의 상당 부분이 줄어든다.

### B. 제한적으로 공통화할 모달 / sheet

추천 대상:

- 아이콘 검색 sheet
- 룸/프로젝트 선택 sheet
- 항목 상세 미리보기 sheet
- 확인/삭제 sheet

추천 형태:

- `PortalModalShell`
  - 타이틀
  - 설명
  - body slot
  - footer action slot
- `PortalSelectionSheet`
  - 검색창
  - 리스트
  - 선택 / 닫기 액션

중요:

기능별 편집 폼 전체를 공통화하지는 않는다. 공통화 대상은 `껍데기(shell)`와 `반복 UX 패턴`까지만 둔다.

### C. 리스트 계열 공통화

웹앱에서 말한 "리스트 뷰 소스 공통화"는 여기서도 유효하다.

추천 공통화 대상:

- 검색 가능한 목록 헤더
- 선택된 항목 하이라이트 row
- 빈 목록 안내
- 최근 변경 카드 row
- 메타 정보 row

단, `채팅 메시지 셀`까지 공통 row로 일반화하는 것은 비추천이다. 메시지 타입, pinned, keyword, editing, link preview, archive 연결 등 채팅 고유 상태가 많아서 손해가 더 크다.

## 기능별 판단

### 1. PortalRootView

판단: 공통화와 분리 둘 다 시급하다.

현재 역할이 너무 많다.

- 앱 shell
- sidebar
- hero header
- footer
- overview 일부 스타일
- Render / WakeUp / settings 관련 하위 UI
- auth / sync footer 표현

권장 분리:

- `PortalSidebarView`
- `PortalFooterView`
- `PortalHeroHeaderView`
- `PortalSettingsSectionView`
- `PortalRenderSectionView`
- `PortalActivitySectionView`

`PortalRootView`는 라우팅과 조립만 담당하는 편이 맞다.

### 2. PortalOverviewToolsSection

판단: 지금 구조에서는 "좋은 중간 단계"이지만 helper가 많이 붙으면 다시 커진다.

권장 분리:

- `OverviewCollaborationDashboard`
- `OverviewToolLauncher`
- `OverviewToolAccordionCard`
- `OverviewCollaborationCard`

이 파일은 대시보드 레이아웃은 유지하되 카드와 액션 버튼만 Shared UI로 올리는 정도가 적절하다.

### 3. PortalProjectChatSection

판단: 가장 큼. 반드시 분리 필요. 다만 지금은 적극 공통화보다 화면 분해가 우선.

현재 한 파일 안에 섞여 있는 것:

- 좌측 프로젝트/룸 패널
- 우측 헤더
- 검색
- focus panel
- 메시지 리스트
- composer
- room creation sheet
- room settings sheet
- archive 연결 액션
- context menu

권장 분리:

- `ChatSidebarView`
- `ChatHeaderView`
- `ChatMessageListView`
- `ChatComposerView`
- `ChatSearchBarView`
- `ChatRoomCreationSheet`
- `ChatRoomFocusPanelView`

채팅은 현재 수정 중이므로, 여기서 공통화할 것은 아래 정도만 추천한다.

- 버튼 스타일
- pill / status chip
- empty / loading / alert
- modal shell

채팅 자체 row, panel, composer까지 공통화하려 들면 개발 속도가 떨어질 가능성이 높다.

### 4. NotionProjectDetailView

판단: 분리 권장.

현재 한 파일 안에서 다음이 같이 있다.

- 프로젝트 헤더
- To-do / Document / Memo 섹션
- 웹뷰
- linked item sheet

권장 분리:

- `NotionProjectHeaderView`
- `NotionLinkedSectionView`
- `NotionProjectBodyView`
- `NotionLinkedItemDetailSheet`

노션은 카드, 메타데이터 행, 섹션 헤더를 공통 스타일로 흡수하기 좋다.

### 5. ProjectArchive / SleepGuard / IconManagement

판단: 당장 위험 수준은 아니지만 공통 프리미티브 적용 효과가 높다.

특히 다음 helper는 Shared UI로 올리기 좋다.

- `sectionCard`
- `softCard`
- `secondaryButton`
- `iconButton`

## 우선순위 제안

### 1차

- `Shared/UI` 레이어 신설
- 카드 / 버튼 / badge / 상태뷰 공통화
- `PortalRootView` 분리

효과:

- 전반적인 화면 일관성 개선
- 이후 기능 개발 시 helper 중복 감소
- `private helper` 누적으로 파일이 비대해지는 속도 감소

### 2차

- `PortalProjectChatSection` 화면 분리
- 채팅 주변 sheet shell 정리

효과:

- 가장 큰 파일 안정화
- 채팅 수정 중 충돌 범위 축소

### 3차

- `NotionProjectDetailView` 분리
- 아카이브 / 아이콘 관리 / 절전 방지에 공통 UI 적용

효과:

- 기능별 디자인 정합성 개선
- 유지보수 비용 감소

## 최종 판단

질문에 대한 직접 답:

### 공통 모달이나 요소를 두는 게 좋은가?

좋다. 다만 "전역 공통 모달 시스템"보다는 "공통 UI 프리미티브 + 반복되는 sheet shell"부터 두는 것이 맞다.

### 웹앱처럼 개별 기능은 공통 모달을 호출하는 방식이 개선에 도움이 되는가?

부분적으로 그렇다. 특히 검색/선택/확인 계열에서는 효과가 크다. 하지만 채팅처럼 기능 상태가 복잡한 화면은 공통 모달 호출 구조로 과하게 몰아넣지 않는 편이 낫다.

### 개별 소스가 비대해서 쪼개는 게 필요한가?

그렇다. 이미 분리 필요 수준이다. 특히 `PortalProjectChatSection.swift`, `PortalRootView.swift`, `NotionProjectDetailView.swift`, `PortalOverviewToolsSection.swift`는 구조 분리가 필요하다.

### 채팅 기능은 지금 수정 중인데 감안하면 어떻게 보는가?

채팅은 지금 당장 대대적 공통화보다 `파일 분해 + 주변 공통 UI만 흡수`가 맞다. 가장 변화가 잦은 중심 로직을 추상화하면 다시 되돌릴 가능성이 높다.

## 권장 실행안

1. `Shared/UI` 폴더를 만들고 카드/버튼/badge/상태뷰부터 올린다.
2. `PortalRootView`를 shell 조립 파일로 축소한다.
3. `PortalProjectChatSection`은 공통화보다 서브뷰 분리를 먼저 한다.
4. 공통 모달은 `선택`, `검색`, `확인` 3종 shell만 만든다.
5. 채팅이 안정화된 뒤에만 채팅 전용 modal / row 공통화를 다시 검토한다.
