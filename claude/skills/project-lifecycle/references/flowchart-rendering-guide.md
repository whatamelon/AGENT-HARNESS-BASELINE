# Flowchart / Diagram 렌더링 가이드

`42.flowchart_data`, `43.flowchart_workflow`, `80.project_management` (WBS mindmap·Timeline gantt) 산출물을 마크다운 뷰어와 PDF 양쪽에서 깨지지 않게 보는 절차.

## 작성 원칙 (소스 단계에서 보장)

| 원칙 | 이유 |
|---|---|
| **Mermaid 단일 소스** | 텍스트 기반 → git diff, 협업, AS-IS/TO-BE 좌우 비교 가능 |
| **본문 `.md`에 코드블록 임베드 + `.mmd` 단독 파일 동시 보관** | 본문은 사람·뷰어용, `.mmd`는 mmdc 빌드용. 두 파일 내용은 항상 동기 유지 |
| **CDN/외부 의존 금지** | 오프라인 PDF 빌드 가능해야 함 |
| **classDef 인라인** | Mermaid가 import 미지원 → `_shared/classes.mmd` 복사 |

---

## 트랙 A — 마크다운 뷰어 (개발·검토 단계)

### A-1. GitHub / GitLab

✅ 별도 작업 불필요. mermaid 코드블록 자동 렌더링.

`.md` 파일을 GitHub에 push하면 그대로 보임. PR 리뷰에서도 동일.

### A-2. VS Code / Cursor

확장 설치 한 번:

```
Markdown Preview Mermaid Support (bierner.markdown-mermaid)
```

`Cmd+Shift+V`로 마크다운 미리보기 → mermaid 다이어그램 렌더링.

### A-3. Claude Code / IDE

대부분 자동 지원. 안 되면 위 VS Code 확장 동일.

### A-4. 일반 마크다운 뷰어 (Obsidian, Typora 등)

대부분 mermaid 내장. 없으면 mermaid 플러그인 설치.

---

## 트랙 B — PDF 빌드 (배포·인쇄 단계)

### B-1. 가장 단순: GitHub 브라우저 인쇄 ★ 권장

1. GitHub에서 해당 `.md` 파일 열기
2. 브라우저 인쇄 (`Cmd+P`) → "PDF로 저장"
3. mermaid 다이어그램 그대로 PDF에 포함됨

**장점**: 정합성 100%, 추가 도구 불필요
**단점**: 수동, 단일 파일만 가능

### B-2. mmdc 사전 빌드 + md-to-pdf ★ 자동화 권장

mermaid를 SVG로 미리 빌드해서 `.md`에 이미지로 임베드한 뒤 PDF 변환. 오프라인 가능.

#### 1단계: mmdc 설치

```bash
npm install -g @mermaid-js/mermaid-cli
```

#### 2단계: SVG 빌드

각 다이어그램 디렉토리에서:

```bash
mmdc -i as-is.mmd -o rendered/as-is.svg -t neutral -b transparent
mmdc -i to-be.mmd -o rendered/to-be.svg -t neutral -b transparent
```

옵션:
- `-t neutral`: 중립 테마 (인쇄 호환)
- `-b transparent`: 배경 투명 (PDF 배경과 자연스럽게 결합)
- `-w 1600`: 너비 지정 (기본 800)

#### 3단계: 본문에 SVG 임베드

기존 mermaid 코드블록과 **함께** 또는 대신 SVG 이미지 참조:

```markdown
## AS-IS

![AS-IS Flow](rendered/as-is.svg)

<details>
<summary>Mermaid 소스 보기</summary>

\`\`\`mermaid
graph LR
  ... (실제 코드)
\`\`\`
</details>
```

#### 4단계: md-to-pdf 호출

`/md-to-pdf` 스킬 사용:

```bash
npx md-to-pdf "<path>/FCD-L1-001_system-landscape.md" --launch-options '{"args":["--no-sandbox"]}'
```

→ 동일 디렉토리에 `.pdf` 생성. SVG 이미지 그대로 포함.

#### 일괄 빌드 스크립트 (참고)

`scripts/render-flowcharts.sh` 같은 파일로 묶어두면 편하다:

```bash
#!/usr/bin/env bash
# 모든 .mmd → SVG 빌드 후 해당 .md → PDF
set -e
ROOT="${1:-.projects/<project>/42.flowchart_data}"

# .mmd → SVG
find "$ROOT" -name "*.mmd" | while read mmd; do
  dir=$(dirname "$mmd")
  base=$(basename "$mmd" .mmd)
  mkdir -p "$dir/rendered"
  mmdc -i "$mmd" -o "$dir/rendered/$base.svg" -t neutral -b transparent
done

# .md → PDF (본문에 SVG 참조하도록 사전 편집되어 있어야 함)
find "$ROOT" -name "FCD-*.md" -o -name "FCW-*.md" | while read md; do
  npx md-to-pdf "$md" --launch-options '{"args":["--no-sandbox"]}'
done
```

### B-3. md-to-pdf + mermaid 직접 (실험적)

md-to-pdf의 `--launch-options`에 mermaid 스크립트를 inject하면 코드블록을 직접 렌더링할 수 있지만, Puppeteer 타이밍 이슈로 빈 박스가 나오는 경우가 있다. **B-2 사전 빌드가 안정적**.

---

## 권장 워크플로우

### 작성·리뷰 단계
- 본문 `.md`에 mermaid 코드블록 임베드만으로 충분
- GitHub PR / VS Code 미리보기로 검토
- `.mmd` 단독 파일도 동일 내용으로 유지 (PDF 빌드 대비)

### approved 시점
- B-1 (간단 1회성) 또는 B-2 (자동화) 중 선택
- approved 시점의 `rendered/*.svg`를 git 커밋 → 스냅샷 보존
- 다이어그램 변경 시 SVG도 재빌드 + 커밋

### 추적성
- `.md` 변경(approved 재진입) → `.mmd`도 동기화 → SVG 재빌드 → PDF 재생성
- frontmatter의 `updated_at`이 SVG·PDF 빌드 트리거

---

## 자주 마주치는 문제

| 증상 | 원인 | 해결 |
|---|---|---|
| GitHub에서 다이어그램 안 보임 | mermaid 문법 오류 | `mmdc -i x.mmd -o /tmp/x.svg`로 로컬 검증 |
| GitHub에서 `Parse error ... got 'STR'` | `==>"라벨"==>` (thick arrow + label) 사용 | **`==>` 사용 금지**. `-- "라벨" -->` 로 대체. GitHub Mermaid 렌더러가 thick arrow의 inline label을 파싱하지 못함 |
| PDF에서 텍스트 깨짐 | 한글 폰트 누락 | mmdc `-c config.json`에 `fontFamily` 명시 또는 SVG 텍스트를 path로 변환 |
| 노드 너무 크고 박스 잘림 | 7±2 초과 | 하위 레벨로 분할. 본 다이어그램은 sub-flow 박스만 |
| AS-IS와 TO-BE 비교 어려움 | 노드 위치 다름 | mermaid는 자동 레이아웃이라 한계. 수동 좌표 필요하면 Excalidraw 보조 사용 (단, 단일 출처 원칙 위반 주의) |
| 색상이 인쇄에서 안 보임 | 배경/대비 부족 | `_shared/classes.mmd` 표준 색상 사용. 인쇄용은 stroke 굵기로 구분 보강 |

---

## 다이어그램 종류별 추가 노트

### Mindmap (WBS 트리)

```
mindmap
  root((프로젝트))
    모듈 A
      작업 1
      작업 2
    모듈 B
      작업 3
```

- **장점**: 노드 적을 때 가독성 ↑, 한 화면 압축
- **한계**: status별 색상 표시 어려움 → 본문에 work_items 표 병행
- **노드 50개 초과**: `graph TD`로 폴백 권장 (status classDef 적용 가능)
- **GitHub 렌더링**: Mermaid v9+ 지원. 매우 오래된 GitHub Enterprise 인스턴스는 미지원 가능

### Gantt (타임라인)

```
gantt
  dateFormat YYYY-MM-DD
  axisFormat %m/%d

  section 설계
  작업 A :crit, done, t01, 2026-04-10, 3d
  작업 B :active, t02, after t01, 5d
  작업 C :t03, after t02, 7d

  section 마일스톤
  설계 완료 :milestone, m1, after t03, 0d
```

- **상태 키워드** (자동 색상): `done`, `active`, `crit`(임계 경로), 미지정(=todo)
- **의존성**: `after <id>` 또는 명시적 시작일 (`2026-04-10`)
- **마일스톤**: `:milestone, id, date, 0d`
- **임계 경로 마킹**: 사람이 검토 후 `crit` 클래스 추가 — Claude가 자동 산출 X
- **baseline 비교**: gantt 자체는 단일 시점만 표현 → baseline은 `snapshots/<date>_baseline.md`의 별도 gantt로 보관 → 변경 시 두 다이어그램 좌우 비교

### Mermaid 자체 한계 — 보조 도구 검토

| 한계 | 우회 |
|---|---|
| Gantt에서 자원(사람) 충돌 시각화 어려움 | 별도 표 또는 외부 도구(예: GanttProject) 비주기적 사용 |
| Mindmap에서 상태별 색상 미지원 | `graph TD` 폴백 또는 본문 표 병행 |
| 의존성 화살표 복잡도 | 너무 복잡하면 하위 레벨로 분할 (계층 원칙) |
| AS-IS/TO-BE 노드 위치 정렬 | Mermaid 자동 레이아웃 한계 — 좌우 비교가 핵심이면 동일 노드 ID·순서 유지 |

---

## 관련 도구

- **Mermaid 공식 문서**: https://mermaid.js.org/
- **Mermaid Live Editor**: https://mermaid.live/ (빠른 검증용)
- **mmdc (mermaid-cli)**: https://github.com/mermaid-js/mermaid-cli
- **md-to-pdf 스킬**: 이 프로젝트의 `/md-to-pdf` 슬래시 커맨드
- **VS Code 확장**: `bierner.markdown-mermaid`
