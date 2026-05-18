# AGENT-HARNESS-BASELINE · 개발환경 꾸쮹

두 맥북(개인/회사) 간 Claude Code + Codex + 셸 + 프로젝트 시크릿 + GUI 앱 설정을 git으로 동기화하는 SSOT.
**1Password 통합** + **launchd 자동 sync** + **휘황찬란한 mac-setup 마법사 (14단계)**.

## 새 맥북 한 줄 셋업

**기본(공장초기화) 맥엔 git·brew가 없다.** Homebrew 설치 한 줄이면 Command Line Tools(= `git`)까지 함께 깔리고, 나머지(`gh`·앱·셸·1Password CLI 등)는 부트스트랩이 자동 설치한다. repo가 **public**이라 clone에 인증 불필요. 공장초기화 → 완료까지 아래 한 줄:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
  git clone https://github.com/whatamelon/AGENT-HARNESS-BASELINE.git ~/.config/agent-harness-baseline && \
  bash ~/.config/agent-harness-baseline/bootstrap/bootstrap-new-mac.sh
```

> 중간에 macOS 암호·CLT 설치 동의가 한두 번 필요 (완전 무인은 아님).
> 이미 brew가 있으면 첫 줄은 "이미 설치됨"으로 건너뜀 (idempotent).
> 이미 git이 있으면 Homebrew 줄 생략하고 아래 clone 줄만 실행해도 됨:
>
> ```bash
> git clone https://github.com/whatamelon/AGENT-HARNESS-BASELINE.git ~/.config/agent-harness-baseline && \
>   bash ~/.config/agent-harness-baseline/bootstrap/bootstrap-new-mac.sh
> ```
>
> `gh` clone을 선호하면: `gh repo clone whatamelon/AGENT-HARNESS-BASELINE ~/.config/agent-harness-baseline`

또는 인터랙티브:
```bash
~/.config/agent-harness-baseline/bin/mac-setup.sh
```

마법사 모드:
- `mac-setup` — 인터랙티브 (모드 선택)
- `mac-setup auto` — 처음부터 끝까지 자동
- `mac-setup verify` — 검증만
- `mac-setup --step N` — 특정 단계 (1~14)
- `mac-setup reset` — 진행 상태 초기화

## 이 부트스트랩이 설치/설정하는 것 (15단계, 멱등)

| # | 단계 | 내용 |
|---|------|------|
| 1 | Xcode CLT | `git` 등 — 다이얼로그 동의 필요 |
| 1 | **머신 프로파일** | step 1 내 — 맥북/맥미니 선택. 맥미니면 풀 무인화(`mac-power-mode headless`) + Hermes Agent 자동 설치 |
| 2 | Rosetta | Apple Silicon만 (라이선스 자동 동의) |
| 3 | Homebrew | 없으면 설치 (이미 한 줄에서 깔았으면 스킵) |
| 4 | SSOT repo | clone 또는 `git pull` (public — 인증 불필요) |
| 5 | **Brewfile 일괄** | CLI: `node git gh tmux postgresql@16 python@3.11 uv pandoc poppler ffmpeg supabase vercel-cli` + zsh 플러그인 + 모던 CLI(`eza bat fd git-delta zoxide atuin fzf`) + `bats-core claude-squad` · Cask: `1password-cli claude codex cursor visual-studio-code docker-desktop gcloud-cli claude-usage-tracker` · VS Code 확장 13개 |
| 6 | 1Password CLI | `op` 설치 |
| 7 | **1Password 인증** | ★사람 액션 — 데스크톱 앱 CLI 연동 ON + `op signin` |
| 8 | install.sh | symlink + 셸(zsh) + git config 일괄 적용 |
| 9 | 시크릿 자동 주입 | 1Password vault → `settings.local.json`, supabase PAT 있으면 자동 login |
| 10 | npm globals | `bootstrap/npm-globals-names.txt` 일괄 |
| 11 | Bun | `bun.sh/install` |
| 12 | launchd | 자동 sync(30분) + daily-digest(매일 8시) + srcsht-rename watcher |
| 13 | 에디터 확장 | VS Code / Cursor extension 설치 |
| 13b | 공유 자산 | CC↔Codex 스킬 풀 + 글로벌 AGENTS.md 재생성 |
| 13c | Claude 플러그인 | OMC(oh-my-claudecode) + BMAD marketplace/plugin |
| 13d | **wishket 회사 정본** | `wishket-aidp/claude-settings` clone — ★여전히 private (gh 인증 + 접근 권한 필요, 없으면 글로벌 심링크 broken) |
| 13e | work-log harness | `whatamelon/agent-work-log-harness` clone + 심링크 |
| 14 | 검증 | `ahb-doctor` |
| 15 | 남은 로그인 안내 | 자동화 불가 OAuth 체크리스트 출력 |

## 맥미니 무인화 (`mac-power-mode`)

맥미니처럼 **항시가동·원격 접속용 헤드리스 박스**는 잠자기/화면잠금이 켜져 있으면
원격 접근이 끊기고 에이전트가 멈춘다. `mac-setup` step 1 의 **머신 프로파일**에서
`맥미니`를 고르면 자동 적용되며, 수동으로도 가능:

```bash
mac-power-mode headless   # 풀 무인화 적용
mac-power-mode laptop     # 노트북 안전 기본값으로 전부 복귀
mac-power-mode status     # 현재 전원/잠금/자동로그인/FileVault 상태
```

`headless` 가 굳히는 것 (모두 멱등·복구 가능):

| 항목 | 효과 |
|------|------|
| `pmset sleep/displaysleep/disksleep 0` | 시스템·디스플레이·디스크 잠자기 끔 |
| `pmset autorestart 1` | 정전 후 자동 재시작 |
| `pmset womp 1` | 네트워크로 원격 깨우기 |
| 화면보호기 `idleTime 0` + `askForPassword 0` | 콘솔 잠금 트리거 차단 |
| (선택) 자동 로그인 | 부팅 시 데스크톱 자동 진입 — **FileVault OFF + 명시 동의 시에만** |

> 자동 로그인은 콘솔 물리접근 시 무방비라 기본 **묻고 진행**(default N).
> FileVault 가 켜져 있으면 자동 스킵(부팅 시 디스크 잠금해제 암호가 필요).
> `machineType` 은 `.machine.json` 에 기록되고, `ahb-doctor` 가 무인화 머신의
> 전원 상태를 검증한다. 되돌리려면 `mac-power-mode laptop`.

### Hermes Agent (맥미니 자동 에이전트 런타임)

맥미니는 "파일 주고 채팅으로 자동사냥" 용 자동 에이전트 박스이므로,
`맥미니` 선택 시 무인화와 함께 **Hermes Agent**(NousResearch 공식 인스톨러)를
자동 설치한다. 멱등(이미 있으면 스킵), `uv` 없으면 인스톨러가 자체 부트스트랩.

- 설치: `curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash -s -- --skip-setup`
- 설치 위치: `~/.hermes`
- `--skip-setup` 이라 대화형 설정은 생략 — API 키/설정은 새 박스에서 한 번 `hermes setup`
- 맥북 프로파일에는 설치 안 함 (자동 박스 전용)

## 부트스트랩 전에 미리 준비해두면 좋은 것

이게 준비 안 되면 중간에 막히거나 일부가 자동으로 안 된다:

- **macOS 로그인 암호** — Homebrew/Rosetta 설치 시 `sudo` 요구
- **1Password 데스크톱 앱** — 설치 + 계정 로그인 + `Settings → Developer → Integrate with 1Password CLI` 토글 ON
  - 안 되어 있으면 **7단계에서 멈춤**, 시크릿 자동 주입(9단계) 스킵됨
- **1Password vault(Employee)에 있어야 자동화되는 항목**
  - `agent-harness-baseline-machine-env` — 없으면 `settings.local.json` 시크릿 주입 스킵 (수동 주입 필요)
  - `supabase-pat` — (선택) 있으면 supabase 자동 login, 없으면 나중에 수동
- **GitHub 계정 + 권한** — 13d의 `wishket-aidp/claude-settings`는 여전히 private. 이 org 접근 권한 있는 계정으로 `gh auth login` 안 하면 회사 정본 clone 실패 → 글로벌 심링크 다수 broken

## 부트스트랩 후 사람이 직접 해야 하는 로그인 (자동화 불가 OAuth)

부트스트랩 15단계가 끝에서 이 목록을 출력한다. 새 맥마다 한 번씩:

| 구분 | 명령 | 용도 |
|------|------|------|
| 필수 | `gh auth login` | GitHub (+ wishket private 정본 접근) |
| 필수 | `op signin` | 1Password (7단계에서 안 했다면) |
| 필수 | `claude` | Claude Code 첫 인증 |
| 필수 | `gws schema gmail.users.messages.list >/dev/null` | Google Workspace(Gmail/Drive/Sheets/Docs/Calendar) — 1회 OAuth, keyring 영구 |
| 프로젝트 | `vercel login` | Vercel |
| 프로젝트 | `supabase login --token "$(op read 'op://Employee/supabase-pat/credential')"` | Supabase (browser OAuth는 자주 실패 → PAT 권장) |
| 프로젝트 | `gcloud init` + `gcloud auth application-default login` | GCP 인프라 (Workspace는 `gws` 우선) |
| 프로젝트 | `firebase login` / `wrangler login` / `docker login` / `aws configure` | 해당 도구 쓸 때만 |
| 선택 | npm private registry / Android Studio·Xcode 라이선스 / macOS 권한(전체 디스크 접근·알림 허용) | 필요 시 |

> 상세 가이드·트러블슈팅·토큰 회전 주기: **[`bootstrap/cli-login-checklist.md`](bootstrap/cli-login-checklist.md)**

## 디렉터리 구조
```
~/.config/agent-harness-baseline/
├── claude/                     # → ~/.claude/{skills,agents,commands,rules,hooks,hud,CLAUDE.md,notify.sh}
├── shell/zshrc.shared          # ~/.zshrc 가 source. chpwd 훅 포함
├── shell/zprofile.shared       # ~/.zprofile 가 source. 백그라운드 git pull
├── shell/machines/             # hostname별 추가 셸 설정
├── git/gitconfig.shared        # ~/.gitconfig include
├── config/projects/            # → ~/.config/projects (Vercel/Supabase 매핑)
├── bin/                        # 헬퍼 스크립트
│   ├── install.sh              # symlink + 셸 + git config 한 방
│   ├── relink.sh               # 새 디렉터리 추가 시 재링크
│   ├── doctor.sh               # agent-harness-baseline 자체 검증
│   ├── bootstrap-doctor.sh     # 시스템 + CLI 인증 광범위 검증
│   ├── sync.sh                 # launchd가 호출 — pull → 자동 commit/push
│   ├── migrate-secrets-to-1password.sh  # 평문 토큰 → vault 이전
│   ├── project-init.sh         # 새 프로젝트 sync 등록
│   ├── ensure-project-layout.sh # docs/work-log/_template + fe/db/.project 보장
│   ├── ensure-work-log-task.sh  # docs/work-log/<task>/{context,plan,checklist}.md 생성
│   ├── env-sync.sh             # .env 재주입 (op inject)
│   ├── export-desktop.sh       # ★ GUI 앱 설정 → SSOT (개인맥에서)
│   ├── import-desktop.sh       # ★ SSOT → 새 머신 (op inject 거침)
│   ├── rebuild-agents-md.sh    # ★ ~/AGENTS.md 빌더 (Codex 글로벌)
│   └── codex-bridge.sh         # ★ Claude Code ↔ Codex 브리지
├── bootstrap/
│   ├── bootstrap-new-mac.sh    # ★ 한 줄 셋업 (비대화형)
│   ├── Brewfile                # brew 패키지 일괄
│   ├── npm-globals.txt         # npm 글로벌 패키지
│   ├── cli-login-checklist.md  # OAuth 안내
│   ├── install-shared-skills.sh # ~/.agents/skills 외부 풀 재구성
│   └── install-codex-skills.sh  # CC 전용 스킬 → Codex 노출
├── desktop/                    # ★ GUI 앱 설정 sync (iTerm/VS Code/Cursor/Claude Desktop)
│   ├── iterm2/                 # com.googlecode.iterm2.plist + DynamicProfiles
│   ├── vscode/                 # settings.json, keybindings.json, snippets/
│   ├── cursor/                 # 동일
│   └── claude-desktop/         # claude_desktop_config.tpl.json (op inject 대상)
├── agents/
│   └── skill-lock.json         # 외부 출처 157개 스킬 메타 (재구성용)
└── launchd/                    # 자동 sync plist
```

## 일상 alias (zshrc.shared 자동 등록)
| alias | 동작 |
|-------|------|
| `ahb` | SSOT로 cd |
| `ahb-sync` | pull + 변경분 자동 commit/push |
| `ahb-doctor` | 환경 검증 |
| `project-init [vault]` | 현재 디렉터리를 sync에 등록 |
| `env-sync` | 현재 디렉터리의 .env 재주입 |
| `secrets-migrate <vault>` | 평문 시크릿을 1Password로 이전 |

## 시크릿 모델 (3계층)
```
[1Password vault] ──── op read / op inject ────→ [디스크 평문 .env / settings.local.json]
        ↑                                                        ↑
        │                                                        │
   사람이 회전                                       Claude Code / 앱이 읽음
```
- 시크릿의 **유일한 SOT**는 1Password
- 디스크 평문은 캐시 (gitignore)
- 토큰 회전 = 1Password 항목 password 수정 + `env-sync` 또는 `op inject` 한 줄

## 자동 sync 흐름
1. **셸 시작 시** (~/.zprofile): 백그라운드 `git pull --rebase`
2. **30분마다** (launchd `com.denny.agent-harness-baseline`): `bin/sync.sh` 호출 → pull → 변경 있으면 자동 commit + push
3. **수동**: `ahb-sync` alias

## CC ↔ Codex 통합

`~/.config/agent-harness-baseline` (AGENT-HARNESS-BASELINE) 가 Claude Code와 Codex 양 도구의 단일 진실 원천(SSOT). 양쪽이 동일한 **스킬 풀**, **글로벌 컨벤션(`~/AGENTS.md`)**, **Codex custom agents/hooks/memories**를 공유한다.

### 자산 출처
| 자산 | 위치 | 출처 |
|------|------|------|
| 외부 스킬 | `~/.agents/skills/` | `agents/skill-lock.json` 기준 GitHub sources |
| Claude slash commands | `claude/commands/*.md` → `~/.agents/skills/*/SKILL.md` | `codex-bridge.sh`가 Codex skill로 생성 |
| CC 전용 스킬 | `claude/skills/*` | 사용자/회사 SSOT |
| Codex custom agents | `codex/agents/` → `~/.codex/agents` | Claude subagent에서 변환, git sync |
| Codex hooks | `codex/hooks.json`, `codex/hooks/` → `~/.codex/*` | Stop hook에서 bridge 실행 |
| Codex memories | `codex/memories/` → `~/.codex/memories` | Claude project memory에서 생성, git sync |
| 글로벌 규칙 | `claude/rules/*.md` | 양 도구 공유 |
| 사용자 메모리 인덱스 | `~/.claude/projects/.../memory/MEMORY.md` | CC 자동 누적 |

### `~/AGENTS.md` 자동 갱신
1. **PostToolUse hook**: CC가 rules/MEMORY 수정 시 즉시 빌드
2. **Stop hook**: Claude Code와 Codex 모두 `codex-bridge.sh` 실행
3. **launchd sync**: 30분마다 `sync.sh` 실행 → git pull 후 `codex-bridge.sh` 자동 실행
4. **bootstrap/mac-setup**: 신규 머신 첫 세팅 시 1회
5. **새 탭/셸 시작**: `zshrc.shared`가 5분 throttle로 `sync.sh` 실행 → bridge 자동 실행

→ rules 또는 MEMORY 만지면 양 도구가 자동 인지. **`~/AGENTS.md` 직접 편집 금지** (다음 trigger에서 덮어쓰임).

### 수동 명령
```bash
# 외부 스킬 풀 재구성 (회사 맥북 첫 세팅 또는 lock 갱신 후)
~/.config/agent-harness-baseline/bootstrap/install-shared-skills.sh

# CC 전용 → Codex 노출
~/.config/agent-harness-baseline/bootstrap/install-codex-skills.sh

# 글로벌 컨벤션 강제 재빌드
~/.config/agent-harness-baseline/bin/rebuild-agents-md.sh --force

# 작업별 work-log 하네스 생성
~/.config/agent-harness-baseline/bin/ensure-work-log-task.sh --title "my task" --json

# Claude Code ↔ Codex 브리지
codex-bridge                 # 빠른 동기화
codex-bridge --validate      # 동기화 + Codex target 검증
codex-bridge --push          # 동기화 + agent-harness-baseline 자동 commit/push
```

### Team workflow

OMC `team`/`swarm`/`ultrawork`를 쓰기 전에는 `codex-bridge --validate`를 먼저 실행한다. 긴 팀 작업이 끝나면 Stop hook이 bridge를 다시 실행해 Claude memories, Codex memories, custom agents, generated command skills, and `AGENTS.md`를 맞춘다.

평소에는 자동으로 돈다:
- 셸/새 탭 시작 시 최대 5분에 한 번
- launchd로 30분마다
- Claude Code 또는 Codex 세션 종료 시

### 의도된 비대칭
- `~/.codex/config.toml`은 Slack/Telegram/MCP 토큰 같은 시크릿을 포함할 수 있어 git에 통째로 넣지 않는다. 공유 가능한 동작은 bridge와 plugin install 상태로 맞추고, 시크릿은 1Password/env/cache로 유지한다.
- Claude hook과 Codex hook은 런타임 의미가 완전히 같지 않다. 공통 Stop hook에는 bridge를 얹고, 도구별 품질 체크는 각 도구 hook에 둔다.


## Shared Design OS (`DESIGN.md` / `getdesign.md`)

Claude Code와 Codex가 같은 디자인 컨텍스트를 보도록 중앙 디자인 파일을 공유한다.

| Entry point | Target |
|---|---|
| `~/DESIGN.md` | `~/.config/agent-harness-baseline/design/DESIGN.md` |
| `~/getdesign.md` | `~/.config/agent-harness-baseline/design/getdesign.md` |
| `~/.claude/DESIGN.md`, `~/.claude/getdesign.md` | same canonical files |
| `~/.codex/DESIGN.md`, `~/.codex/getdesign.md` | same canonical files |

사용법:

```bash
getdesign                         # shell alias가 없으면 아래 직접 실행
~/.config/agent-harness-baseline/bin/getdesign.sh
```

UI/UX/product/visual 작업 전에는 `getdesign.md` → `DESIGN.md` → 프로젝트 로컬 디자인 문서 순서로 읽는다.
공유 디자인 파일을 수정한 뒤에는 아래로 인증한다:

```bash
cd ~/.config/agent-harness-baseline
bash bin/sync-attest.sh
```

## 새 프로젝트 등록
```bash
cd ~/development/new-project
vercel link            # 또는 supabase link --project-ref XXX
project-init           # 매핑 자동 추가 + 1Password 항목 자동 생성 + .env 자동 주입
```
이후 `cd` 할 때마다 자동으로 그 프로젝트의 토큰이 export.

## GUI 앱 설정 sync (`desktop/`)

iTerm2 / VS Code / Cursor / Claude Desktop 설정을 머신 간 동기화. mac-setup 14단계 중 13단계로 자동 import.

### 흐름
```
[개인맥]                                  [회사맥]
export-desktop.sh ─────► SSOT git ─────► import-desktop.sh
(plist + settings.json 등 복사)          (백업 후 덮어쓰기, op inject)
```

### 개인맥 — 변경한 설정을 SSOT에 반영
```bash
export-desktop                    # bin/export-desktop.sh
cd ~/.config/agent-harness-baseline && git add desktop && git commit -m "desktop: sync" && git push
```

### 회사맥 — SSOT 설정을 적용
```bash
ahb-sync                           # 또는 git pull
import-desktop --all              # 자동 import (기존 파일 .bak.타임스탬프로 백업)
# 또는 --dry로 미리보기, 인자 없으면 앱별 yes/no
```
또는 `mac-setup --step 13`으로 마법사가 호출.

### 시크릿 처리 (Claude Desktop MCP API key 등)
- 실제 시크릿 들어간 `claude_desktop_config.json`은 **gitignore**
- git에는 `claude_desktop_config.tpl.json` (1Password 참조 템플릿)만 들어감
  ```json
  "--api-key", "{{ op://Employee/Upstash-MCP/credential }}"
  ```
- import 시 `op inject`로 실제 값 주입 → `~/Library/Application Support/Claude/claude_desktop_config.json`
- 새 MCP 서버 추가 시: 1Password에 항목 만들고 `.tpl.json`에 `op://...` 참조 추가

### 동기화 대상
| 앱 | 파일 |
|----|------|
| iTerm2 | `com.googlecode.iterm2.plist`, `~/Library/Application Support/iTerm2/DynamicProfiles/` |
| VS Code | `settings.json`, `keybindings.json`, `snippets/` |
| Cursor | 동일 |
| Claude Desktop | `claude_desktop_config.tpl.json` (MCP 서버 정의) |

> Karabiner / AeroSpace / Rectangle 등 안 깐 앱은 자동 스킵.

## 검증
```bash
ahb-doctor              # agent-harness-baseline 자체
bootstrap-doctor       # 시스템 전체 (CLI 인증까지)
```

## 충돌
양쪽 머신에서 같은 파일 수정 → 표준 git merge.
자동 commit이 켜져 있어 자주 push되니 충돌은 드묾.

## 히스토리 재작성 후 다른 맥 복구

`git filter-repo` 등으로 **히스토리를 재작성하고 force-push**한 경우(예: 민감정보 purge),
다른 맥의 로컬 클론은 옛 히스토리를 그대로 갖고 있어 그 맥의 자동 sync가 옛 히스토리를
되밀어 **재유출**시킬 수 있다. 그 맥의 sync가 돌기 전에 **한 줄로 재clone**
(옛 디렉터리는 새 clone·install 성공 후에만 삭제):

```bash
touch ~/.config/agent-harness-baseline/.sync-paused 2>/dev/null; mv ~/.config/agent-harness-baseline ~/.config/agent-harness-baseline.OLD && git clone https://github.com/whatamelon/AGENT-HARNESS-BASELINE.git ~/.config/agent-harness-baseline && bash ~/.config/agent-harness-baseline/bin/install.sh && touch ~/.config/agent-harness-baseline/.sync-paused && rm -rf ~/.config/agent-harness-baseline.OLD && echo "✅ 재clone 완료 — sync 일시정지 상태"
```

1. 기존 디렉터리 sync 정지 → `.OLD` 이동 (launchd가 옛 히스토리 못 건드림)
2. 교정된 원격에서 새 clone → `install.sh`로 심링크(`~/.claude` 등) 재연결
3. 새 clone에도 `.sync-paused` — 양쪽 확인 전 자동 sync 방지
4. 새 clone·install 성공 시에만 옛 디렉터리(옛 사본 포함) 삭제

양쪽 맥 정상 확인 후 각 맥에서 `rm ~/.config/agent-harness-baseline/.sync-paused` 로 재개.

> 주의: force-push로 그 시점 이후 **모든 커밋 SHA가 바뀐다**. 이미 public이었다면
> GitHub 캐시·포크·아카이브·크롤러가 옛 내용을 복제했을 수 있어, 완전 제거는
> GitHub Support에 캐시·옛 SHA 퍼지 요청이 추가로 필요하다.

## 로그
- 자동 sync: `/tmp/agent-harness-baseline.{out,err}.log`
- file-tracker: `~/.claude/logs/file-changes.log`

## 끄기 (자동 sync 임시 중단)
```bash
launchctl unload ~/Library/LaunchAgents/com.denny.agent-harness-baseline.plist
# 다시 켜기:
launchctl load ~/Library/LaunchAgents/com.denny.agent-harness-baseline.plist
```
