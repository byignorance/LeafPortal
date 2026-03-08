# Project Hub External Storage Runbook

## Purpose

StudioLeafPortal의 Project Hub 외부 스토리지 연동을 다시 설정하거나 복구할 때 참고하는 운영 문서다.

이 문서는 다음을 다룬다.

- Google Drive 연동 순서
- Dropbox 연동 순서
- Firebase Functions secret 이름
- 콘솔 메뉴 접근 위치
- 앱 내 검증 순서
- 토큰 만료, 권한 오류 시 재설정 절차

비밀값 자체는 이 문서에 저장하지 않는다.

## Operational Roles

- Firebase 앱 전체 관리자: `hello@studioleaf.kr`
- 외부 스토리지 실행 계정: `pd@studioleaf.kr`
- 일반 사용자: Firebase 로그인 사용자 각자 계정

원칙:

- 앱 관리자 계정과 외부 스토리지 실행 계정은 분리한다.
- Google Drive / Dropbox API 호출은 `pd@studioleaf.kr` 권한으로 수행한다.
- 자격 증명은 Firebase Functions secret에 저장한다.
- 클라이언트 앱에는 비밀값을 넣지 않는다.

## Current Storage Policy

- Google Drive
  - 문서, 기획, 참고자료, 관리성 파일
  - 프로젝트 생성 시 `년도_프로젝트이름` 폴더 생성
  - 하위에 스토리지 템플릿 기준 폴더 생성
- Dropbox
  - 편집본, 그래픽, 렌더, 납품 산출물
  - 프로젝트 생성 시 `년도_프로젝트이름` 폴더 생성
  - 하위에 스토리지 템플릿 기준 폴더 생성

## App UI Entry Points

- 외부 스토리지 상태/검증:
  - `환경설정 > 외부 스토리지 계정 관리`
- 프로젝트별 루트 정보 확인:
  - `프로젝트 허브 > 프로젝트 선택 > 설정`
- 프로젝트별 파일 목록 보기:
  - `프로젝트 허브 > Google Drive`
  - `프로젝트 허브 > Dropbox`

## Google Drive Setup

### Google Side Decisions

- Google Cloud 프로젝트 소유자는 `hello@studioleaf.kr` 기준이어도 된다.
- 실제 OAuth refresh token은 `pd@studioleaf.kr` 계정으로 발급해야 한다.
- Shared Drive 안에 Project Hub 전용 루트를 둔다.

### Current Folder Convention

- Shared Drive 내부 루트 폴더 이름:
  - `studioLEAF Projects/Project Hub Root`

실제 Functions에는 아래 두 값이 필요하다.

- `Shared Drive ID`
- `Project Hub Root Folder ID`

### ID Extraction Rule

Google Drive URL 예시:

```text
https://drive.google.com/drive/u/1/folders/0AL3TbX5ngakVUk9PVA
https://drive.google.com/drive/u/1/folders/1zwDP4DrSaiQGJYLcc7xK3ORg_e_eMDlT
```

규칙:

- `/folders/` 뒤 문자열이 ID다.
- Shared Drive URL이면 Shared Drive ID
- Project Hub Root 폴더 URL이면 Root Folder ID

### Required Firebase Secrets

- `GOOGLE_DRIVE_OAUTH_CLIENT_ID`
- `GOOGLE_DRIVE_OAUTH_CLIENT_SECRET`
- `GOOGLE_DRIVE_OAUTH_REFRESH_TOKEN`
- `GOOGLE_DRIVE_SHARED_DRIVE_ID`
- `GOOGLE_DRIVE_PROJECT_HUB_ROOT_FOLDER_ID`

### Google OAuth Refresh Token Issuance

개요:

- OAuth 앱은 메인 관리자 Google 프로젝트 기준으로 생성 가능
- refresh token은 반드시 `pd@studioleaf.kr`로 승인받아야 함

핵심 입력값:

- OAuth Client ID
- OAuth Client Secret
- Refresh Token

권장 절차:

1. Google Cloud Console에서 OAuth Client 생성
2. `pd@studioleaf.kr`로 OAuth 승인
3. refresh token 발급
4. Firebase Functions secret 저장

### Secret Storage

터미널 위치:

```bash
cd /Users/sangjoonpark/0_local/main_work_macbook/mac_apps/StudioLeafPortal
```

저장:

```bash
firebase functions:secrets:set GOOGLE_DRIVE_OAUTH_CLIENT_ID --project studioleafportal
firebase functions:secrets:set GOOGLE_DRIVE_OAUTH_CLIENT_SECRET --project studioleafportal
firebase functions:secrets:set GOOGLE_DRIVE_OAUTH_REFRESH_TOKEN --project studioleafportal
firebase functions:secrets:set GOOGLE_DRIVE_SHARED_DRIVE_ID --project studioleafportal
firebase functions:secrets:set GOOGLE_DRIVE_PROJECT_HUB_ROOT_FOLDER_ID --project studioleafportal
```

### App Validation

앱에서:

1. `환경설정 > 외부 스토리지 계정 관리`
2. `Google Drive 연결 검증`
3. 성공 시 상태가 `connected`로 갱신되는지 확인

### Provision Check

앱에서 신규 Project Hub 생성 후 확인:

1. `년도_프로젝트이름` 폴더 생성
2. 템플릿 기반 하위 폴더 생성
3. 프로젝트 허브 상세에 Google Drive 루트 링크 저장

## Dropbox Setup

### Dropbox App Console

접속:

- [Dropbox App Console](https://www.dropbox.com/developers/apps)

앱 생성 규칙:

1. `Create app`
2. `Scoped access`
3. `Full Dropbox`
4. App name: `StudioLeafPortal`

메모:

- 앱 소유자는 메인 관리자 계정이어도 된다.
- 실제 refresh token은 `pd@studioleaf.kr`로 발급해야 한다.

### Required Dropbox Permissions

Dropbox App Console `Permissions` 탭에서 체크:

- `account_info.read`
- `files.metadata.read`
- `files.metadata.write`
- `files.content.read`
- `files.content.write`

권한 체크 후 `Submit` 반영

### User Limit Note

개발 상태 Dropbox 앱은 사용자 수 제한이 있을 수 있다.

대표 증상:

- `This app has reached its user limit`

해결:

- App Console에서 사용자 수 확장
- 또는 테스트 사용자 허용 후 재시도

### Required Firebase Secrets

- `DROPBOX_APP_KEY`
- `DROPBOX_APP_SECRET`
- `DROPBOX_REFRESH_TOKEN`

### Dropbox OAuth Authorization URL

아래 URL의 `YOUR_APP_KEY`를 실제 App key로 바꿔서 연다.

```text
https://www.dropbox.com/oauth2/authorize?client_id=YOUR_APP_KEY&response_type=code&token_access_type=offline
```

주의:

- `APP_KEY`라는 문자 그대로 넣으면 안 된다.
- 실제 Dropbox App key 값을 넣어야 한다.
- 반드시 `pd@studioleaf.kr` 계정으로 승인한다.

### Dropbox Authorization Code Exchange

authorization code를 받으면 터미널에서 교환한다.

```bash
curl https://api.dropbox.com/oauth2/token \
  -d code='YOUR_AUTH_CODE' \
  -d grant_type=authorization_code \
  -d client_id='YOUR_APP_KEY' \
  -d client_secret='YOUR_APP_SECRET'
```

응답 JSON에서 필요한 값:

- `refresh_token`

중요:

- `access_token`이 아니라 `refresh_token`을 저장해야 한다.
- authorization code는 1회용이다.

### Secret Storage

터미널 위치:

```bash
cd /Users/sangjoonpark/0_local/main_work_macbook/mac_apps/StudioLeafPortal
```

저장:

```bash
firebase functions:secrets:set DROPBOX_APP_KEY --project studioleafportal
firebase functions:secrets:set DROPBOX_APP_SECRET --project studioleafportal
firebase functions:secrets:set DROPBOX_REFRESH_TOKEN --project studioleafportal
```

### Current Dropbox Root Convention

- Dropbox 프로젝트 루트 경로:
  - `/01_ProjectHub`

프로젝트 생성 시:

- `/01_ProjectHub/년도/년도_프로젝트이름`

형태로 폴더가 만들어지고, 그 아래 템플릿 하위 폴더가 생성된다.

### App Validation

앱에서:

1. `환경설정 > 외부 스토리지 계정 관리`
2. `Dropbox 연결 검증`
3. 성공 시 상태가 `connected`로 갱신되는지 확인

### Provision Check

앱에서 신규 Project Hub 생성 후 확인:

1. Dropbox 프로젝트 폴더 생성
2. 템플릿 기반 하위 폴더 생성
3. 프로젝트 허브 상세에 Dropbox 루트 경로 및 URL 저장

## Firebase Deploy

Functions secret 변경 후에는 Functions 재배포가 필요하다.

```bash
cd /Users/sangjoonpark/0_local/main_work_macbook/mac_apps/StudioLeafPortal
firebase deploy --only functions
```

참고:

- artifact cleanup policy 경고는 배포 실패와 다르다.
- 함수 업데이트가 성공했으면 기능 자체는 반영된 상태일 수 있다.

## Reissue Checklist

아래 상황이면 토큰을 다시 발급하는 쪽으로 본다.

- 외부 스토리지 검증이 갑자기 실패
- OAuth refresh token revoked
- 실행 계정 변경
- 앱 권한 범위 변경

Google Drive 재발급 시:

1. `pd@studioleaf.kr`로 새 refresh token 발급
2. `GOOGLE_DRIVE_OAUTH_REFRESH_TOKEN` 교체
3. 필요 시 client id / client secret도 같이 점검
4. Functions 재배포
5. 앱에서 `Google Drive 연결 검증`

Dropbox 재발급 시:

1. `pd@studioleaf.kr`로 authorization code 재발급
2. 새 refresh token 발급
3. `DROPBOX_REFRESH_TOKEN` 교체
4. Functions 재배포
5. 앱에서 `Dropbox 연결 검증`

## Troubleshooting

### Google Drive

- 증상: 프로젝트 생성 시 폴더 생성 실패
  - 점검:
    - Shared Drive ID
    - Root Folder ID
    - `pd@studioleaf.kr` 권한
    - Functions 배포 여부

- 증상: 검증 버튼 반응 없음
  - 점검:
    - Functions 최신 배포 여부
    - Firebase 로그인 상태
    - 관리자 계정이 `hello@studioleaf.kr`인지

### Dropbox

- 증상: `Invalid client_id`
  - 원인:
    - 인증 URL에 실제 App key 대신 문자열 `APP_KEY` 입력

- 증상: `This app has reached its user limit`
  - 원인:
    - 개발 앱 사용자 제한
  - 해결:
    - App Console에서 user limit 확장 또는 테스트 사용자 허용

- 증상: 메인 계정으로는 되는데 `pd` 계정은 안 됨
  - 원인:
    - refresh token 발급 계정이 잘못되었거나 사용자 제한 문제

- 증상: 연결 검증 실패
  - 점검:
    - `DROPBOX_APP_KEY`
    - `DROPBOX_APP_SECRET`
    - `DROPBOX_REFRESH_TOKEN`
    - `/01_ProjectHub` 실제 존재 여부
    - Functions 재배포 여부

## Do Not Store Here

이 문서에는 저장하지 않는다.

- App key 실제 값
- App secret 실제 값
- refresh token 실제 값
- Google client secret 실제 값

이 값들은 Firebase Functions secret에만 저장한다.
