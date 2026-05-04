# OMX 팀 모드 워커 역할 선정

## 핵심 규칙

> **`omx team` / `$team` / `/team` 등 팀 모드를 띄울 때, 무조건 `executor` 일괄 사용 금지. 작업 성격에 맞는 워커 에이전트 타입을 먼저 고민하고 명시해서 띄운다.**

기본 동작인 `omx team 4:executor` 는 모든 워커를 일반 executor 로 통일한다. 이는 동작은 하지만 (a) 검증·디자인·문서·보안 같은 전문 영역에서 효과가 떨어지고, (b) `omx team status` 출력에 나오는 `staffing_plan` 추천을 무시하는 결과가 된다.

## 적용 절차 (필수)

팀 모드 띄우기 직전 다음 순서를 지킨다.

### 1. 작업 분해 (lane 식별)

작업을 lane 단위로 쪼개고, 각 lane 의 성격을 한 단어로 라벨링한다.
- 구현(impl), 디자인/UI, 검증/테스트, 빌드 수정, 코드리뷰, 보안, 문서, 리서치, 분석, 탐색, 계획, 비평, 디버깅, 성능, 데이터/통계, 비전(이미지)

### 2. 사용 가능한 워커 역할 확인

`omx team --help` 또는 첫 launch 출력의 `available_agent_types` 라인 참조. 대표적으로:

| Lane 성격 | 우선 후보 역할 |
|---|---|
| 일반 구현 | `executor` |
| UI/디자인 | `designer` |
| 빌드 깨짐/타입 에러 | `build-fixer` |
| 단위/E2E 테스트 작성 | `test-engineer`, `qa-tester` |
| 검증·완료 게이트 | `verifier`, `quality-reviewer` |
| 코드 리뷰 | `code-reviewer`, `style-reviewer`, `api-reviewer` |
| 보안 점검 | `security-reviewer` |
| 문서 작성 | `writer`, `information-architect` |
| 리서치/외부 사실 | `researcher` |
| 코드 탐색·심볼 위치 | `explore`, `explore-harness` |
| 계획 수립 | `planner`, `architect` |
| 비평·갭 탐지 | `critic` |
| 디버깅·근본원인 | `debugger` |
| 성능 분석 | `performance-reviewer` |
| 데이터/통계/실험 | `scientist`, `product-analyst` |
| 이미지/스크린샷 분석 | `vision` |

### 3. staffing_plan 우선 존중

`omx team` 첫 launch 시 출력의 `staffing_plan: <role> x<n> (<reason>); ...` 라인은 OMX 가 추천하는 워커 구성이다. **특별한 이유가 없으면 이 추천을 따른다.** 기본 `4:executor` 로 띄웠더라도 staffing_plan 출력을 본 뒤 inbox 에 워커별 역할 행동지침을 명시하거나, 필요시 즉시 shutdown 후 추천 staffing 으로 재기동한다.

### 4. 명시적 역할 선언 (launch)

- 단일 역할 다수 워커: `omx team 3:test-engineer "regression coverage"` 처럼 명시
- 혼합 역할이 필요한 경우 (현재 `omx team` CLI 가 한 번에 한 role 만 받으므로):
  - 가장 비중 큰 역할로 launch (`omx team 4:executor` 대신 `omx team 4:designer` 등)
  - 그 후 워커별 inbox.md 에 lane 별 역할 행동지침을 적어 다른 lane 의 워커 행동을 유도
  - 또는 두 개 이상의 작은 팀을 나눠 띄우기 (예: `omx team 2:designer "UI"` + `omx team 2:test-engineer "QA"`)

### 5. 검증 lane 분리 (구현 lane 와 다른 워커가 맡는다)

구현/테스트는 같은 워커에 맡기지 않는다. 같은 워커가 자기 코드를 검증하면 사각지대가 생긴다. 최소 1명은 `verifier` / `qa-tester` / `test-engineer` 로 분리한다.

## How to apply

- 사용자가 "팀 모드", "병렬", "$team" 같은 트리거를 줬을 때 — 작업 분해 → role 후보 매핑 → staffing 결정 → 그제야 `omx team N:role "..."` 호출
- 사용자가 명시적으로 "executor 만 써" 라고 하면 그게 우선
- launch 후 `staffing_plan` 출력에 다른 추천이 나오면 사용자에게 한번 알리고 그대로 갈지/재기동할지 판단

## Why

- OMX 의 `available_agent_types` 는 30+ 개의 전문 역할을 제공하며 각 역할은 prompt/instruction 이 다르게 튜닝되어 있음. `executor` 는 만능이 아닌 *기본값*
- 잘못된 역할로 lane 을 맡기면 워커가 자기 lane 을 벗어나 다른 워커 영역 침범하거나(워커-1 가 hero 까지 짜는 식), 검증을 sloppy 하게 통과시키거나, 디자인 톤이 무너지는 패턴이 자주 관찰됨
- staffing_plan 은 OMX 가 task description 으로부터 자동 분석한 추천이므로 무시하면 가치 손실
