# Icon Management Guide

`StudioLeafPortal`의 아이콘 관리는 아래 우선순위로 통합합니다.

## Source Of Truth

1. 운영 아이콘 라이브러리
   - URL: `https://leaf-asset-library-336177244400.us-west1.run.app/`
   - 로컬 기준: `leaf-asset-library.json`
   - 실제 배포용 SVG: `canonical-svg/`

2. Figma
   - 역할: 의미, 네이밍, 톤, 은유 구조 확인
   - 로컬 기준: `leaf-icon-manifest.json`

3. HTML/스크린샷 복원본
   - 역할: 임시 보강, 비교, fallback
   - 로컬 기준: `material-symbol-map.json`, `svg/`

## 관리 규칙

- 앱에서 새 아이콘을 쓸 때는 먼저 `canonical-svg/`를 확인합니다.
- 아이콘 식별자는 가능한 한 `filename` 기준으로 유지합니다.
- UI 표시는 사용자 친화적 이름을 쓰고, 파일명은 변경하지 않습니다.
- 같은 의미의 보조 아이콘이 있어도 운영 원본과 다른 모양이면 대체하지 않습니다.
- Figma와 운영 페이지가 충돌하면 `운영 페이지의 path data`를 우선합니다.

## 현재 운영 기준

- 총 아이콘 수: `25`
- 포맷: `SVG`
- 그리드: `24px center / 2px padding`
- 두께: `1.0pt / 0.125rem`
- 기본 색상: `#1A2E26`
- 배경 기준: `#F8FAF9`

## Render Noti 추천 매핑

- 감시 시작/상태: `observation.svg`
- 대상 경로/폴더: `path_trail.svg`
- 완료/결과물: `open_gate.svg`
- 알림/이벤트: `pebble_alert.svg` 또는 `rain_error.svg`
- 활동 로그: `footprint_history.svg`
- 진행 흐름: `wind_sync.svg` 또는 `search_find.svg`
- 설정 안내/내비게이션: `compass_nav.svg`

## 파일 구조

- `leaf-asset-library.json`
  - 운영 페이지에서 추출한 메타데이터와 path data
- `canonical-svg/`
  - 운영 기준 SVG 파일
- `leaf-icon-manifest.json`
  - Figma 기준 의미/용도 매핑
- `material-symbol-map.json`
  - HTML 기반 fallback 매핑
- `svg/`
  - HTML/스크린샷 기반 보조 SVG

## 업데이트 절차

1. 운영 아이콘 페이지 JS 번들을 다시 가져옵니다.
2. `id`, `name`, `metaphor`, `filename`, `path`, `iconName`를 파싱합니다.
3. `leaf-asset-library.json`을 갱신합니다.
4. `canonical-svg/*.svg`를 재생성합니다.
5. Figma 의미 체계가 바뀌었으면 `leaf-icon-manifest.json`도 맞춥니다.
6. 앱에서 쓰는 아이콘 이름이 바뀌면 화면 매핑도 같이 수정합니다.

## 주의사항

- 현재 운영 페이지의 path 데이터는 시각적으로 `filled path` 형태입니다.
- Figma나 초기 HTML은 `line-art` 설명이 있었지만, 실제 배포 기준은 운영 페이지 산출물을 따릅니다.
- 따라서 앱에서 stroke 기반 재해석을 하려면 별도 디자인 합의가 필요합니다.
