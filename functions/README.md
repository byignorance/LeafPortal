# StudioLeafPortal Functions

현재 Functions는 외부 스토리지 관리자 메타를 읽고 저장하는 최소 스캐폴드만 포함한다.

## Included

- `getExternalStorageAdminStatus`
- `updateExternalStorageAdminStatus`

## Intended Next Step

외부 스토리지 실제 연결은 이후 아래 비밀값을 Firebase Functions / Secret Manager에 추가한 뒤 구현한다.

- Google Drive 실행 계정: `pd@studioleaf.kr`
- Dropbox 실행 계정: `pd@studioleaf.kr`
- 필요한 값:
  - Google OAuth client id
  - Google OAuth client secret
  - Google refresh token or delegated service-account configuration
  - Dropbox app key
  - Dropbox app secret
  - Dropbox refresh token

## Local Commands

```bash
npm install
npm run build
firebase deploy --only functions
```
