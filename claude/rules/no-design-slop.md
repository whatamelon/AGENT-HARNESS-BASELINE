# AI 디자인 슬롭 금지 (글로벌 디자인 하네스)

> **AI에게 디자인을 맡기면 반복 생성되는 저품질 패턴 모음. 모바일 B2C 기준선은
> 무신사·지그재그·당근·토스 수준의 꼼꼼함이다.** 이 기준을 못 넘는 화면은
> "동작은 하지만 AI가 자동 생성한 티"가 난다.

기존 자산과 함께 적용: [[no-decorative-eyebrow]] (장식 eyebrow/영문라벨, hook 강제),
[[ui-service-quality-bar]] (dead affordance/가짜통계/풀블리드/카드밀도/헤더경량).
본 문서는 그 둘이 안 덮는 색·아이콘·정렬·border·모달·상세위계·메타 꼼꼼함을 덮는다.
중복 항목은 해당 룰을 따르고 여기서 재정의하지 않는다.

---

## 1. 색감

- **슬롭**: 보라·인디고 디폴트 그라데이션, 무지개 5색, accent 남발, 프레임워크 기본색(`blue-500`) 그대로, hover만 살짝 어둡게, 텍스트 대비 4.5:1 미달, 다크모드 대비 붕괴, 의미색 체계 없음, 토큰 무시 임의 hex/arbitrary.
- **1등앱 바**: 무채 베이스 + brand accent 1개. 색은 액션·상태에만. (토스=무채+파랑1, 당근=주황1, 무신사=흑백)
- **self-check**: 디자인 토큰만 사용했나? 화면당 accent ≤1? 그라데이션은 의미 있는 1곳뿐인가? 라이트/다크 둘 다 대비 통과?

## 2. 아이콘

- **슬롭**: 라이브러리 혼용(lucide+heroicons+이모지), 사이즈 난립, stroke-width 불일치, 장식 아이콘, 이모지를 아이콘 대용, 라벨 없는 아이콘 버튼, 액션과 무관한 아이콘.
- **1등앱 바**: 단일 세트, 통일 사이즈/스트로크, 텍스트 동반 또는 관용 아이콘만, 장식 0.
- **self-check**: 아이콘 import 소스 1개인가? 사이즈/스트로크 통일? 모든 아이콘이 의미·액션을 갖나? 이모지를 아이콘으로 쓰지 않았나?

## 3. 정렬

- **슬롭**: 중앙정렬 남발(본문까지 center), 좌/우 혼재, baseline 안 맞음, 아이콘+텍스트 수직정렬 깨짐, 숫자·금액 우측정렬 안 함, 라벨-값 그리드 어긋남.
- **1등앱 바**: 본문 좌측정렬 고정, 금액·숫자 우측, 정렬선 한 축 통일, 아이콘-텍스트 center 일관.
- **self-check**: 본문이 center로 도배되지 않았나? 숫자 컬럼 우측정렬? 한 화면의 좌측 정렬선이 하나로 통일되나?

## 4. 리스트

- **슬롭**: 카드 거대화(1스크린 1.5개), divider 없음/과함, 동일 카드 무한, 썸네일 비율 깨짐, skeleton/empty/error/zero 상태 없음, 페이지네이션·무한스크롤 미구현, 항목 간격 불규칙, 탭타깃 44px 미만.
- **1등앱 바**: 컴팩트 행(썸네일 ~100 + 정보), 1스크린 3+ 항목, skeleton+empty+error 필수, 일관 divider. (당근/무신사 리스트 밀도) — 카드 사이즈 상세는 [[ui-service-quality-bar]].
- **self-check**: 1스크린에 핵심 항목 3+ 보이나? 로딩/빈/에러 상태를 다 그렸나? 썸네일 비율 고정? 탭타깃 ≥44px?

## 5. 상세페이지

- **슬롭**: hero+인용+CTA 욱여넣기, 위계 없음(다 같은 크기), sticky CTA 없음/중복, 핵심정보 fold 아래, 갤러리 1장, 가짜 추천, 뒤로가기 동작 애매.
- **1등앱 바**: 이미지→핵심정보→상세→액션 위계, sticky 단일 CTA, 핵심정보 첫 화면, 한 페이지 한 미션. (CTA 중복 금지는 [[ui-service-quality-bar]])
- **self-check**: 첫 화면에 가격·핵심이 보이나? 위계가 크기로 드러나나? sticky CTA가 정확히 1개인가? 추천이 실데이터인가?

## 6. 글로벌 네비 / 헤더 / 바텀시트

- **슬롭**: 헤더에 검색+알림+도움말 다 박기, 탭루트 뒤로가기, 바텀네비 5+탭, 스크롤 동기 없음, 바텀시트 드래그/스냅/백드롭 없음, safe-area 무시, sub페이지에 글로벌네비 노출.
- **1등앱 바**: 헤더 최소(제목±1), 탭 ≤5, 스크롤 방향 show/hide 동기, 바텀시트 드래그+스냅+백드롭 닫기, safe-area 준수. (헤더 경량 상세는 [[ui-service-quality-bar]])
- **self-check**: 헤더 우측 액션 ≤1? 탭루트에 뒤로가기 없나? 바텀시트가 드래그·백드롭으로 닫히나? safe-area inset 적용?

## 7. 모달 UX

- **슬롭**: 모달 위 모달 스택, 닫기 X만(백드롭/제스처 없음), 풀스크린감을 작은 모달로, 모달 내 스크롤 깨짐, ESC/뒤로가기 무반응, 페이지로 충분한 걸 모달로, 키보드가 입력 가림, 진입 애니 튐.
- **1등앱 바**: 선택은 인라인 expand/바텀시트(모달 X), 모달은 파괴 액션·확인만, 백드롭+제스처+뒤로가기 다 닫힘, 키보드 avoid, 단일 레이어. (인라인 expand 패턴은 [[ui-service-quality-bar]])
- **self-check**: 모달이 중첩되지 않나? 백드롭·뒤로가기로 닫히나? 선택 UI를 모달 대신 인라인/바텀시트로 했나? 키보드가 입력을 안 가리나?

## 8. border / ring

- **슬롭**: border 두께 0.5/1/2 난립, 회색 hardcode, focus ring 없음(접근성), ring+border 동시, 카드마다 radius 다름, double border, divider를 border로 흉내, 다크모드 border 안 보임.
- **1등앱 바**: 단일 border 토큰 + radius 표준 1~2개, focus-visible ring 필수, hairline divider 일관.
- **self-check**: border 색이 토큰인가? radius가 표준값(임의 px 금지)인가? 키보드 포커스 ring이 있나? border와 ring을 동시에 쓰지 않았나?

## 9. 카드 디자인

- **슬롭**: shadow 과함(blur 40 / elevation 24), shadow+border+ring 동시, radius 제각각, 카드 안 카드, 패딩 비대칭, 풀블리드 hero 남발, 카드마다 구조 다름, 모바일인데 press 피드백 없음.
- **1등앱 바**: 평평+hairline border 위주(shadow 절제), 카드 2종만(컴팩트 리스트형 / 풀블리드 hero), radius·padding 동일, press 피드백 필수. (카드 표준 2종은 [[ui-service-quality-bar]])
- **self-check**: shadow가 과하지 않나? 카드 종류가 2종 이내인가? radius·padding이 카드 간 동일? 모바일 press 피드백이 있나? 카드 안에 카드 없나?

## 10. 한국 1등앱 꼼꼼함 (메타 기준선)

무신사·지그재그·당근·토스가 기본으로 하는 것 — 안 하면 "덜 만든 앱".

- **즉시 피드백**: 탭 반응 <100ms, 옵티미스틱 업데이트, 햅틱
- **모든 상태**: skeleton / empty / error / zero / offline 전부 디자인 (일부만 하면 슬롭)
- **자연 한국어 카피**: 번역체·영문 더미 금지 ([[no-decorative-eyebrow]] 강제)
- **숫자 포맷**: 천단위 콤마, `원`, 상대시간(`3분 전`), raw 출력 금지
- **전환 일관성**: 화면 전환·애니메이션 한 가지 언어로
- **pull-to-refresh / 키보드 처리 / 스크린리더 라벨 / 다크모드 완전**
- **첫 진입 0.5초 안에 가치가 보인다**
- **self-check**: 위 8개 중 빠진 게 있나? 하나라도 빠지면 1등앱 바 미달.

---

## 구조 (5계층 — "정규식 불가"를 맞는 구조로 전환)

단일 소스: `~/.config/claude-sync/claude/hooks/designslop_detectors.py`.
`quality-check.py`(Stop, 세션 수정파일) 와 `designslop-audit.py`(전수) 가 동일 `run_all` 호출 → 드리프트 0.

| 계층 | 방식 | 분야 | 상태 |
|---|---|---|---|
| **A. 즉시 게이트** (`exit 2`, `🚫`) | `quality-check.py` | eyebrow/영문라벨 ([[no-decorative-eyebrow]]), D1 아이콘혼용, D2 border·radius arbitrary, D-EMOJI 이모지데코, **D6 네비** | **라이브** |
| **B. 경고** (Stop `⚠️` 비차단) | `quality-check.py` | D3 raw hex, D4 리스트 빈상태, D7 Modal close, D9 과도 shadow | **라이브** |
| **레저(추적)** | `~/.claude/logs/designslop-review.jsonl` | 정규식 판별 불가 퍼지케이스(.map 리스트/커스텀 오버레이/계산식 shadow) — 못 잡으면 버리지 말고 추적 | **라이브** |
| **전수 감사 (Tier F)** | `designslop-audit.py <root>` | 세션 밖 잠재 슬롭 + baseline 대비 회귀만 게이트(CI용). `--baseline` 수용 스냅샷 | **라이브** |
| **C. 판단/시각** | `designslop-rubric.json` + 리뷰/비전 에이전트 | 1 색감종합, 3 정렬, 5 상세위계, 한국1등앱 메타 | **루브릭화** (머신리더블 채점계약) |

**못한 것 → 어떻게 구조화했나**
- **D6 네비** (이름이 프로젝트마다 다름) → 추측 안 함. 프로젝트가 `.designslop.json`(레포 루트)에 `nav.globalComponents`/`tabRootGlobs` **선언** → 선언 시에만 발화, 미선언 시 비활성 = 오탐 0. "기술 한계"가 "선언 계약"으로 전환됨.
- **C 판단영역** (정규식 불가) → `designslop-rubric.json` 의 머신리더블 probe(질문/pass·fail/severity/evidence)로 구조화. 리뷰·비전 에이전트가 렌더 화면에 일관 채점. 게이트는 Stop이 아니라 명시 리뷰 게이트.
- **세션만 스캔** (옛 파일 잠재 슬롭 못 봄) → 전수 `designslop-audit.py` + `.designslop-baseline.json`(수용 residue). CI는 신규 회귀만 비영점 종료.
- **도메인 영어 오탐**(SUV/CAR 등) → 매니페스트 `allow.englishLabels` 프로젝트 선언. 테스트/스토리 파일은 출하 UI 아니므로 디텍터 전역 제외.
- **cancel MCP false-success** → `~/.config/claude-sync/bin/omc-cancel-verify.sh <mode>` 로 검증된 복구 절차 스크립트화(MCP 비의존, 잔존0 단언).

라이브 게이트: `file-tracker.py`(PostToolUse) → 세션파일 → `quality-check.py`(Stop) → `exit 2`(A)/`⚠️`(B)/레저. 동시편집 재발도 다음 Stop 재적발.

검증된 오탐 제외:
- 아이콘: lucide-react↔lucide-react-native 동일 패밀리
- border/radius: `rounded-[var()/theme()]` 토큰
- hex: 경로 colors/theme/token, `#000/#fff`, SVG fill/Path, `shadowColor`(해당 hex만)
- 이모지: 화살표(→←↑↓), `·` `×`, `✓`(U+2713), `★☆`(2605/06 평점), `♠♥♦♣`(2660-2667 카드슈트), 마작/카드블록(1F000-1F2FF). 데코 본체 1F300↑ + 큐레이트 BMP
- 공통: 주석/`import` 라인, **테스트·스토리·목 파일(`.test.`/`.spec.`/`.stories.`/`__tests__`)**
- 프로젝트 선언: `.designslop.json` `allow.englishLabels`
- B-휴리스틱 잔여 한계는 **레저로 추적**(D4 `.map`/D7 커스텀시트/D9 계산식) — 미탐이 아니라 추적된 미확정

## How to apply

- UI 작성·수정 시: 해당 분야 self-check를 통과해야 작업 완료로 본다
- 새 패턴(리스트/모달/카드 등) 작성 전 같은 패턴이 다른 화면에 있으면 그걸 먼저 참조 (1등앱은 일관성으로 완성됨)
- 디자인 톤과 본 기준은 둘 다 충족 — 톤 우선이라며 기준 희생 금지
- A계층 위반은 Stop hook이 자동 차단(구현된 분야). B/C는 작성자·리뷰어가 책임
- 룰/hook allowlist·패턴은 함께 갱신 (한쪽만 바꾸면 드리프트)

## Why

**Why:** 사용자가 AI 디자인 위임 결과의 저품질을 다수 목격. eyebrow는 한 사례일 뿐,
색·아이콘·정렬·border·모달·상세위계·메타 꼼꼼함 전반에서 동일하게 재발(2026-05-15 지시).
모바일 B2C 기준선은 한국 1등앱(무신사/지그재그/당근/토스) 수준으로 못박는다.
글로벌 룰로 승격해 매 세션 자동 로드, 가능한 분야는 hook으로 강제.

**How to judge edge cases:** "이 화면을 토스/당근 PM이 봤을 때 통과시킬까?"
통과 못 할 디테일이면 슬롭. 정보를 더하지 않는 장식은 빼고, 빠진 상태·포맷·일관성은 채운다.
