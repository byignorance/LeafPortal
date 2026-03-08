# StudioLeaf Portal Design Guideline

## 🍃 1. Product Tone & Theme

- **핵심 아이덴티티**: Leaf Portal의 정체성은 **'산책(Flâneur)', '자연', '성장'**에 있습니다.
- **macOS 네이티브 감성**: 과한 장식보다 정돈된 스튜디오 포털 느낌을 우선하며, 밝은 배경과 부드러운 회색 패널을 기본으로 합니다.
- **포인트 컬러**: 짙은 국방색(`red: 0.10, green: 0.18, blue: 0.14`)을 메인으로, 초록색 계열의 긍정 상태색을 사용합니다.
- **언어**: 고유 이름 외 기본 언어는 한글을 유지합니다.

---

## 🎨 2. Component & Layout Rules

### [Card] 소프트 카드 (Soft Card)
- **Background**: `Color.white`, **Corner Radius**: `16pt`
- **Border**: `1px`, `Color.black.opacity(0.06)`
- **Shadow**: `radius: 8`, `y: 2`, `Color.black.opacity(0.04)`
- > **Guideline**: 단순 테두리보다 옅은 그림자를 사용하여 배경과 부드럽게 분리되는 'Floating' 느낌을 선호합니다.

### [Section Header] 섹션 헤더
- **Structure**: `Icon Box (28x28)` + `Title (Bold)`
- **Icon Box**: 주 테마색의 `8%` 투명도 배경을 사용하며, 아이콘 본체는 `opacity(0.7~0.8)`를 권장합니다.

### [Button] 버튼 및 드롭다운
- **Primary**: 짙은 국방색 배경 + 흰색 텍스트 + **그림자(`opacity 0.25`)** 필수.
- **Secondary**: 흰색 배경 + `1px` 외곽선 + 미세 그림자. 텍스트 대신 `ellipsis` 등 아이콘 버튼을 적극 활용합니다.
- **Disabled**: 배경 없이 `opacity(0.12)` 정도의 연한 외곽선으로만 표현합니다.

### [Input] 경로 및 데이터 영역
- **Background**: 연한 쿨그레이 (`red: 0.96, green: 0.97, blue: 0.97`)
- **Structure**: 좌측에 데이터 성격(폴더, 파일 등) 아이콘 고정 배치.

---

## 🔍 3. Icon Selection Rules

- **Theme-First (우선순위)**:
    1. **Nature**: `leaf`, `tree`, `flower`, `sun`, `drop`
    2. **Journey**: `figure.walk` (산책), `shoeprints.fill` (걸음), `path`, `waveform`
    3. **Calm**: `moon.stars`, `wind`, `hourglass`, `circle.inset.filled`
- **SF vs Lucide**:
    - 시스템 UI(설정, 닫기 등): **SF Symbols** 기본.
    - 기능 강조 및 도구용: **Lucide Icons**의 정교한 라인 아이콘 권장.
- **Size**: 아이콘은 `14~18pt` 크기, `medium` 또는 `semibold` 굵기를 표준으로 합니다.

---

## 🖱️ 4. Interaction & UX Rules

- **Hover**: 클릭 가능 영역은 반드시 포인터(`pointingHand`)가 바뀌어야 합니다.
- **Click Area**: 버튼, 카드, 메뉴 행은 텍스트만이 아니라 **시각적 블록 전체**가 클릭되어야 합니다.
- **Status**: 오류나 상태 변화는 색상만이 아니라 텍스트/아이콘을 병기하여 인지성을 높입니다.
- **새 기능 확장**: 기존 디자인 언어를 그대로 복제하지 말고, 포털 구조 안에서 기능별 헤더와 카드 레이아웃만 확장합니다.

