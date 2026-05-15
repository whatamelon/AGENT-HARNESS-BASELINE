# 장식 eyebrow / 영어 UI 라벨 금지 (글로벌 디자인 하네스)

## 핵심 규칙

> **(1) 섹션/페이지 타이틀 바로 위에 ALL CAPS micro eyebrow·키커 라벨을 두지 않는다.
> (2) 화면에 노출되는 UI 라벨은 한국어가 기본. 비기능 영어 라벨(장식성 ALL CAPS 영문)은 금지.**

상위 패밀리: [[no-design-slop]] (AI 디자인 슬롭 10분야 — 본 룰은 그 중 강제 hook 구현분).

"NOTIFICATION CENTER / CONTACT / DELIVERY DETAILS / WHY BBAKCAR / MEMBER" 처럼
큰 타이틀 위에 얹는 영문 미니 헤더는 매거진 감성이 아니라 "AI가 자동 생성한 톤"이 된다.
큰 타이틀(`display-*`/`heading-*`)만으로 섹션을 구획하고, 호흡은 spacing으로 잡는다.

## 안티패턴 (금지)

```tsx
// ❌ 섹션 타이틀 위 장식 eyebrow
<CuratorTag label="NOTIFICATION CENTER" tone="ash" />
<Text className="text-display-l ...">새로 도착한 소식.</Text>

// ❌ className 직접 박은 영문 ALL CAPS 키커
<Text className="text-micro uppercase tracking-wider font-semibold">DELIVERY DETAILS</Text>
<Text className="text-heading-l ...">배송 정보</Text>

// ❌ 비기능 영문 라벨 (의미 없는 영어 표식)
<Badge label="CEO PICK" />
<FilterGroup label="MAKE">
```

## 안전 패턴

```tsx
// ✅ 타이틀만으로 섹션 구획, eyebrow 없음
<Text className="text-display-l font-extrabold text-ink leading-9">
  새로 도착한 소식.
</Text>

// ✅ 라벨이 꼭 필요하면 한국어로
<Badge label="CEO 픽" />
<FilterGroup label="제조사">
```

## 허용 예외 (eyebrow 자체가 아니라 per-item 메타 / 고유명사)

- **카드 내부 per-item 메타 라벨** (섹션 헤더가 아닌 항목 레벨) — 단, 한국어로. 영문 장식 라벨 금지
- **고유명사**: 브랜드명·모델 코드(`BMW`, `Tesla`, `GT3`) — 번역 불가하므로 영문 유지
- **기술 토큰(사용자 비노출)**: 코드·API·URL·env 키 — 본 규칙 대상 아님
- **표준 약어**: `CEO`, `VIP` 등 한국에서 그대로 통용되는 약어는 한국어 문맥 내 사용 OK (`CEO 픽`)

## 적용 대상

모든 프로젝트, 모든 UI 산출물 (RN/웹/랜딩/어드민). 새 화면 작성·기존 화면 수정 양쪽.
프로젝트 로컬 DESIGN.md가 "ALL CAPS eyebrow"를 권장하더라도 **본 글로벌 룰이 우선**한다
(프로젝트 DESIGN.md는 본 룰에 맞춰 갱신한다).

## 강제 메커니즘 (수동 룰 아님)

본 룰은 문서만이 아니라 **Stop 게이트 hook으로 자동 강제**된다:

- `~/.config/claude-sync/claude/hooks/quality-check.py` 의 `check_eyebrow_slop()`
- 매 턴 종료(Stop)마다 그 세션에서 수정된 `.tsx/.jsx/.ts/.js`를 재스캔
- 위반 발견 시 `exit 2`로 file:line을 에이전트에 강제 피드백 → 수정 전까지 계속 표면화
- 동시편집 프로세스가 eyebrow를 되돌려도 다음 Stop에서 재적발 (현재 파일 내용 기준 스캔)
- allowlist(`EYEBROW_ALLOW`): 브랜드·플랫폼 고유명사 + 한국 통용 약어. 한글 포함·변수보간·주석 라인은 오탐 제외

룰 텍스트와 hook의 allowlist/패턴은 함께 갱신한다 (한쪽만 바꾸면 드리프트).

## How to apply

- UI 작성/수정 시: 타이틀 위에 micro ALL CAPS 라벨을 얹으려는 충동이 들면 → **얹지 말 것**. 타이틀 + spacing으로 충분
- 화면 텍스트에 영어가 들어가면 → 고유명사/기술토큰/통용 약어인지 자가 점검. 아니면 한국어로
- 기존 화면에서 위반 발견 시 즉시 제거(섹션 eyebrow) 또는 한글 전환(per-item 라벨)
- eyebrow 제거 후 타이틀에 남은 dangling margin(`mt-4` 등) 함께 정리
- `testID`는 보존
- [[design-context]] 로드 시 본 룰을 active constraint로 함께 적용. [[ui-service-quality-bar]] 9번(헤더 가볍게)과 같은 방향

## Why

**Why:** 빡차 앱 `notifications` 등 다수 화면에서 "NOTIFICATION CENTER" 류 영문 eyebrow가 반복 생성됨.
사용자가 "필요 없다, 글로벌 하네스로 앞으로 모든 디자인에 안 들어가게" 명시 지시(2026-05-15).
프로젝트 DESIGN.md는 §0.6에서 이미 같은 금지를 명시했으나 글로벌 SSOT엔 없어 슬롭이 계속 재발 →
글로벌 룰로 승격해 매 세션 자동 로드.

**How to judge edge cases:** "이 영어/eyebrow가 사용자에게 정보를 더하는가, 아니면 톤 장식인가?"
장식이면 제거. 정보(브랜드·통용 약어)면 최소 형태로 한국어 문맥에 녹인다.
