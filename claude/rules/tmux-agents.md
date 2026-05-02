# tmux 에이전트 팀 운영 규칙

## 핵심 규칙

> **tmux가 사용 가능한 환경이면, 에이전트 팀(team/swarm/dispatch)은 무조건 tmux로 실행한다.**

## 적용 범위

다중 에이전트가 동시에 일하는 모든 워크플로우:
- `/team`, `/oh-my-claudecode:team` (N 코디네이트 에이전트)
- `/oh-my-claudecode:omc-teams` (CLI 팀 워커)
- `/oh-my-claudecode:swarm` (N 워커 + 태스크 클레임)
- `/oh-my-claudecode:ultrawork`, `ultrapilot` (병렬 실행)
- `dispatch-agents` 스킬 (외부 리포 에이전트 디스패치)
- `project-session-manager`, `qa-tester` 류 (tmux 기반 인터랙티브)

## 판단 절차

1. **tmux 가용성 확인** (필수, 작업 시작 전):
   ```bash
   command -v tmux >/dev/null 2>&1 && echo OK
   ```
2. 가능하면 → **tmux 세션/팬으로 에이전트 분리** (각 에이전트 1팬)
3. 불가능한 경우에만 fallback:
   - (a) 컨테이너 격리
   - (b) 일반 Task tool + `run_in_background`

## 이유

- **실시간 가시성**: 각 에이전트 진행을 사용자가 attach 해서 직접 관찰 가능
- **세션 격리**: 작업 디렉토리/환경변수/프로세스 충돌 방지
- **디버깅**: 멈춘 에이전트에 사용자가 직접 들어가 점검 가능
- **본래 디자인**: ultrawork/team 계열은 tmux 기반으로 설계된 것이 정본

## How to apply

- 다중 에이전트 작업이 필요한 순간 → **첫 점검은 tmux 가용 여부**
- 가용하면 tmux 기반 스킬 우선 사용
- 단일 에이전트·1회성 위임은 룰 적용 대상 아님 (일반 Task로 OK)
- 사용자가 명시적으로 "Task로 해" 하면 그게 우선

## 위반 시

- tmux 가능한데 일반 Task로 다중 에이전트 돌렸으면 → 즉시 사용자에게 알리고 tmux 기반으로 재구성 제안
