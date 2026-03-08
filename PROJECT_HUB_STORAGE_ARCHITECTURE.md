# Project Hub Storage Architecture

Operational runbook:

- `PROJECT_HUB_EXTERNAL_STORAGE_RUNBOOK.md`

## Goal

StudioLeaf Portal의 프로젝트 허브를 단순 링크 모음이 아니라 프로젝트별 스토리지 운영 허브로 확장한다.

- Google Drive: 문서, 일정, 기획, 참고자료 관리
- Dropbox: 편집본, 그래픽, 렌더, 납품 산출물 관리
- Project Chat: 업로드 진입점
- Project Hub: 트리 구조/라우팅 정책/루트 연결 상태 관리

## Operational Accounts

인증 계층은 분리한다.

- 앱 전체 관리자 계정: `hello@studioleaf.kr`
- 외부 스토리지 실행 계정: `pd@studioleaf.kr`
- 일반 앱 사용자는 Firebase 개인 계정으로 로그인

Rules:

- Firebase 로그인 계정은 앱 접근과 프로젝트 멤버십 확인에만 사용
- Google Drive / Dropbox 조회 및 업로드는 `pd@studioleaf.kr` 기준으로 수행
- 외부 스토리지 자격은 클라이언트 앱이 아니라 서버 측에서 보관
- 앱 전체 관리자 메뉴는 1차에서 `hello@studioleaf.kr` allowlist 기준으로 접근 제어
- 추후 앱 전체 관리자 기능이 완성되면 allowlist를 정식 권한 모델로 교체

## Final UX

### Project Hub

- 프로젝트별 Google Drive 루트 폴더 지정
- 프로젝트별 Dropbox 루트 폴더 지정
- 앱 내에서 공통 트리 구조 관리
- 루트 지정 후 표준 하위 폴더 일괄 생성
- 각 논리 폴더별:
  - 표시 이름
  - 하위 경로
  - 연결 대상 스토리지(`googleDrive` / `dropbox`)
  - 매칭 키워드
  - 업로드 기본 분류
  - 활성 여부
- 앱 내에서 파일 트리 목록 보기
- 개별 파일 클릭 시 해당 서비스 웹 링크로 이동

### Project Chat

- 채팅에서 파일 첨부 가능
- 첨부 시 분류/용도 선택
- 분류 기준으로 Google Drive 또는 Dropbox의 대응 폴더로 자동 업로드
- 업로드 완료 후 채팅에 저장 위치 링크와 폴더 정보 표시

## Storage Strategy

### Provider Roles

- Google Drive
  - docs
  - references
  - schedule
  - meeting-notes
  - scripts
  - admin
- Dropbox
  - footage
  - graphics
  - renders
  - exports
  - delivery
  - review

### Logical Folder Definition

앱 내부에서는 실제 외부 경로 대신 논리 폴더를 기준으로 관리한다.

Each logical folder contains:

- `id`
- `title`
- `provider`
- `relativePath`
- `keywords`
- `allowedExtensions`
- `sortOrder`
- `isRequired`
- `isVisible`

Example:

- `docs/meeting-notes` -> Google Drive
- `renders/final` -> Dropbox
- `delivery/client` -> Dropbox

### Root Mapping

프로젝트별로 저장:

- `googleDriveRootFolderId`
- `googleDriveRootTitle`
- `googleDriveRootWebURL`
- `dropboxRootPath`
- `dropboxRootTitle`
- `dropboxRootWebURL`

실제 업로드 대상은:

`project root + logicalFolder.relativePath`

형태로 계산한다.

## Data Model Changes

### ProjectArchive

현재 `resourceLinks` 기반 구조를 확장한다.

- `googleDriveRootFolderId: String?`
- `googleDriveRootTitle: String?`
- `googleDriveRootWebURL: String?`
- `dropboxRootPath: String?`
- `dropboxRootTitle: String?`
- `dropboxRootWebURL: String?`
- `storageTemplateVersion: Int`
- `storageFolders: [ProjectStorageFolder]`

### ProjectStorageFolder

```swift
struct ProjectStorageFolder: Identifiable, Codable, Equatable, Sendable {
    enum Provider: String, Codable, Sendable {
        case googleDrive
        case dropbox
    }

    let id: String
    var title: String
    var provider: Provider
    var relativePath: String
    var keywords: [String]
    var allowedExtensions: [String]
    var sortOrder: Int
    var isRequired: Bool
    var isVisible: Bool
}
```

### Chat Upload Routing Metadata

```swift
struct ProjectChatUploadIntent: Codable, Equatable, Sendable {
    let projectArchiveID: String
    let folderID: String
    let provider: String
    let targetRelativePath: String
    let originalFilename: String
    let selectedCategory: String
}
```

## Required New Services

### GoogleDriveService

Responsibilities:

- OAuth session
- Root folder selection
- Folder existence check
- Folder create
- File list
- File upload
- Web link resolve

### DropboxService

Responsibilities:

- OAuth session
- Root path selection
- Folder existence check
- Folder create
- File list
- File upload
- Shared/web link resolve

### ProjectStorageProvisioner

Responsibilities:

- 프로젝트 루트와 표준 트리 기준으로 실제 외부 폴더 생성
- 누락된 폴더만 생성
- 생성 결과를 `storageFolders` 상태와 동기화

### ProjectStorageRouter

Responsibilities:

- 채팅 업로드 파일을 논리 폴더로 라우팅
- 분류/키워드 기반 추천
- provider 결정
- 외부 업로드 서비스 호출

### StorageAdminService

Responsibilities:

- 앱 전체 관리자 메뉴에서 Google Drive / Dropbox 연결 계정 상태 표시
- `pd@studioleaf.kr` 기준 자격 연결/교체 플로우 관리
- Firebase Functions 또는 서버 비밀 저장소와 연동

## Admin Menu Scope

앱 전체 관리자 메뉴를 별도로 둔다.

- 접근 대상: `hello@studioleaf.kr`
- 관리 대상:
  - Google Drive 연결 계정
  - Dropbox 연결 계정
  - 현재 활성 외부 스토리지 계정 상태
  - 연결 만료/재인증 상태

1차에서는 앱 전체 관리자 메뉴가 외부 스토리지 계정 연결만 담당한다.
프로젝트별 권한 관리는 별도 기능로 분리한다.

## Folder Provisioning Flow

1. 사용자가 프로젝트 허브에서 Google Drive 루트 지정
2. 사용자가 프로젝트 허브에서 Dropbox 루트 지정
3. 앱이 현재 저장된 표준 트리 로드
4. "폴더 구조 생성" 실행
5. Provider별로 누락 경로 생성
6. 결과를 허브에 반영

## File Tree View Scope

1차 범위:

- 폴더 목록
- 파일 목록
- 이름
- 수정 시각
- 파일 크기
- provider 배지
- 웹에서 열기

제외:

- 바이너리/문서 본문 프리뷰
- 인앱 영상 재생
- 인앱 문서 렌더링

## Chat Upload Flow

1. 채팅에서 파일 첨부
2. 분류 선택:
   - 문서
   - 레퍼런스
   - 미팅
   - 렌더
   - 그래픽
   - 편집본
   - 납품본
   - 기타
3. 앱이 매칭 폴더 추천
4. 사용자가 최종 폴더 확인
5. 업로드 실행
6. 채팅 메시지에 업로드 결과 남김

## Admin UI Scope

프로젝트 허브 내 추가 패널:

- `스토리지 연결`
  - Google Drive 루트 선택
  - Dropbox 루트 선택
- `폴더 구조`
  - 논리 폴더 목록
  - provider 변경
  - 경로 변경
  - 키워드 변경
  - 표준 구조로 리셋
  - 외부 폴더 생성 실행
- `파일 브라우저`
  - provider 탭
  - 트리 목록
  - 최근 파일

## Recommended Delivery Phases

### Phase 1

- 프로젝트 허브 데이터 모델 확장
- 스토리지 루트 저장
- 논리 폴더 편집 UI
- 표준 트리 템플릿 적용
- 관리자 allowlist(`hello@studioleaf.kr`) 기반 메뉴 노출 제어

### Phase 2

- Google Drive / Dropbox OAuth 연결
- 루트 폴더 선택
- 표준 하위 폴더 생성
- Firebase Functions 기반 외부 스토리지 게이트웨이
- `pd@studioleaf.kr` 연결 상태 관리자 메뉴

### Phase 3

- 앱 내 파일 트리 목록
- 웹으로 열기

### Phase 4

- 채팅 파일 업로드 라우팅
- 분류 기반 자동 매칭
- 업로드 결과 메시지 생성

## Risks

- Dropbox는 공유 링크/팀 정책에 따라 웹 접근 제약이 있을 수 있다.
- Google Drive와 Dropbox의 폴더 식별 방식이 다르므로 공통 추상화가 필요하다.
- 채팅 첨부 업로드는 파일 크기 제한, 재시도, 중복 업로드 정책을 먼저 정해야 한다.
- 폴더 자동 생성은 부분 실패 처리와 idempotency가 중요하다.

## Decision

프로젝트 허브의 스토리지 기능은 다음 기준으로 구현한다.

- 외부 스토리지 자체 구조가 아니라 앱 내부의 논리 트리를 기준으로 운영한다.
- 파일 프리뷰는 하지 않고 파일 목록/트리만 보여준다.
- 개별 파일 열기는 각 provider의 웹 링크로 위임한다.
- 채팅 업로드는 논리 폴더 라우팅을 거쳐 실제 provider로 전송한다.
