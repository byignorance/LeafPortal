# LEAF Icon Library

이 폴더는 `StudioLeafPortal`에서 사용하는 LEAF 아이콘 시스템의 로컬 기준점입니다.

현재 기준 원본은 3개입니다.

1. 아이콘 운영 원본

- URL: `https://leaf-asset-library-336177244400.us-west1.run.app/`
- 로컬 매니페스트: `leaf-asset-library.json`
- 로컬 SVG 세트: `canonical-svg/`

2. 시각/의미 기준 Figma 파일:

- File: `LEAF Portal`
- URL: `https://www.figma.com/design/MH614VTJPSAtcP4cMcZhBZ/LEAF-Portal?node-id=0-1&p=f&t=vGrqcGQCoKV0FQUw-0`
- Root node: `0:1`

3. 보조 기준 HTML 파일:

- File: `/Users/sangjoonpark/Downloads/stitch (2)/code.html`
- 성격: `Material Symbols Outlined` 이름 매핑 기반 아이콘 카탈로그

## 현재 상태

- 운영 기준 `25개` 아이콘 세트는 `leaf-asset-library.json`과 `canonical-svg/`에 저장됨
- Figma 기준 아이콘 목록과 용도는 `leaf-icon-manifest.json`에 정리됨
- HTML 기준으로 복원 가능한 SVG는 `svg/` 아래에 저장됨
- HTML 기준 매핑은 `material-symbol-map.json`에 정리됨
- Figma 커스텀 원본 SVG는 아직 미추출 상태
- 이유: 현재 세션에서 Figma MCP 추가 호출 한도 초과, MCP가 반환한 자산 URL은 외부 `curl` 기준 `404`

## 다음 추출 절차

1. Figma MCP 한도가 리셋되면 개별 아이콘 노드에서 `get_design_context` 재실행
2. 각 아이콘의 벡터 자산 또는 path 데이터를 `.svg`로 저장
3. 저장 위치:
   - `Resources/LeafIcons/svg/<icon-name>.svg`
4. 앱 적용 시 우선순위:
   - 브랜드: `leaf-logo`
   - Render Noti 핵심 동작: `observation`, `path`, `alert`, `open-gate`, `footprints`

## 현재 생성된 SVG

운영 기준 SVG:

- `canonical-svg/leaf_logo.svg`
- `canonical-svg/observation.svg`
- `canonical-svg/path_trail.svg`
- `canonical-svg/footprint_history.svg`
- `canonical-svg/lantern_active.svg`
- `canonical-svg/compass_nav.svg`
- `canonical-svg/seedling_new.svg`
- `canonical-svg/ancient_tree.svg`
- `canonical-svg/pebble_alert.svg`
- `canonical-svg/wind_sync.svg`
- `canonical-svg/park_bench.svg`
- `canonical-svg/binoculars.svg`
- `canonical-svg/open_gate.svg`
- `canonical-svg/walking_stick.svg`
- `canonical-svg/map_context.svg`
- `canonical-svg/star_fav.svg`
- `canonical-svg/cloud_sync.svg`
- `canonical-svg/rain_error.svg`
- `canonical-svg/sun_system.svg`
- `canonical-svg/moon_dark.svg`
- `canonical-svg/telescope_remote.svg`
- `canonical-svg/watering_update.svg`
- `canonical-svg/fence_boundary.svg`
- `canonical-svg/bridge_link.svg`
- `canonical-svg/search_find.svg`

- `observation.svg`
- `path.svg`
- `discovery.svg`
- `seedling.svg`
- `compass.svg`
- `lantern.svg`
- `footprints.svg`
- `alert.svg`
- `ancient-tree.svg`
- `pebble.svg`
- `wind.svg`
- `park-bench.svg`
- `binoculars.svg`
- `open-gate.svg`
- `workspace.svg`
- `progress.svg`
- `growth.svg`
- `flow.svg`

참고:

- `canonical-svg/`는 운영 페이지 번들에서 직접 추출한 기준 세트
- `discovery.svg`, `seedling.svg`, `footprints.svg`는 `code.html`과 스크린샷을 기준으로 수동 복원
- 나머지는 공개 `Material Icons` SVG를 로컬 저장

## 디자인 기준

- 캔버스: `24x24`
- 안전 여백: `2px`
- 스트로크: `1.5pt`
- 코너 반경: `2px / 4px`
- 간격 전략: `2px`

## 스튜디오 팔레트

- Primary Active: `#17CF54`
- Studio Depth: `#0D1A12`
- Muted Glyph: `#94A3B8`
