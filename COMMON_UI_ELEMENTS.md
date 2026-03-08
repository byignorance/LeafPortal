# StudioLeafPortal 공통 UI/구조 요소 정리 (2026-03-07)

이 문서는 현재 코드 기준으로 `리프포탈(LeafPortal)` 앱의 공통 요소를 정리한 기준 문서입니다.  
기준 출처: `PortalRootView.swift`, `PortalCoreModels.swift`, `PortalViewModel.swift`, `PortalOverviewToolsSection.swift`, `NotionHub*`, `ProjectChat*`, `SleepGuard*`, `PortalIconManagementSection.swift`.

## 1) 현재 세부 개발 내역 요약

- 포털 핵심 구조: `Portal` + `Features/<FeatureName>` 분리 구조 유지.
- 활성 포털 섹션: 
  - 대시보드, 프로젝트 채팅, 노션 보기, Render Noti, WakeUp Leaf, 활동 로그, 환경설정, 아이콘 관리.
- 기능 동작 레이어:
  - Render Notification: `PortalViewModel` + `RenderNotificationMonitorEngine` 중심.
  - Sleep Guard: `SleepGuardManager`.
  - Notion Hub: `NotionHubViewModel` + `NotionHubService` 계층(캐시, 실서비스/목업 분기).
  - 프로젝트 채팅: `PortalProjectChatManager`.
  - 아이콘 관리: `PortalViewModel` + `PortalIconManagementSection`.
- 구조 안정성 이슈(기존 문서와 일치): 포털 공통/기능 전용 경계는 분리되어 있으나 일부 동작은 아직 Placeholder(예: `새 감시 추가`, 하단 푸터의 기록 내보내기)로 남아 있음.

## 2) 공통 레이아웃 요소

### 2-1. 앱 셸 레이아웃 (PortalRootView)
- `HStack(spacing: 0)` 기반의 2단 구조:
  - 왼쪽: 고정 너비 사이드바 (`.frame(width: 250)`).
  - 오른쪽: 메인 패널 (`ScrollView` 또는 고정 `VStack`).
- 하단은 `safeAreaInset(edge: .bottom)`으로 푸터를 항상 고정 표시.

### 2-2. 좌측 메뉴(사이드바)
- 구성 블록:
  - 헤더(로고 + 앱명)
  - 그룹별 항목
    - 도구: 노션 보기 / Render Noti / WakeUp Leaf
    - 협업: 프로젝트 채팅
    - 설정: 활동 로그 / 환경설정 / 아이콘 관리
- 선택 상태 표시:
  - 텍스트/배경/포인트 dot로 active 표시.
- 각 항목은 `PortalSection` enum과 바인딩(`viewModel.selectedSection`)으로 탐색.

### 2-3. 사이드바 하단 공통 영역
- 하단 CTA: `새 감시 추가` 버튼 (현재는 미래 확장용 placeholder).
- 인증 영역:
  - 로그인 상태/프로필/클라우드 동기화 상태 표시.
  - 로그인 / 로그아웃 액션.

### 2-4. 메인 패널 상단 Hero Header
- 공통 구성:
  - 브레드크럼 텍스트.
  - 섹션별 아이콘 + 제목/서브타이틀.
  - 실행 상태 Badge(예: 감시 중, WakeUp Leaf 활성).

### 2-5. 하단 푸터
- 항상 표시:
  - 아이콘 버튼 2개(설정 이동용).
  - 동기화/계정 상태 라벨.
  - 섹션별 주 액션 버튼:
    - 프로젝트 채팅: `채팅 관리`(현재 비활성)
    - 노션 보기: `위키 보기`(현재 비활성)
    - WakeUp Leaf: `WakeUp Leaf 중지`
    - 기본: `감시 중지`
  - `기록 내보내기` 버튼(현재 액션 미연결).

## 3) 공통 컴포넌트(섹션 간 재사용 패턴)

- 카드 스타일:
  - `RoundedRectangle` + 라이트 보더 + 미세 그림자.
  - Soft Card 패턴은 루트 및 일부 피처에서 반복 사용.
- 버튼 패턴:
  - Primary/secondary 스타일이 루트와 아이콘관리/랜치카드에서 중복 패턴.
  - 라벨은 한글 중심, 버튼 영역 전체 클릭 처리.
- 커서/인터랙션:
  - `.clickableCursor()`를 이용해 hover 시 포인터 전환.
- 아이콘 정책:
  - `PortalIconRole` 기반 좌측 메뉴/카드/요소 아이콘 중앙 관리.
  - SF Symbols, Lucide, 커스텀 PNG/JPG/PDF 모두 바인딩/선택 가능.

## 4) 섹션별 특이사항(공통 요소 적용 범위)

- 스크롤 동작:
  - 노션 보기/프로젝트 채팅은 성능/상호작용을 위해 메인 영역을 비스크롤 컨테이너.
  - 나머지는 스크롤 컨테이너.
- 전역 상태 연동:
  - 기능별 상태 전환과 동작은 각 기능 ViewModel/Manager가 소유.
  - 포털 루트는 진입/레이아웃/전환/상태바 위주 관리.

## 5) 공통 요소 사용 규칙 제안 (정의)

1. `PortalRootView`는 레이아웃/탐색/공통 액션만 다룬다.
2. 기능별 화면은 자기 상태/로직을 각 Feature 뷰모델로 분리한다.
3. 메뉴 라벨/섹션명은 `PortalSection` 및 `Notion Hub/Settings` 등 공식 명칭 사용.
4. 하단 푸터의 `기록 내보내기`와 사이드바의 `새 감시 추가`는 실제 동작 구현 전까지는 placeholder 상태를 명시한다.
