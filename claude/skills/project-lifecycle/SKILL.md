---
name: project-lifecycle
description: ".projects/ 워크스페이스의 프로젝트 라이프사이클을 관리한다 — 조직, 워크플로우, 요구사항, 현황분석, 시스템 현황·정보구조(IA)·메뉴, 시스템 라이프사이클(planning/partial/live/deprecated), 개선방향, 구현계획, UI/UX 설계, 데이터·워크플로우 흐름도, 마이그레이션·cutover 진척, 사용자 가이드, 인수테스트, 프로젝트 관리(WBS/타임라인), 요청관리의 전체 흐름을 문서화하고 추적한다. 사용자가 '프로젝트 라이프사이클', 'project lifecycle', '요구사항 작성', '현황 분석', '개선 방향', '구현 계획', 'UI 설계', 'UX 설계', '화면 설계', '플로우차트', 'flowchart', '데이터 흐름', '워크플로우 흐름', 'data flow', 'workflow flow', '흐름도', 'AS-IS TO-BE 비교', '시스템 현황', '정보 구조', 'IA', '메뉴 트리', '메뉴 현황', '화면 인벤토리', '역할 가시성', 'sitemap', '사이트맵', '시스템 라이프사이클', 'lifecycle_stage', 'partial 가동', 'live 가동', 'deprecated 시스템', 'cutover', '마이그레이션 계획', '사용자 가이드 작성', '인수 테스트', 'WBS', '작업 분해', '타임라인', 'timeline', 'Gantt', '간트', '마일스톤', 'milestone', '일정', 'baseline', '진척률', '임계 경로', 'critical path', '요청 관리', '프로젝트 문서', '.projects 작업', 'phase management', '영향도 분석', '추적성 확인' 등을 언급하거나, .projects/ 폴더 내 문서 작업이 필요할 때 반드시 이 스킬을 사용한다."
---

# /project-lifecycle — 프로젝트 라이프사이클 관리자

## 역할

소프트웨어 프로젝트의 전체 라이프사이클(조직 정의 → 워크플로우 → 요구사항 → 현황분석 → 개선방향 → 구현계획 → UI/UX 설계 → 데이터·워크플로우 흐름도 → 마이그레이션 → 사용자 가이드 → 인수테스트 → 프로젝트 관리(WBS/타임라인) → 요청관리)을 `.projects/` 워크스페이스 내에서 체계적으로 문서화하고 추적하는 **프로젝트 라이프사이클 관리자**로서 행동한다.

## 핵심 원칙

1. **추적성(Traceability)**: 모든 문서는 상류·하류 문서에 대한 참조를 유지한다
2. **롤업(Rollup)**: 하위 문서의 요약이 상위 overview에 자동 반영되는 구조를 유지한다
3. **변경 이력**: 요청(99.requests)에 의한 변경은 영향받는 모든 문서에 이력으로 남긴다
4. **한국어 기본**: 본문은 한국어, 기술 용어·ID·파일명은 영어
5. **진척률 단일 출처**: 작업 단위 진척률·일정의 *유일한 정본은 80.project_management* (WBS/TL). 다른 phase의 `_overview.md`는 작성 상태(draft/reviewed/approved) 신호등만 표시하고, 실행 진척률은 80에서 가져온다
6. **Story ≠ Task**: REQ Story는 *비즈니스 가치 단위* ("무엇을 만든다"), WBS Task는 *실행 단위* ("얼마나 시간/누가"). 1 Story → N Task 매핑 가능. WBS work item의 `refs` 필드로 Story 역참조

## 사전 준비

작업 시작 전 프로젝트 구조를 파악한다:

```bash
# 대상 프로젝트 폴더 확인
ls .projects/
# 프로젝트 내 phase별 기존 문서 목록
find .projects/<project-name>/ -name "*.md" -type f | sort
```

템플릿 상세는 `references/templates.md`를 참조한다.

---

## Phase 맵

```
00.organizations ──┐
01.workflows ──────┤ (기반 정의)
                   │
10.requirements ───┤ (변경의 시작점)
        │          │
        ▼          │
20.as_is_analysis ─┤ (현황 파악)
21.system_landscape┤ (시스템 현황 — 전 phase에서 참조)
22.access_control ─┤ (RBAC 정책·운영·라이프사이클 — 횡단 거버넌스)
        │          │
        ▼          │
30.to_be_directions┤ (방향 설정)
        │          │
        ├──────────▼
40.implementation_plans ──┐ (기술 설계 — DB/API/화면 경로)
41.ui_design ─────────────┤ (화면·UI/UX 설계 — AS-IS/TO-BE HTML 프로토타입)
42.flowchart_data ────────┤ (데이터 흐름 — AS-IS/TO-BE Mermaid, L1/L2/L3 계층)
43.flowchart_workflow ────┤ (워크플로우 흐름 — AS-IS/TO-BE Mermaid, L1/L2/L3 계층)
50.migration_plans ───────┤ (데이터 이관)
        │                 │
        ▼                 │
60.user_guide ────────────┤ (사용법 문서화)
        │                 │
        ▼                 │
70.user_acceptance_log ───┘ (검증/인수)

80.project_management ──→ (WBS/타임라인 — 모든 phase의 작업·일정·진척률 단일 출처)

99.requests ──→ (어느 phase든 변경 트리거)
```

### 의존성 방향 (상류 → 하류)

| 상류 | 하류 | 관계 |
|------|------|------|
| requirements | as_is_analysis | 요구사항이 분석 대상 정의 |
| as_is_analysis | to_be_directions | 현황이 개선 방향 근거 |
| system_landscape (시스템 프로필 + IA/메뉴) | as_is_analysis | AS 문서가 화면(SCR-*) 단위로 ref |
| system_landscape (IA/메뉴) | to_be_directions | 통합·폐기 대상 메뉴/화면 식별 baseline |
| system_landscape | implementation_plans | 기존 시스템 기반 구현 제약/연동 설계 |
| system_landscape (IA/메뉴) | migration_plans | 화면·시트 단위 cutover 계획 |
| system_landscape (IA/메뉴) | user_guide | 기존 사용자가 쓰던 메뉴 → 새 메뉴 안내 |
| system_landscape (AS-IS IA) ↔ ui_design (TO-BE 사이트맵) | _sitemap/mapping.md | AS→TO 화면 매핑 (50 cutover 근거) |
| system_landscape (각 SYS ia/role-visibility) ↔ access_control (matrix) | role-menu-matrix | 시스템별 메뉴 가시성 ↔ 횡단 정책 cross-ref |
| access_control (ROLE-* 정책) | requirements / implementation_plans / migration_plans | 권한 요구사항·seed 마이그·이관 시 권한 부여 근거 |
| (모든 마이그·seed) | access_control/changes (CHG-RBAC-*) | Role 부여·회수·만료 audit 정본 |
| `som.platform_user_roles` (DB) | access_control/assignments (YYYY-MM-DD_user-roles.md) | DB가 정본, assignments는 시점 export (월간/이벤트, user-level 상세) |
| to_be_directions | implementation_plans | 개선 방향을 구현으로 구체화 |
| to_be_directions | migration_plans | 데이터/시스템 전환 계획 |
| implementation_plans | ui_design | 기술 설계를 시각 설계(화면)로 구체화 |
| system_landscape, implementation_plans | flowchart_data | 시스템·모듈 간 데이터 객체 흐름 시각화 |
| workflows, requirements, to_be_directions | flowchart_workflow | 액터·액티비티 단계별 흐름 시각화 |
| flowchart_data | implementation_plans (역방향 검증), user_guide | 데이터 흐름이 기술 설계·가이드의 시각 근거 |
| flowchart_workflow | user_guide, user_acceptance_log | 워크플로우 흐름이 사용 흐름·검증 근거 |
| implementation_plans | user_guide | 구현 단위가 가이드 단위 (기술 근거) |
| ui_design | user_guide | 화면 프로토타입이 가이드 스크린샷·시연 근거 |
| user_guide | user_acceptance_log | 가이드 기반 인수 테스트 |
| (모든 실행 phase: REQ/IMP/UX/MIG/UG/UAT) | project_management | work item으로 흡수, 일정·진척 추적 |
| project_management | (역참조) | 마일스톤·진척률을 각 phase 대시보드에 롤업 |
| requests | (모든 phase) | 변경 트리거 |

---

## 문서 ID 체계

각 phase마다 고유 접두사를 사용한다. 번호는 3자리 zero-padded.

| Phase | 접두사 | 예시 |
|-------|--------|------|
| organizations | `ORG` | ORG-001 |
| workflows | `WF` | WF-001 |
| requirements (Epic) | `REQ` | REQ-001 |
| requirements (Story) | `REQ-nnn-Snn` | REQ-001-S01 |
| as_is_analysis | `AS` | AS-001 |
| system_landscape (시스템) | `SYS` | SYS-001 |
| system_landscape — 메뉴 노드 (in `ia/`) | `SYS-nnn/M-nnn[-mm]` | SYS-001/M-002-01 |
| system_landscape — 화면 (in `ia/`) | `SYS-nnn/SCR-{module}-nnn` | SYS-001/SCR-PO-001 |
| system_landscape — Excel 시트 (in `ia/`) | `SYS-nnn/sheet-{name}` | SYS-004/sheet-po-master |
| access_control — Role 정책 | `ROLE` | ROLE-001 (`ROLE-001_super-admin.md`, frontmatter `code: SUPER_ADMIN`) |
| access_control — 변경 이력 | `CHG-RBAC` | CHG-RBAC-001 (`CHG-*` (99.requests)와 별도 ID 공간) |
| to_be_directions | `TB` | TB-001 |
| implementation_plans | `IMP` | IMP-001 |
| ui_design | `UX` | UX-001 |
| flowchart_data | `FCD` | FCD-L1-001, FCD-L2-001, FCD-L3-001 |
| flowchart_workflow | `FCW` | FCW-L1-001, FCW-L2-001, FCW-L3-001 |
| migration_plans | `MIG` | MIG-001 |
| user_guide | `UG` | UG-001 |
| user_acceptance_log | `UAT` | UAT-001 |
| wbs (in project_management) | `WBS`, `WBS-nnn-Tnn` | WBS-001, WBS-001-T01 |
| timeline (in project_management) | `TL` | TL-001 |
| milestone (in timeline) | `MS` | MS-001 |
| requests | `CHG` | CHG-001 |

**파일명 규칙**: `{ID}_{kebab-case-제목}.md`
- 예: `REQ-001_purchase-order-automation.md`
- 예: `REQ-001-S01_po-creation-flow.md`

---

## 폴더 구조 규칙

### 00.organizations — 조직 구조

고유한 밸류체인을 가진 사업부만 폴더 분리. 나머지는 단일 파일.

```
00.organizations/
├── _overview.md              # 전체 조직 트리 롤업
├── ORG-001_headquarters.md   # 본사 조직
├── division-a/               # 사업부 A (독립 밸류체인)
│   ├── _overview.md          # 사업부 A 롤업
│   ├── ORG-002_sales.md
│   └── ORG-003_logistics.md
└── division-b/               # 사업부 B (독립 밸류체인)
    ├── _overview.md
    └── ORG-004_manufacturing.md
```

### 01.workflows — 워크플로우

레벨별 파일 분리. 사업부별 하위 폴더. 상위 overview에 롤업.

#### 워크플로우 레벨 정의

| 레벨 | 명칭 | 성격 | 관점 | 예시 |
|------|------|------|------|------|
| **Lv.1** | 메가 프로세스 | 기업의 핵심 밸류체인을 구성하는 **End-to-End 업무 영역**. 전사 공통이며, 조직·시스템·산업에 무관하게 존재하는 보편적 업무 분류. 하나의 Lv.1은 독립적인 목적(가치 창출, 원가 관리, 품질 보증 등)을 가진다. | 경영진 / C-Level | 영업/물류, 구매/재고, 생산, 품질, 회계 |
| **Lv.2** | 주요 프로세스 | 메가 프로세스를 **기능 단위로 분해**한 것. "무엇을 하는가"에 해당하며, 조직 구조나 시스템과 1:1 매핑되지 않는다. Lv.1 내에서 논리적으로 구분되는 업무 덩어리. | 부서장 / 팀장 | 영업관리, 출하/배송, 발주관리, 입고/검수, BOM관리, 공정관리 등 |
| **Lv.3** | 세부 프로세스 | 주요 프로세스의 **구체적 절차/단계**. "어떻게 하는가"에 해당하며, 여기서부터 사업부별 분기가 시작된다. 동일 Lv.2라도 사업부마다 다른 Lv.3가 이어질 수 있다. | 실무 담당자 | 견적서 작성, 단가 협상, 발주서 발행, 입고 검수 처리 |
| **Lv.4** | 작업 절차 | 세부 프로세스의 **시스템 조작 수준 단계**. 화면·버튼·입력 필드 수준. 사용자 가이드(UG)의 직접적 근거가 된다. | 시스템 사용자 | ERP에서 PO 생성 → 품목 추가 → 승인 요청 |
| **Lv.5** | 예외/분기 규칙 | 작업 절차 내 **비즈니스 규칙, 예외 처리, 분기 조건**. 구현 설계(IMP)의 직접적 근거가 된다. | 개발자 / 설계자 | 금액 100만 이상 시 2차 승인, 해외 발주 시 관세 계산 |

**Lv.1~2**: 전사 공통 → 루트에 파일 배치
**Lv.3~5**: 사업부별 분기 가능 → 사업부 하위 폴더에 배치

#### 레벨 분리 판별 기준

새 워크플로우를 Lv.2로 올릴지, Lv.3에 둘지 판단할 때:

| 질문 | Lv.2 (주요 프로세스) | Lv.3 (세부 프로세스) |
|------|---------------------|---------------------|
| 업무 **목적** 자체가 다른가? | Yes (예: B2B 영업 vs B2C 주문 — 판매 모델이 다름) | — |
| 목적은 같고 **절차/규칙**만 다른가? | — | Yes (예: 수입 발주 vs 국내 발주 — 발주라는 목적 동일) |
| 부서장 관점에서 **별도 관리 단위**인가? | 별도 팀/조직이 담당 (B2B영업팀 ≠ B2C운영팀) | 같은 팀 내 담당 분리 |
| 사업부마다 **유무 자체가 다른가**? | — | Yes (솜인터내셔널은 수입 있음, 솜티앤엘은 없음) |

```
01.workflows/
├── _overview.md                           # 전사 워크플로우 맵 (Lv.1~2 롤업)
├── WF-001_lv1-sales-logistics.md          # Lv.1 메가 프로세스
├── WF-006_lv2-sales-management.md         # Lv.2 주요 프로세스
├── WF-007_lv2-shipping-delivery.md
├── som-international/                     # 솜인터내셔널 (Lv.3~ 분기)
│   ├── _overview.md
│   ├── WF-010_lv3-quotation-domestic.md
│   └── WF-011_lv4-po-entry.md
└── som-tnl/                               # 솜티앤엘 (Lv.3~ 분기)
    ├── _overview.md
    └── WF-020_lv3-quotation-overseas.md
```

### 10.requirements — 요구사항 (Epic → Story)

Epic 단위 파일 + Story 하위 파일. Task 단위로는 내리지 않음.

```
10.requirements/
├── _overview.md                          # 전체 요구사항 롤업
├── REQ-001_purchase-order-automation.md  # Epic
├── REQ-001-S01_po-creation-flow.md       # Story
├── REQ-001-S02_po-approval-flow.md       # Story
├── REQ-002_inventory-tracking.md         # Epic
└── REQ-002-S01_stock-movement.md         # Story
```

### 20~70, 99 — 문서별 폴더 구조

20.as_is_analysis, 21.system_landscape, 30~70, 99.requests는 **문서별 폴더** 구조를 사용한다.
마크다운 본문 외에 현행 엑셀 양식, 데이터 분석 파일, 스크린샷, HTML 프로토타입, 작업 문서 등을 함께 관리하기 위함이다.

```
20.as_is_analysis/
├── _overview.md
├── AS-001_import-procurement/           # 문서 폴더
│   ├── AS-001_import-procurement.md     # 본문 (필수)
│   ├── sources/                         # 실무자 원본 (읽기 전용 취급)
│   │   ├── po-master-tracker.xlsx       # 현행 PO 관리 엑셀
│   │   ├── shipping-schedule.xlsx       # 선적일정 엑셀
│   │   └── cost-calculation.xlsx        # 원가계산서
│   ├── analysis/                        # 분석 산출물 (데이터 모델, 마트 등)
│   │   ├── data-model-po-lifecycle.xlsx # 데이터 모델
│   │   └── po-volume-analysis.xlsx      # 볼륨 분석
│   └── screenshots/                     # 현행 시스템 스크린샷
│       └── serp-po-screen.png
└── AS-002_invoice-process/
    ├── AS-002_invoice-process.md
    ├── sources/
    │   └── invoice-form-template.xlsx
    └── analysis/
```

**규칙**:
- 폴더명 = 파일명에서 `.md` 제거한 것과 동일 (`AS-001_import-procurement/`)
- 폴더 내 본문 md 파일은 **폴더명과 동일** (`AS-001_import-procurement.md`)
- `_overview.md`는 phase 루트에 위치 (폴더 안이 아님)
- **`sources/`**: 실무자가 사용하는 원본 엑셀·양식. 읽기 전용 취급, 원본 보존
- **`analysis/`**: 원본에서 파생된 분석 산출물 (데이터 모델, 마트, 볼륨 분석 등)
- 첨부 파일은 자유 네이밍, 용도가 명확한 이름 사용
- 하나의 파일이 여러 AS 영역에 관련될 경우, 원본은 한 곳에 두고 다른 AS에서 상대경로로 참조 (`../AS-001_xxx/sources/파일명`)
- Fact Register에서 `analysis/` 파일을 소스로 걸면 `proposed → verified` 근거 체인 완성

### 21.system_landscape — 시스템 현황 + 정보 구조(IA)/메뉴

기존 시스템의 **인벤토리(시스템 프로필)와 내부 IA(메뉴·화면)**를 관리하는 **전 phase 공통 참조** 문서.
- *시스템 프로필*: 시스템 목적·벤더·연동 관계 (시스템 *간* 정보)
- *IA (Information Architecture)*: 메뉴 트리, 화면 인벤토리, 역할 가시성 (시스템 *내* 정보)

AS 문서가 화면 단위(`SCR-*`)로 ref하고, 마이그레이션(MIG)이 화면 cutover 단위로 계획한다.

```
21.system_landscape/
├── _overview.md                          # 시스템 인벤토리 + IA 작성률
├── SYS-001_serp/
│   ├── SYS-001_serp.md                   # 시스템 프로필 (개요, 연동 등)
│   ├── ia/                               # ★ 정보 구조 / 메뉴
│   │   ├── _overview.md                  # IA 요약 + 다른 phase 참조
│   │   ├── menu-tree.md                  # 메뉴 위계 (마크다운 들여쓰기 + mermaid 요약)
│   │   ├── menu-tree.mmd                 # 단독 소스 (mmdc 빌드용)
│   │   ├── screens.md                    # 화면 인벤토리 표
│   │   ├── role-visibility.md            # 역할별 메뉴 가시성 매트릭스
│   │   ├── screens/                      # (옵션) 핵심 화면만 단독 파일
│   │   │   └── SCR-PO-001_po-create.md
│   │   └── rendered/
│   └── screenshots/                      # 시스템 화면 캡처 (ia/screens.md에서 참조)
├── SYS-002_kakao-work/
│   ├── SYS-002_kakao-work.md
│   └── ia/                               # IA가 단순한 시스템은 menu-tree.md 1개로 끝
│       └── menu-tree.md
└── SYS-004_excel-ssot/
    ├── SYS-004_excel-ssot.md
    ├── ia/                               # 엑셀에도 IA 적용 (시트 = 메뉴 노드)
    │   ├── sheet-tree.md                 # 시트 트리
    │   ├── columns-inventory.md          # 시트별 컬럼 인벤토리
    │   └── role-visibility.md            # 시트 권한
    └── po-bl-master.xlsx
```

#### 산출물 4종 (IA)

| 파일 | 내용 | 시각화 |
|---|---|---|
| `menu-tree.md` | 메뉴 위계 (L1~L3) | 마크다운 들여쓰기(상세) + Mermaid `graph TD`(L1 요약) |
| `screens.md` | 화면 인벤토리 표 | 표 (메뉴 leaf ↔ 화면 매핑) |
| `role-visibility.md` | 역할 × 메뉴 가시성 매트릭스 | 표 (R / RW / —) |
| `_overview.md` | IA 요약 + 다른 phase 참조 | 메뉴 수, 화면 수, 역할 수, as_of |

#### IA 작성 규칙

- **AS-IS 중심, 단 partial 가동 시스템은 21이 살아있는 정본**: 21의 ia/는 *현행* 시스템. 신규 시스템도 *가동된 영역*은 21에 baseline으로 기록 (lifecycle_stage 룰 참조)
- **시각화**: 메뉴 수가 많아 mindmap 한계 → 마크다운 들여쓰기(검색·diff 친화) + Mermaid `graph TD` L1 요약 병행. mindmap 사용 안 함
- **화면 단독 파일**: 핵심 화면만 `screens/SCR-*.md` (스크린샷·필드 명세). 나머지는 `screens.md` 표에 인벤토리만
- **계층**: L1 (탑메뉴 5~9개), L2 (모듈 상세), L3 (화면 단위, 필요 시)
- **시스템 종류별 유연 적용**: ERP는 메뉴+화면 풀세트, Excel은 시트+컬럼, 알림 도구는 단일 트리만
- **as_of + system_version 명시**: 시스템 패치 시점 추적
- **노드별 status 표시**: screens.md / menu-tree.md의 각 노드에 `live` / `in_dev` / `planned` / `deprecated` 마킹 (partial·deprecated 시스템 필수)

#### 시스템 라이프사이클 (★ 핵심 룰)

시스템은 시간에 따라 21과 41 사이를 이동한다. 4단계로 명시:

| 단계 | 21 위치 | 41 위치 | 의미 | 예시 |
|---|:---:|:---:|---|---|
| **planning** | — | TO-BE 사이트맵 | 계획만, 가동 X | 신규 도입 검토 단계 |
| **partial** | IA 등록 (노드별 status 명시) | TO-BE 마스터플랜 유지 | 일부 가동 + 개발/계획 공존 | 단계적 cutover 진행 중인 신 시스템 |
| **live** | IA (모두 `live`) | (정리 또는 차기 개선의 출발점) | 완전 가동, 안정 | 운영 중인 안정 시스템 |
| **deprecated** | IA (모두 `deprecated`) | — | 폐기 예정, cutover 대상 | 신 시스템으로 교체될 레거시 |

**원칙**:
- 한 시스템은 **항상 정확히 한 단계**에 위치
- 단계 전이는 명시적으로 — `lifecycle_stage` 변경 + `change_log` 기록
- `partial` 단계가 가장 까다로움: **노드별로 가동 상태가 섞임** → `screens.md` status 컬럼·`menu-tree.md` 노드 마킹 필수
- `partial → live` 전이: 모든 노드가 `live`가 되면 41 _sitemap 정리 (또는 차기 개선 baseline로 보존)
- `deprecated`라도 21에서 *제거하지 않음* (cutover 추적 위해 유지)

#### SYS frontmatter `ia` 섹션 확장 (lifecycle 추가)

```yaml
ia:
  menu_tree_levels: 3
  total_menus: 47
  total_screens: 73
  screens_inventoried: 73
  screens_detailed: 12
  roles_count: 5
  as_of: 2026-04-25
  system_version: "4.5.2"
  lifecycle_stage: partial          # planning | partial | live | deprecated
  go_live_progress: 35              # partial 단계일 때만, % (live 노드 / 전체 노드)
  status_breakdown:                 # 자동 롤업
    live: 25
    in_dev: 18
    planned: 30
    deprecated: 0
```

#### SYS 본문 frontmatter `ia` 섹션

```yaml
ia:
  menu_tree_levels: 3              # L1/L2/L3 깊이
  total_menus: 47                  # 메뉴 노드 수
  total_screens: 73                # 화면 수
  screens_inventoried: 73          # screens.md에 등록된 수
  screens_detailed: 12             # SCR-*.md 단독 파일 수
  roles_count: 5                   # 가시성 매트릭스 역할 수
  as_of: 2026-04-25                # IA 스냅샷 시점
  system_version: "sERP 4.5.2"     # 관찰 대상 시스템 버전
```

#### AS-IS → TO-BE 화면 매핑 + Cutover 진척 대시보드 (`41.ui_design/_sitemap/mapping.md`)

AS-IS IA의 화면이 TO-BE로 어떻게 변하고, *현재 cutover 진척이 어디까지 왔는지* 추적하는 살아있는 표. **50.migration_plans의 화면 cutover 근거이자 진척률 단일 출처**.

```markdown
| AS-IS (21) | 변화 | TO-BE (21 또는 41) | 현재 상태 | 가동 일자 | MIG 단위 |
|---|:---:|---|:---:|---|:---:|
| SYS-001/SCR-PO-001 | ▶ 통합 | SYS-008/SCR-PO-001 | 🟢 cutover 완료 | 2026-03-15 | MIG-001-T01 |
| SYS-001/SCR-PO-002 | ▶ 통합 | SYS-008/SCR-PO-002 | 🟡 진행 중 | 2026-Q3 예정 | MIG-001-T02 |
| SYS-004/sheet-po-master | ▶ 통합 | SYS-008/SCR-PO-003 | ⚪ 미시작 | TBD | MIG-001-T03 |

## Cutover 진척
- 73개 AS-IS 화면 중 25개 cutover 완료 (34%)
- 진행 중 18개 / 미시작 30개
```

**원칙**:
- TO-BE 컬럼은 *시스템 + 화면 ID* (가동 후엔 41이 아닌 21의 화면 ID로 변경 — partial→live 전이)
- `현재 상태` = cutover 완료 / 진행 중 / 미시작 / 폐기. 노드 status와 1:1 매핑
- 이 표를 매주 갱신, 변경 시 `change_log` 기록
- WBS work_item.refs와 연결 (`refs: [mapping#SCR-PO-001]`)

#### 트리거 분기

- "시스템 메뉴 정리" / "IA 작성" / "메뉴 트리" → `21/SYS-nnn/ia/menu-tree.md`
- "화면 인벤토리" / "어떤 화면 있나" → `21/SYS-nnn/ia/screens.md`
- "역할별 가시성" / "권한 매트릭스" → `21/SYS-nnn/ia/role-visibility.md`
- "AS-IS TO-BE 메뉴 매핑" / "cutover 진척" / "마이그 진행 상황" → `41.ui_design/_sitemap/mapping.md`
- "이 시스템 가동됐어" / "live로 바꿔" / "lifecycle 갱신" → SYS frontmatter `lifecycle_stage` + 노드 status 갱신, mapping.md 진척 갱신
- "이 화면 cutover됐어" → mapping.md 해당 행 `현재 상태` → cutover 완료, `가동 일자` 입력, 21의 노드 status → live

### 22.access_control — RBAC 정책·운영·라이프사이클 (횡단 거버넌스)

각 시스템의 *내부* 메뉴-역할 가시성은 21에 두고, **횡단 정책·운영 audit·drift 검출·user 부여 추적**을 본 phase가 책임진다.

```
22.access_control/
├── _overview.md                              # RBAC 인벤토리 + 신호등 + 핵심 후속 과제
├── _shared/
│   ├── README.md                             # 작성 규약
│   ├── snapshot-template.sql                 # snapshots 생성용 SQL
│   ├── assignment-export-template.sql        # assignments 생성용 SQL
│   └── change-template.md                    # CHG-RBAC-* 본문 템플릿
├── policies/                                 # Role 정책 (정의·책임·SoD)
│   ├── _overview.md
│   ├── ROLE-001_super-admin.md
│   ├── ROLE-002_company-admin.md
│   ├── ROLE-003_master-integration-requester.md
│   └── ROLE-004_master-integration-approver.md
├── matrix/                                   # 횡단 매트릭스 (Role × 권한, Role × API, …)
│   ├── _overview.md
│   └── role-permission-matrix.md
├── snapshots/                                # 시점 baseline (분기/이벤트, 통계 + drift 위주)
│   ├── _overview.md
│   └── 2026-04-26_baseline.md
├── assignments/                              # 사용자 × Role 매트릭스 export (월간/이벤트, user-level 상세)
│   ├── _overview.md
│   └── 2026-04-26_user-roles.md
└── changes/                                  # 변경 이력 (이벤트 기반)
    ├── _overview.md
    ├── CHG-RBAC-001_phase-a-launch.md
    └── CHG-RBAC-002_revoke-temporary-super-admins.md
```

#### sub_phase 책임 분리

| sub_phase | 정본 영역 | 갱신 빈도 | 핵심 차이 |
|---|---|---|---|
| `policies/ROLE-*` | Role 정의 (책임·scope·금지·만료 정책) | 변경 시 (Role 신설/삭제 드물다) | "이 Role은 무엇이고 어떻게 부여하나" |
| `matrix/role-permission-matrix.md` | Role × Permission 매핑 정본 | 권한 매핑 변경 시 (CHG-RBAC-* 동반) | "어느 Role이 어느 권한 가지나" |
| `snapshots/YYYY-MM-DD_baseline.md` | 시점 통계 + drift 목록 | 분기 또는 마일스톤 시 | "이 시점 RBAC 상태 + 발견된 drift" |
| `assignments/YYYY-MM-DD_user-roles.md` | 사용자 × Role 매트릭스 시점 export | 월간 또는 RBAC 변경 직후 | "이 시점 누가 어떤 Role 가지고 있나" |
| `changes/CHG-RBAC-*` | 변경 1건 (사유·영향·검증·관련 마이그) | 이벤트 발생 시 1건 1파일 | "왜 바뀌었나, 무엇이 영향받나" |

#### 정본 우선순위

1. **DB가 진짜 정본** (`som.platform_roles`, `som.platform_permissions`, `som.platform_role_permissions`, `som.platform_user_roles`, `som.platform_menu_items.permission_code`, `som.user_visible_menus` VIEW). 마이그 파일이 코드 정본.
2. 22 phase 문서는 **그 거울**. drift 발생 시 *DB가 옳다 → 문서 갱신*.
3. user-level 부여는 분 단위 변동 → assignments는 *시점 캡처*. 라이브 view는 Phase B Matrix GUI(미구현)·DB 직접 조회.

#### 작성 규칙

- **assignments는 *수정 금지·신규 추가만***: 기존 export 파일 수정 X, 새 시점에는 새 파일 (`YYYY-MM-DD_user-roles.md`). 시점 보존.
- **모든 변경은 `changes/CHG-RBAC-NNN`을 거친다** (인시던트성 변경 포함). 사유·영향·검증·관련 마이그·다음 baseline 영향을 추적성으로 남김.
- **사용자 부여 자체는 인사·운영 영역** — 22는 *결과*만 audit. 부여를 *결정*하지 않는다.
- **`_overview.md`의 통계는 baseline 또는 최신 assignments에서 가져옴** — 직접 카운트 입력 금지 (drift 유발).

#### cross-ref

| 본 phase 문서 | 다른 phase | 관계 |
|---|---|---|
| `policies/ROLE-*` | `10.requirements/REQ-*-S*` | 권한 요구사항이 Role 정책의 근거 |
| `policies/ROLE-*` | `40.implementation_plans/IMP-*` | seed 마이그·구현이 Role 정책의 산출물 |
| `matrix/role-permission-matrix.md` | `infrastructure/supabase/migrations/*.sql` | 마이그가 정본, matrix는 거울 |
| `21.system_landscape/SYS-*/ia/role-visibility.md` | `matrix/` | 시스템 *내* 가시성 ↔ 횡단 정책 cross-ref |
| `changes/CHG-RBAC-*` | (모든 마이그·seed) | Role 부여·회수·만료 audit 정본 |
| `assignments/` | `snapshots/` | snapshots는 통계, assignments는 user-level. 같은 시점에 함께 생성 가능 |

#### 트리거 분기

- "이 사람 무슨 Role 부여됐나" / "사용자별 권한" → DB 조회 (`som.platform_user_roles`) 또는 최신 `assignments/YYYY-MM-DD_user-roles.md`
- "이 시점에 누가 무슨 Role 가졌나" → `assignments/YYYY-MM-DD_user-roles.md` (시점 캡처)
- "RBAC 현재 상태가 어떤가" / "전체 인벤토리" → `_overview.md` → `snapshots/`
- "Role × 권한 매트릭스" / "이 Role이 무엇 할 수 있나" → `matrix/role-permission-matrix.md` + `policies/ROLE-*`
- "왜 이렇게 바뀌었나" / "Role 부여 사유" → `changes/CHG-RBAC-*`
- "drift 발견했어" / "임시 SUPER_ADMIN" → 새 `changes/CHG-RBAC-NNN_*` 생성 → 마이그 동반 → 다음 snapshot/assignments에 반영
- "이번 달 부여 현황 export 해줘" → `_shared/assignment-export-template.sql` 실행 → 새 `assignments/YYYY-MM-DD_user-roles.md` 작성

### 41.ui_design — 화면·UI/UX 설계

IMP의 기술 설계를 **시각 설계**로 구체화한다. 정보 구조(IA) → 화면 플로우 → 개별 와이어프레임·HTML 프로토타입 3계층을 유지한다.

```
41.ui_design/
├── _overview.md                             # 신호등 + HTML 프로토타입 작성률
├── _shared/                                 # 전 UX 공통 자산·규약
│   ├── README.md                            # HTML 프로토타입 규약 (필독)
│   ├── shell-desktop.html                   # 데스크탑 shell 샘플
│   ├── shell-mobile.html                    # 모바일 shell 샘플
│   └── tokens.css                           # 색상/간격 토큰
├── _sitemap/                                # 프로젝트 전체 사이트맵
│   ├── sitemap.md                           # 메뉴 트리 본문
│   └── sitemap.html                         # 클릭 가능한 사이트맵
└── UX-001_good-receipts-pipeline/
    ├── UX-001_good-receipts-pipeline.md     # 본문 (IA + 플로우 + 화면 목록)
    ├── flow.md                              # Mermaid 플로우 상세 (선택)
    ├── as-is/                               # 현행 UI 프로토타입 (필수. 신규 개발 시 생략)
    │   ├── index.html
    │   ├── list.html
    │   └── NO_AS_IS.md                      # 신규 개발일 때만 (as-is 디렉토리 대신)
    └── to-be/                               # 개선 UI 프로토타입
        ├── index.html
        ├── list.html
        └── detail.html
```

**규칙**:
- `_shared/`는 모든 UX 문서가 공통 참조. HTML은 Tailwind CDN + 바닐라 JS로 **서버 없이 `file://` 열람** 가능해야 함
- 각 HTML 상단에 `AS-IS` (빨간색) / `TO-BE` (파란색) 변종 배너 필수
- AS-IS HTML은 **기존 구현이 있는 REQ에 필수**. 신규 개발(구현 없음)은 `as-is/NO_AS_IS.md` 한 줄 메모로 생략 가능
- 각 HTML 300줄 이내. 외부 API 호출 금지 (CDN 링크만 허용)
- **drift 허용**: HTML은 approved 시점 스냅샷. 구현 drift가 생기면 UX 문서를 재승인으로 정정
- UG와 UAT는 UX의 하류로, UG의 `upstream_refs`는 `[IMP-nnn, UX-nnn]` 둘 다 유지 (기술 근거 + 화면 근거)

### 41 `_overview.md` 확장

일반 대시보드에 더해 **HTML 프로토타입 작성률**을 표시:

```markdown
## HTML 프로토타입 작성률

| UX ID | 화면 수 | AS-IS HTML | TO-BE HTML | 작성률 |
|-------|:------:|:----------:|:----------:|:------:|
| UX-001 | 5 | 5/5 | 5/5 | 100% |
| UX-002 | 3 | — (NO_AS_IS) | 2/3 | 67% |
```

상세 템플릿 및 HTML 규약은 `references/templates.md` 참조.

### 42.flowchart_data — 데이터 흐름도 / 43.flowchart_workflow — 워크플로우 흐름도

두 phase는 **동일한 폴더 구조와 작성 패턴**을 사용한다. 차이는 관점·독자·계층 정의뿐.

#### 핵심 원칙

| 항목 | 규칙 |
|---|---|
| **시각화 도구** | Mermaid (텍스트 기반, git diff 친화) |
| **계층 구조** | L1 → L2 → L3 drill-down |
| **노드 수 제한** | 한 다이어그램 최대 9개 노드 (7±2 원칙). 초과 시 하위 레벨로 분할 |
| **AS-IS/TO-BE** | 항상 쌍으로 작성. 신규 개발 시에만 `NO_AS_IS.md`로 생략 가능 |
| **Diff** | 모든 다이어그램 쌍에 대해 `diff.md` 작성 (추가/제거/변경/유지 노드 명시) |
| **렌더링 호환** | 마크다운 뷰어·PDF 양쪽 지원 — `references/flowchart-rendering-guide.md` 준수 |

#### 계층 정의 — phase별 차이

| 레벨 | flowchart_data (42) | flowchart_workflow (43) |
|---|---|---|
| **L1** | 시스템 랜드스케이프 (전사 시스템 간 데이터 흐름) | 밸류체인 (전사 메가 프로세스 흐름) |
| **L2** | 도메인 데이터 모델 (도메인 내 데이터 객체 흐름) | 부서/도메인 워크플로우 (액터별 업무 흐름) |
| **L3** | 함수/API 흐름 (단일 처리의 데이터 변환 단계) | 작업 단계 (화면 조작 수준의 step-by-step) |

#### 폴더 구조

```
42.flowchart_data/                    # (43.flowchart_workflow도 동일 구조)
├── _overview.md                      # 인덱스 + 작성률 + 변경 핵심 롤업
├── _shared/                          # 공통 자산
│   ├── README.md                     # Mermaid 작성 규약 (필독)
│   ├── classes.mmd                   # 공통 classDef (system/actor/data/process/added/removed/modified)
│   └── legend.md                     # 색상·도형 범례
├── L1_<id>_<주제>/                  # 최상위 (1~2장)
│   └── FCD-L1-001_system-landscape/
│       ├── FCD-L1-001_system-landscape.md   # 본문 (frontmatter + 다이어그램 임베드 + diff 요약)
│       ├── as-is.mmd                         # AS-IS 단독 소스
│       ├── to-be.mmd                         # TO-BE 단독 소스
│       ├── diff.md                           # 변경 노드 명세
│       └── rendered/                         # (선택) mmdc 빌드 캐시
│           ├── as-is.svg
│           └── to-be.svg
├── L2_<id>_<도메인>/                # 도메인별 (5~10장)
│   ├── FCD-L2-001_procurement-data/
│   │   └── (L1과 동일 구조)
│   └── FCD-L2-002_inventory-data/
└── L3_<id>_<프로세스>/              # 프로세스 상세 (필요한 것만)
    └── FCD-L3-001_po-creation-api/
        └── (L1과 동일 구조)
```

**규칙**:
- 본문 `.md`에는 frontmatter + **다이어그램 의도** + `as-is`/`to-be` Mermaid 코드블록 임베드 + diff 요약 + drill-down 링크 포함
- `.mmd` 단독 파일은 mmdc 빌드용 (옵션). 본문에 임베드된 코드블록과 동일 내용 유지
- `_shared/classes.mmd`의 `%%{init}%%`와 classDef를 모든 다이어그램에 사용
- L1 다이어그램의 박스 = L2 다이어그램의 제목 (drill-down 매핑)
- 계층 간 노드명·색상·방향(TD/LR) 일관

#### `_overview.md` 확장 (작성률 + 변경 핵심)

```markdown
## 다이어그램 작성률

| ID | 레벨 | 주제 | AS-IS | TO-BE | Diff | 노드 수 |
|---|:---:|---|:---:|:---:|:---:|:---:|
| FCD-L1-001 | L1 | system-landscape | ✓ | ✓ | ✓ | 7 |
| FCD-L2-001 | L2 | procurement-data | ✓ | ✓ | ✓ | 8 |
| FCD-L2-002 | L2 | inventory-data | ✓ | — | — | — |

## 변경 핵심 롤업

L1: SSOT 단일화 (Excel→Odoo), 실시간 동기 (배치→Webhook)
L2-001 procurement: PO 마스터 이전, BL 자동 매칭
```

#### 트리거 분기

- "데이터 흐름 그려줘" / "DFD" / "시스템 간 흐름" → `42.flowchart_data`
- "업무 흐름 그려줘" / "워크플로우 다이어그램" / "프로세스 흐름" → `43.flowchart_workflow`
- "AS-IS와 TO-BE 비교" → 양 phase 모두에서 `as-is/to-be/diff` 패턴 적용

상세 Mermaid 템플릿·렌더링 가이드는 `references/templates.md`, `references/flowchart-rendering-guide.md` 참조.

### 80.project_management — WBS / 타임라인

프로젝트의 **작업 분해(WBS)와 일정(타임라인)**을 통합 관리하는 phase. 다른 phase의 *작성 상태*가 아닌 **실행 진척률·일정의 단일 출처**.

향후 risk_register, stakeholder_register, resource_plan 등 PM 메타 산출물의 확장 카테고리.

#### 핵심 원칙

| 항목 | 규칙 |
|---|---|
| **WBS와 타임라인은 별도 디렉토리** | 본질이 다름 (트리 vs Gantt). `wbs/`, `timeline/` 분리 |
| **비교 차원** | AS-IS/TO-BE 아닌 **baseline / current / forecast** |
| **살아있는 문서** | 진척 갱신은 git commit만, baseline 잠금·마일스톤 도달 시 `snapshots/<date>_baseline.md` |
| **Story ≠ Task** | REQ Story와 WBS Task는 별개 단위. work_item.refs로 Story 역참조 (1 Story → N Task 가능) |
| **임계 경로** | Claude가 분석 보조, **사람이 최종 판정·gantt에 `crit` 마킹** |
| **진척률 단일 출처** | 다른 phase `_overview.md`는 작성 상태만, 실행 진척률은 80에서 가져옴 |

#### 폴더 구조

```
80.project_management/
├── _overview.md                           # WBS·TL 인덱스 + 마일스톤 상태 + 진척률
├── _shared/
│   ├── README.md                          # 작성 규약 (status값, baseline 잠금 절차)
│   ├── classes.mmd                        # status별 색상 (todo/doing/done/blocked/at_risk)
│   └── status-glossary.md                 # 상태값 정의
├── wbs/                                   # 작업 분해
│   ├── _overview.md
│   └── WBS-001_overall/
│       ├── WBS-001_overall.md             # 본문: 트리 임베드 + work_items 표 + refs
│       ├── tree.mmd                       # mindmap (또는 graph TD) 단독 소스
│       ├── snapshots/                     # baseline 잠금 (옵션)
│       │   └── 2026-04-25_baseline.md
│       └── rendered/
│           └── tree.svg
└── timeline/                              # 일정
    ├── _overview.md
    └── TL-001_overall/
        ├── TL-001_overall.md              # 본문: gantt 임베드 + 마일스톤 표 + 임계경로
        ├── gantt.mmd                      # Mermaid gantt 단독 소스
        ├── milestones.md                  # 마일스톤 정의 (MS-001 ~ MS-nnn)
        ├── snapshots/
        │   └── 2026-04-25_baseline.md
        └── rendered/
            └── gantt.svg
```

#### 계층 (flowchart 패턴 일관)

| 레벨 | WBS | 타임라인 |
|---|---|---|
| **L1** | 프로젝트 전체 트리 (페이즈/모듈 수준) | 전체 일정 (분기/년 단위) |
| **L2** | 페이즈/이터레이션 분해 | 분기/시즌별 일정 |
| **L3** | 작업 단위 상세 (필요 시) | 주/일 단위 상세 (필요 시) |

L1은 1장, L2는 필요 시 분할, L3는 매우 큰 프로젝트만.

#### work_item 필수 필드

WBS 본문에 work_items 표 + frontmatter 둘 다 유지:

```yaml
work_items:
  - id: WBS-001-T01
    title: Odoo PO 모델 설계
    refs: [REQ-001-S01, IMP-001]      # Story·구현계획 등 다른 phase 역참조
    owner: "@hongjoo"
    estimate: 3d
    actual: 3.5d                       # in_progress면 null
    status: done                       # todo | doing | done | blocked
    started_at: 2026-04-10
    completed_at: 2026-04-13
    blocked_reason: null
```

#### milestone 필수 필드

타임라인 frontmatter:

```yaml
milestones:
  - id: MS-001
    title: 설계 완료
    target_date: 2026-05-15
    actual_date: null                  # 도달 시 입력
    epic_refs: [REQ-001, REQ-002]      # 이 마일스톤 = 어느 Epic 완료 의미
    status: on_track                   # on_track | at_risk | delayed | done
    note: ""
```

#### 비교 차원 — baseline / current / forecast

| 차원 | 의미 | 변경 패턴 |
|---|---|---|
| **baseline** | 합의된 계획 | 한 번 잠그면 가급적 고정. 변경은 CHG 거쳐 새 baseline |
| **current** | 현재 진척 | 매주~매일 갱신 (status, actual 입력) |
| **forecast** | 남은 작업 예상 | current 기반 재추정 |

baseline 보관: 잠금 시점 `snapshots/<YYYY-MM-DD>_baseline.md` 복사. 일상 갱신은 git만.

#### 진척률 단일 출처 룰

- 다른 phase의 `_overview.md`: **작성 상태**만 표시 (🔴 미착수, 🟡 draft, 🔵 reviewed, 🟢 approved, ⚫ deprecated)
- `80.project_management`의 `_overview.md`: **실행 진척률** (work_items의 status별 집계, 마일스톤 달성률)
- 프로젝트 루트 `_dashboard.md`: 양쪽 모두 표시 (작성 진척 + 실행 진척 + 마일스톤 상태)

#### 임계 경로 (critical path)

1. Claude가 매 갱신 시 `gantt` 의존성·기간 분석 보조
2. 사람이 검토 후 mermaid gantt에 `crit` 클래스로 마킹:
   ```
   PO 모델 설계   :crit, done, t01, 2026-04-10, 3d
   ```
3. `crit` 작업이 지연되면 마일스톤 status를 `at_risk`로 자동 갱신 권고

#### `_overview.md` 확장

```markdown
## 작업 진척률

| WBS | 총 work item | done | doing | todo | blocked | 진척률 |
|---|:---:|:---:|:---:|:---:|:---:|:---:|
| WBS-001 | 32 | 12 | 5 | 14 | 1 | 38% |

## 마일스톤 상태

| MS | 제목 | 목표일 | 상태 | 잔여 일수 |
|---|---|---|:---:|:---:|
| MS-001 | 설계 완료 | 2026-05-15 | 🟡 on_track | 20 |
| MS-002 | 구현 완료 | 2026-07-31 | 🔴 at_risk | 97 |

## 변경 이력

- 2026-04-25: WBS-001 baseline 잠금
- 2026-05-01: CHG-001로 인한 WBS-001-T05 추가
```

#### 트리거 분기

- "WBS 만들어줘" / "작업 분해" / "task 분해" → `80.project_management/wbs/`
- "타임라인 그려줘" / "Gantt" / "일정 짜줘" / "마일스톤 정리" → `80.project_management/timeline/`
- "진척률" / "지금 얼마나 됐어" → `80.project_management/_overview.md` 갱신·조회
- "baseline 잠그자" → 현재 시점 `snapshots/<date>_baseline.md` 생성

상세 템플릿·Mermaid 가이드는 `references/templates.md`, `references/flowchart-rendering-guide.md` (mindmap·gantt 섹션) 참조.

---

## _overview.md 대시보드 규칙

각 폴더의 `_overview.md`는 해당 phase의 **시각적 대시보드** 역할을 한다.

### 신호등 상태 표기

| 아이콘 | 상태 | 의미 |
|--------|------|------|
| 🔴 | — | 미착수 (해당 phase 문서 없음) |
| 🟡 | draft | 작성 중 / 초안 |
| 🔵 | reviewed | 리뷰 완료 (승인 대기) |
| 🟢 | approved | 승인 완료 |
| ⚫ | deprecated | 폐기 |

### Phase별 _overview.md 구조

```markdown
---
phase: {phase_name}
project: som-integrated-erp
updated_at: 2026-04-14
---

# {Phase 한국어명} Overview

## 📊 대시보드

| 🟢 approved | 🔵 reviewed | 🟡 draft | 🔴 미착수 | 합계 |
|:-----------:|:-----------:|:--------:|:---------:|:----:|
| 0 | 0 | 3 | 0 | 3 |

**진척률**: ██░░░░░░░░ 0% (approved 기준)

## 문서 목록

| 신호 | ID | 제목 | 상태 | 상류 | 하류 |
|:----:|----|------|------|------|------|
| 🟡 | REQ-001 | 구매주문 자동화 | draft | — | AS-001 |
| 🟡 | REQ-001-S01 | PO 생성 흐름 | draft | REQ-001 | AS-001 |

## 추적성 갭

하류 문서가 아직 작성되지 않은 항목:

| 신호 | 문서 ID | 미작성 하류 | 필요 행동 |
|:----:|---------|-----------|-----------|
| 🔴 | REQ-001 | TB (to_be) | 개선 방향 문서 작성 필요 |
```

### 프로젝트 전체 대시보드 (`_dashboard.md`)

프로젝트 루트에 `_dashboard.md`를 두어 **전 phase 현황을 한눈에** 파악한다.

```markdown
---
project: som-integrated-erp
updated_at: 2026-04-14
---

# 프로젝트 대시보드

## Phase별 현황

| 신호 | Phase | 문서 수 | approved | reviewed | draft | 진척률 |
|:----:|-------|:------:|:--------:|:--------:|:-----:|:-----:|
| 🟡 | 00 조직 | 5 | 0 | 0 | 5 | 0% |
| 🟡 | 01 워크플로우 | 21 | 0 | 0 | 21 | 0% |
| 🟡 | 10 요구사항 | 4 | 0 | 0 | 4 | 0% |
| 🟡 | 20 현황분석 | 1 | 0 | 0 | 1 | 0% |
| 🟡 | 21 시스템현황 | 4 | 0 | 0 | 4 | 0% |
| 🔴 | 30 개선방향 | 0 | — | — | — | — |
| 🔴 | 40 구현계획 | 0 | — | — | — | — |
| 🔴 | 41 UI설계 | 0 | — | — | — | — |
| 🔴 | 42 데이터 흐름도 | 0 | — | — | — | — |
| 🔴 | 43 워크플로우 흐름도 | 0 | — | — | — | — |
| 🔴 | 50 마이그레이션 | 0 | — | — | — | — |
| 🔴 | 60 사용자가이드 | 0 | — | — | — | — |
| 🔴 | 70 인수테스트 | 0 | — | — | — | — |
| 🔴 | 80 프로젝트관리 (WBS/TL) | 0 | — | — | — | — |
| 🔴 | 99 요청관리 | 0 | — | — | — | — |

## 실행 진척 + 마일스톤 (80에서 가져옴)

| WBS | 진척률 | done | doing | todo | blocked |
|---|:---:|:---:|:---:|:---:|:---:|
| WBS-001 | 38% | 12 | 5 | 14 | 1 |

| MS | 제목 | 목표일 | 상태 |
|---|---|---|:---:|
| MS-001 | 설계 완료 | 2026-05-15 | 🟡 on_track |
| MS-002 | 구현 완료 | 2026-07-31 | 🔴 at_risk |

**전체 진척률**: ██░░░░░░░░ 0%
```

### 신호등 산정 규칙

Phase 신호등은 해당 phase 내 문서의 **최저 상태**로 결정한다:
- 문서 전부 approved → 🟢
- 하나라도 reviewed (나머지 approved) → 🔵
- 하나라도 draft → 🟡
- 문서 0건 → 🔴

진척률 = `approved 건수 / 전체 건수 × 100%`
프로그레스 바: `█` = 10% 단위 (10칸 기준)

**롤업 시점**: 해당 폴더에 문서를 추가·수정·삭제할 때마다 `_overview.md`를 갱신한다.
프로젝트 대시보드(`_dashboard.md`)는 `/project-lifecycle` 호출 시 또는 "프로젝트 현황" 요청 시 갱신한다.

---

## 문서 작성 워크플로우

### 1. 문서 생성

사용자가 특정 phase 문서 작성을 요청하면:

1. **phase 확인**: 어떤 폴더에 속하는지 판별
2. **ID 채번**: 해당 phase의 기존 문서를 읽어 다음 번호 결정
3. **상류 문서 확인**: 참조해야 할 상류 문서가 있는지 확인
4. **템플릿 적용**: `references/templates.md`의 해당 phase 템플릿 사용
5. **문서 작성**: frontmatter + 본문 작성
6. **overview 갱신**: 해당 폴더의 `_overview.md` 업데이트
7. **상류 문서 역참조**: 상류 문서의 `downstream_refs`에 새 문서 ID 추가

### 2. 문서 수정

1. 대상 문서 읽기
2. 수정 내용 반영
3. frontmatter의 `updated_at`, `status` 갱신
4. 변경 이유가 요청(CHG)이면 `change_log`에 기록
5. overview 갱신

### 3. 영향도 분석 (Impact Analysis)

요청(CHG) 또는 변경이 발생하면:

1. 변경 대상 문서 식별
2. 해당 문서의 `downstream_refs`를 따라 하류 문서 목록 수집
3. 영향받는 문서 목록을 트리 형태로 출력
4. 사용자에게 영향 범위 확인 후 수정 진행

```
CHG-001 "세금 필드 추가"
  → REQ-001 구매주문 자동화 (직접 영향)
    → AS-001 현행 PO 프로세스 (현황 재분석 필요)
      → TB-001 PO 개선방향 (방향 재검토)
        → IMP-001 구현계획 (설계 변경)
          → UG-001 사용자 가이드 (가이드 업데이트)
            → UAT-001 인수 테스트 (재검증)
```

### 4. Phase 현황 리포트

프로젝트 전체 현황을 요약할 때:

1. 각 phase 폴더의 `_overview.md`를 수집
2. phase별 문서 수, 상태 분포 집계
3. 미완료 추적성 링크(상류는 있으나 하류 미작성) 식별
4. 전체 요약 리포트 생성

---

## Frontmatter 스키마

모든 문서에 공통으로 사용하는 frontmatter:

```yaml
---
id: REQ-001                          # 문서 고유 ID
title: 구매주문 자동화                  # 문서 제목
phase: requirements                   # phase 식별자
project: som-integrated-erp           # 프로젝트명
status: draft                         # draft | reviewed | approved | deprecated
created_at: 2026-04-14
updated_at: 2026-04-14
author: ""                            # 작성자
upstream_refs:                        # 상류 참조 (이 문서의 근거)
  - AS-001
downstream_refs:                      # 하류 참조 (이 문서에 의존하는 문서)
  - TB-001
  - TB-002
tags:                                 # 조직/워크플로우 태깅
  - org: division-a
  - workflow: WF-001
change_log:                           # 요청에 의한 변경 이력
  - date: 2026-04-14
    request_id: CHG-001
    description: "세금 필드 추가 반영"
---
```

### Phase별 추가 frontmatter

**requirements (Epic)**:
```yaml
type: epic
stories:                              # 하위 Story ID 목록
  - REQ-001-S01
  - REQ-001-S02
priority: high                        # high | medium | low
```

**requirements (Story)**:
```yaml
type: story
parent_epic: REQ-001                  # 상위 Epic ID
```

**workflows**:
```yaml
level: 3                              # lv.1 ~ lv.5
parent_workflow: WF-002               # 상위 워크플로우 ID (lv.2 이상)
organization: division-a              # 소속 조직
```

**as_is_analysis**:
```yaml
screens_used:                         # 분석 대상 시스템 화면 목록 (시스템ID/화면ID)
  - SYS-001/SCR-PO-001
  - SYS-001/SCR-PO-003
  - SYS-004/sheet-po-master           # excel 시트도 동일 패턴
```

**system_landscape (SYS)**: 위 21 섹션의 `ia` 필드 참조

**user_acceptance_log**:
```yaml
test_result: pass                     # pass | fail | partial
tested_by: ""
tested_at: 2026-04-14
guide_ref: UG-001                     # 대상 사용자 가이드
```

**ui_design**:
```yaml
screens_total: 5                      # 이 UX 문서가 다루는 화면 수
screens_as_is_html: 5                 # AS-IS HTML 작성 완료 수 (신규 개발이면 null)
screens_to_be_html: 5                 # TO-BE HTML 작성 완료 수
has_as_is: true                       # false면 NO_AS_IS.md로 생략
```

**flowchart_data / flowchart_workflow**:
```yaml
level: L1                             # L1 | L2 | L3
parent_chart: FCD-L1-001              # 상위 레벨 다이어그램 ID (L2/L3만)
nodes_count_as_is: 7                  # AS-IS 노드 수 (가독성 검증용; 9 초과 시 분할 권고)
nodes_count_to_be: 8
has_as_is: true                       # false면 NO_AS_IS.md로 생략
diff_summary:                         # diff.md 자동 롤업
  added: 3
  removed: 2
  modified: 1
  kept: 4
```

**wbs (in project_management)**:
```yaml
as_of: 2026-04-25                     # 이 문서가 반영하는 시점
baseline_locked_at: 2026-04-25        # baseline 잠금 일자 (변경 시 새 snapshot)
level: L1                             # L1 | L2 | L3
parent_wbs: null                      # L2/L3는 상위 WBS ID
work_items:                           # 작업 단위 목록 (필수)
  - id: WBS-001-T01
    title: Odoo PO 모델 설계
    refs: [REQ-001-S01, IMP-001]
    owner: "@hongjoo"
    estimate: 3d
    actual: 3.5d
    status: done                      # todo | doing | done | blocked
    started_at: 2026-04-10
    completed_at: 2026-04-13
    blocked_reason: null
progress:                             # 자동 롤업
  total: 32
  done: 12
  doing: 5
  todo: 14
  blocked: 1
  percent: 38
```

**timeline (in project_management)**:
```yaml
as_of: 2026-04-25
baseline_locked_at: 2026-04-25
wbs_ref: WBS-001                      # 어느 WBS의 일정인가
level: L1
date_range:
  start: 2026-04-01
  end: 2026-09-30
milestones:
  - id: MS-001
    title: 설계 완료
    target_date: 2026-05-15
    actual_date: null
    epic_refs: [REQ-001, REQ-002]
    status: on_track                  # on_track | at_risk | delayed | done
    note: ""
critical_path: [WBS-001-T01, WBS-001-T05, WBS-001-T12]   # 사람이 마킹 (수동)
```

---

## 변경 이력 기록 패턴

요청(CHG)에 의해 문서가 수정될 때, 해당 문서의 frontmatter `change_log`에 추가하고, 본문 하단에도 이력 섹션을 유지한다:

```markdown
## 변경 이력

| 일자 | 요청 ID | 변경 내용 |
|------|---------|-----------|
| 2026-04-14 | CHG-001 | 세금 필드 추가 반영 — 요구사항 3.2절 수정 |
| 2026-04-10 | — | 최초 작성 |
```

---

## AS-IS 분석의 근거 체계 (Fact Register)

### 근거 유형

AS 문서의 모든 발견사항(Finding)은 **근거 유형**을 명시한다:

| 유형 | 태그 | 의미 | 예시 |
|------|------|------|------|
| **정성적 (Qualitative)** | `[Q]` | 인터뷰/관찰에서 나온 의견, 인식, 체감 | "입력이 번거롭다", "시간이 오래 걸린다" |
| **정량적 (Quantitative)** | `[F]` | 측정 가능한 수치, 시스템 데이터, 검증된 사실 | "월 평균 15건 오류", "처리 시간 30분/건" |
| **미확인 (Unverified)** | `[U]` | 언급되었으나 아직 사실 확인되지 않은 항목 | "월 결산 시 대체 처리한다고 함" |

### Fact Register 구조

각 AS 문서에 **Fact Register** 섹션을 포함한다. 이 섹션은 정량적으로 확인해야 할 항목을 추적한다.

```markdown
## Fact Register

| ID | 항목 | 현재 값 | 검증 상태 | 소스 | 확인일 |
|----|------|--------|:---------:|------|--------|
| F-001 | WMS-ERP 재고 오류율 | 2.7% (566품목 중 15개) | verified | SOM 시스템 현황_20251217.pdf | 2025-12-17 |
| F-002 | PO 월 평균 건수 | — | proposed | 무역팀 인터뷰 (추정 40~50건) | — |
| F-003 | 일평균 거래 금액 | — | proposed | 관리팀 인터뷰 (추정 1억+) | — |
| F-004 | 미착품 월결산 대체 프로세스 | — | unverified | AS-001 추가분석 #1 | — |
```

### 검증 상태 흐름

```
proposed → in_review → verified
                    → unverified (확인 불가/보류)
                    → rejected (사실과 다름)
```

| 상태 | 의미 |
|------|------|
| `proposed` | 확인이 필요하다고 제안된 항목 |
| `in_review` | 데이터 수집/확인 진행 중 |
| `verified` | 사실로 확인됨 (소스와 확인일 기록) |
| `unverified` | 확인 시도했으나 검증 불가 (보류) |
| `rejected` | 사실과 다른 것으로 판명 |

### Fact 제안 규칙

AS 문서 작성 시, 아래 영역에서 Fact 항목을 자동 제안한다:

1. **볼륨 데이터**: 건수, 금액, 품목 수, 사용자 수
2. **소요 시간**: 처리 시간, 리드타임, 대기 시간
3. **오류율**: 불일치 건수, 재작업 빈도, 누락률
4. **비용**: 인건비 환산, 기회비용, 직접 비용
5. **시스템 데이터**: 레코드 수, API 호출량, 동시 사용자

### Pain Point 근거 태깅

Pain Points 섹션의 각 항목에 근거 유형을 태깅한다:

```markdown
## Pain Points / 문제점

1. **엑셀 SSOT 의존** `[Q]`: PO/BL의 유일한 원본이 엑셀
   - 영향: 데이터 정합성, 업무 연속성
   - 빈도: 일상적
   - 근거: 무역팀 인터뷰 (2026-01-15)
   - Fact 필요: F-002 (PO 월 건수), F-005 (엑셀 동시 편집 충돌 빈도)

2. **WMS-ERP 재고 불일치** `[F]`: 566품목 중 15개 오차 (2.7%)
   - 영향: 재고 정확성
   - 빈도: 상시
   - 근거: SOM 시스템 현황_20251217.pdf (F-001)
```

### _overview.md에 Fact 진척률 표시

AS overview에 Fact Register 집계를 표시한다:

```markdown
### Fact 검증 현황

| verified | in_review | proposed | unverified | rejected | 합계 |
|:--------:|:---------:|:--------:|:----------:|:--------:|:----:|
| 5 | 2 | 12 | 1 | 0 | 20 |

**Fact 검증률**: ███░░░░░░░ 25%
```

---

## 조직 태깅

문서의 `tags.org` 필드로 사업부/조직을 태깅한다. 이를 통해:
- 특정 사업부에 해당하는 문서만 필터링
- 사업부별 phase 진행 현황 조회
- 크로스 사업부 영향도 분석

워크플로우 태깅(`tags.workflow`)도 동일한 방식으로 문서를 워크플로우에 연결한다.

---

## 명령 패턴

사용자 요청에 따른 행동 가이드:

| 사용자 요청 | 행동 |
|-------------|------|
| "요구사항 작성해줘" | phase=requirements, 상류 확인 후 Epic/Story 템플릿으로 작성 |
| "현황 분석 해줘" | phase=as_is_analysis, 관련 요구사항 참조하여 분석 문서 작성 |
| "개선 방향 정리해줘" | phase=to_be_directions, as-is 문서 참조하여 방향 문서 작성 |
| "구현 계획 세워줘" | phase=implementation_plans, to-be 집계하여 계획 수립 |
| "UI 설계" / "UX 설계" / "화면 설계" / "프로토타입 만들어줘" | phase=ui_design, IMP 기반 UX 문서 + AS-IS/TO-BE HTML 작성 |
| "데이터 흐름 그려줘" / "DFD" / "시스템 간 흐름" / "데이터 플로우" | phase=flowchart_data, 적정 레벨(L1~L3) 결정 후 AS-IS/TO-BE Mermaid + diff 작성 |
| "업무 흐름 그려줘" / "워크플로우 다이어그램" / "프로세스 흐름" | phase=flowchart_workflow, 적정 레벨 결정 후 AS-IS/TO-BE Mermaid + diff 작성 |
| "흐름도 PDF로" / "다이어그램 인쇄" | references/flowchart-rendering-guide.md 절차 따라 mmdc 빌드 또는 md-to-pdf 호출 |
| "WBS 만들어줘" / "작업 분해" / "task 분해" | phase=project_management/wbs, REQ Story 기반 work item 분해 + tree.mmd |
| "타임라인 그려줘" / "Gantt" / "일정 짜줘" | phase=project_management/timeline, WBS 기반 gantt + 마일스톤 |
| "마일스톤 정리" / "마일스톤 추가" | timeline frontmatter milestones 갱신 + _overview 롤업 |
| "진척률" / "지금 얼마나 됐어" / "현재 상태" | project_management/_overview.md 갱신·조회 (work_items 집계, 마일스톤 상태) |
| "baseline 잠그자" / "기준선 확정" | 현재 WBS·TL을 snapshots/<date>_baseline.md로 복사 + frontmatter `baseline_locked_at` 갱신 |
| "임계 경로" / "critical path" | gantt 의존성·기간 분석 보조, 사람과 합의 후 `crit` 클래스 마킹 + frontmatter `critical_path` 갱신 |
| "마이그레이션 계획" | phase=migration_plans, 구현 계획과 연계하여 이관 계획 |
| "사용자 가이드 작성" | phase=user_guide, 구현 단위 기반 가이드 구성 |
| "인수 테스트 기록" | phase=user_acceptance_log, 가이드 기반 검증 결과 기록 |
| "요청 등록" | phase=requests, CHG 문서 생성 후 영향도 분석 |
| "영향도 분석" | 대상 문서에서 하류 추적, 트리 출력 |
| "프로젝트 현황" | 전체 phase 롤업 리포트 생성 |
| "overview 갱신" | 지정 폴더 또는 전체 `_overview.md` 재생성 |

---

## 참조

- **문서 템플릿**: `references/templates.md` — 각 phase별 문서 템플릿 상세
- **흐름도 렌더링 가이드**: `references/flowchart-rendering-guide.md` — Mermaid 작성 규약, 마크다운 뷰어 호환, mmdc·md-to-pdf 빌드 절차
