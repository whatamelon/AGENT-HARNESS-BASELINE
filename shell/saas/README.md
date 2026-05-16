# SaaS 플러그인 디렉터리

`__load_project_secrets()` 훅이 cd마다 이 디렉터리의 모든 `*.sh` 를 자동으로 source + 호출.

## 인터페이스 규약

각 플러그인은 `__load_<saas_name>()` 함수 1개를 정의해야 함. 파일명과 동일.

예: `shell/saas/sentry.sh` → `__load_sentry()` 함수

`_lib.sh`의 헬퍼를 사용:

```bash
source "$HOME/.config/agent-harness-baseline/shell/saas/_lib.sh"

__load_<name>() {
  local map="$HOME/.config/projects/<name>.json"
  [[ -f "$map" ]] || return 0
  __is_saas_disabled <name> && return 0

  # 1) 마커 찾기 (.agent-harness-baseline.json 우선, 없으면 자동 탐색)
  local marker_file
  marker_file=$(__find_marker <name> "<default-marker-suffix>" 4)
  [[ -z "$marker_file" ]] && return 0

  # 2) 마커에서 ID 추출
  # 3) 매핑에서 op:// 참조 조회 → op read → export
  # 4) export한 변수명을 stdout으로 출력

  echo "VAR1 VAR2 VAR3"
}
```

## 마커 위치 결정 규칙

`__find_marker` 함수의 동작 우선순위:

1. **명시적 (C)**: 프로젝트 루트의 `.agent-harness-baseline.json` 안에 `saas.<plugin>.marker` 키가 있으면 그 경로 사용 (project-root 기준 상대경로)
2. **자동 탐색 (B)**: 프로젝트 루트에서 `-maxdepth N` 까지 `*<default-suffix>` 패턴으로 find. `node_modules`, `.git`, `dist`, `build` 디렉터리는 제외. 가장 얕은 경로 우선.

**프로젝트 루트 감지**: 현재 위치에서 위로 거슬러 올라가며 다음 중 하나가 있는 첫 디렉터리:
- `.git/` (가장 일반적)
- `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`
- `.agent-harness-baseline.json` (강제 지정용)

## .agent-harness-baseline.json 예시 (프로젝트별 옵션)

```json
{
  "saas": {
    "vercel": { "marker": "fe/.vercel/project.json" },
    "supabase": { "marker": "db/supabase/config.toml" },
    "sentry": { "disabled": true }
  }
}
```

이 파일은 git commit 안전 (op 참조도 시크릿도 안 들어감, 단지 경로/플래그만).

## 출력 약속

- **export한 변수명을 stdout으로 출력** — 훅이 다음 cd 때 unset할 수 있게 기록
- 빈 출력 = 이 디렉터리에선 적용 안 됨
- export 자체는 함수 내부에서 (서브셸 X)

## 새 SaaS 추가
```bash
saas-add <name>   # 인터랙티브로 자동 생성
```
또는 수동:
1. 이 디렉터리에 `<name>.sh` 작성
2. `~/.config/projects/<name>.json` 빈 매핑 생성
3. 1Password vault 항목 만들기
4. cd 테스트
