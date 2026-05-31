# PDF 설계서 패키징 절차

Step 6에서 이 문서를 참조한다. 01~05 산출물을 하나의 PDF로 패키징한다.

## 통합 마크다운 구조

`<feature-dir>/feature-design.md` 를 작성한다. 목차 순서는 **결론부터 → 상세** 로 배열한다 (읽는 사람이 요약을 먼저 본다).

```markdown
<div class="cover">
  <p class="cover-label">Feature Design Document</p>
  <h1 class="cover-title">{{FEATURE_NAME}}</h1>
  <div class="cover-meta">
    <p>작성일: {{DATE}}</p>
    <p>작성자: {{AUTHOR}} <!-- git user or skill invoker --></p>
    <p>기반 산출물: 01-analysis / 02-design / 03-review / 04-plan / 05-ui-demo</p>
  </div>
</div>

<!-- ========== 1. 최종 플랜 ========== -->
<div class="chapter">
<p class="chapter-number">Chapter 1</p>

{{04-plan.md 원문 (첫 # 헤더는 "최종 플랜"으로 바꿔도 됨)}}

</div>

<!-- ========== 2. UI 변경 데모 ========== -->
<div class="chapter">
<p class="chapter-number">Chapter 2</p>

# UI 변경 데모

<div class="feature-demo">
{{05-ui-demo.html의 <body> 내부를 "정규화"한 후 임베딩. 아래 ⚠ 절 참조.
 <h1 class="demo-title">은 위 챕터 헤더와 중복되므로 제거.}}
</div>

</div>

<!-- ========== 3. 설계 상세 ========== -->
<div class="chapter">
<p class="chapter-number">Chapter 3</p>

{{02-design.md 원문}}

</div>

<!-- ========== 4. 리뷰 의견 ========== -->
<div class="chapter">
<p class="chapter-number">Chapter 4</p>

{{03-review.md 원문}}

</div>

<!-- ========== 5. 현황 분석 부록 ========== -->
<div class="chapter">
<p class="chapter-number">Appendix</p>

{{01-analysis.md 원문}}

</div>
```

## ⚠ Chapter 2 UI 데모 임베딩 — HTML 정규화 필수

`05-ui-demo.html`의 `<body>` 내부를 들여쓰기·빈 줄을 그대로 둔 채 복붙하면 PDF의 일부 영역이 raw HTML 코드로 출력된다.

**왜 깨지는가** — md-to-pdf가 사용하는 마크다운 파서(marked/CommonMark)는 빈 줄을 만나면 HTML 블록을 종료하고, 그 다음 들여쓰기 4칸 이상으로 시작하는 줄을 "들여쓰기 코드 블록"으로 처리한다. 템플릿의 `state as-is`/`state to-be` 같은 형제 블록은 보통 들여쓰기 4칸으로 작성되고 사이에 빈 줄이 들어가므로, 두 번째 형제부터 코드 블록으로 떨어진다.

**정규화 규칙** — 임베딩 영역 전체에 다음을 일괄 적용한다:

1. 모든 줄의 leading whitespace 제거 (들여쓰기 0으로 정렬)
2. 영역 내부의 빈 줄 모두 제거 (HTML 블록 분절 방지)

`<pre>`/`<code>` 블록 내부는 들여쓰기·빈 줄을 보존해야 하므로 임베딩 영역에 코드 블록이 있다면 정규화 대상에서 제외한다 (Chapter 2 UI 데모에는 보통 없음).

**처리 방법** — `05-ui-demo.html`의 body 내부만 `/tmp/ui-demo-body.html`에 떼어놓고 sed로 한 번에 처리:

```bash
sed -e 's/^[[:space:]]*//' -e '/^$/d' /tmp/ui-demo-body.html \
  > /tmp/ui-demo-body.normalized.html
```

또는 통합 md를 작성한 후 Chapter 2 영역만 같은 sed 규칙으로 in-place 정규화한다.

정규화는 PDF 시각 결과에 영향이 없다 (HTML은 leading whitespace·빈 줄에 무관, 모든 시각 표현은 CSS가 담당).

## md-to-pdf 호출

`.claude/skills/md-to-pdf/SKILL.md` 의 기본 규약을 따르되, 아래 플래그를 추가한다:

```bash
npx md-to-pdf "<feature-dir>/feature-design.md" \
  --launch-options '{"args":["--no-sandbox"]}' \
  --stylesheet "<repo-root>/.claude/skills/feature-review/references/pdf-styling.css" \
  --pdf-options '{"format":"A4","margin":{"top":"20mm","right":"15mm","bottom":"20mm","left":"15mm"},"printBackground":true}' \
  --highlight-style "github" \
  --document-title "{{FEATURE_NAME}} 설계서"
```

**플래그 이유**:

| 플래그 | 이유 |
|---|---|
| `--launch-options '{"args":["--no-sandbox"]}'` | macOS/Linux Puppeteer 안정성 (md-to-pdf 스킬과 동일) |
| `--stylesheet` | 표지·챕터·하이라이트 스타일 주입 |
| `printBackground: true` | `.added/.changed/.removed` 하이라이트 배경색이 PDF에 보이도록 |
| `margin 20/15mm` | 한국 기업 문서 표준 여백 |
| `--highlight-style "github"` | 코드블록 가독성 |
| `--document-title` | PDF 메타데이터(탭/파일 속성에 표시) |

## 출력 경로

기본: `<feature-dir>/feature-design.pdf` (md-to-pdf는 원본 md와 동일 디렉토리 + 같은 basename으로 생성)

## 정리 정책

- `feature-design.md` 는 변환 후에도 **보존**한다 (사용자가 편집·재변환할 수 있도록).
- PDF 재생성 시 기존 `feature-design.pdf` 는 덮어쓴다.

## 실패 복구

| 증상 | 원인 후보 | 조치 |
|---|---|---|
| `md-to-pdf: command not found` | 패키지 미설치 | `npx --yes md-to-pdf ...` 로 재시도 |
| Puppeteer sandbox 에러 | `--no-sandbox` 누락 | launch-options 플래그 확인 |
| 한글 깨짐 (Tofu) | 시스템에 한글 폰트 없음 | `--css` 로 web-safe fallback 추가 (macOS/Linux는 Noto/Apple SD Gothic 기본 포함) |
| 하이라이트 배경색 미출력 | `printBackground` 누락 | pdf-options에 `"printBackground":true` 명시 |
| 이미지 안 보임 | 상대경로 문제 | md 파일과 같은 디렉토리 기준으로 `./image.png` 형태 유지 |
| 변환 60s 타임아웃 | 문서 과대 | `--timeout 120000` 추가, 또는 부록(01-analysis) 제외 버전 시도 |
| Chapter 2의 To-Be 등 일부 영역이 raw HTML 코드 그대로 PDF에 출력 | 임베딩 영역에 빈 줄 + 들여쓰기 4칸 이상 혼재 → 두 번째 형제 블록부터 들여쓰기 코드 블록으로 잡힘 | 위 "⚠ Chapter 2 UI 데모 임베딩 — HTML 정규화 필수" 절의 sed로 leading whitespace·빈 줄 제거 후 재변환 |

## 검증 체크리스트

PDF 생성 후 아래를 수동 확인:

- [ ] 표지에 기능명·날짜 정상 표시
- [ ] 각 챕터가 새 페이지에서 시작 (`.chapter` page-break 동작)
- [ ] UI 데모 섹션의 As-Is/To-Be 카드가 잘리지 않음 (`page-break-inside: avoid`)
- [ ] 하이라이트(.added/.changed/.removed) 색상 출력
- [ ] 한글 문자 깨짐 없음
- [ ] 코드블록 구문강조 표시
- [ ] PDF에 raw HTML 텍스트가 보이지 않음 — `pdftotext "<feature-dir>/feature-design.pdf" - | grep -E '<div class=|<section class=|<span class='` 매칭 0건
