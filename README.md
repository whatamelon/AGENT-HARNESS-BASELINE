# claude-sync · 개발환경 꾸쮹

두 맥북(개인/회사) 간 Claude Code + Codex + 셸 + 프로젝트 시크릿 + GUI 앱 설정을 git으로 동기화하는 SSOT.
**1Password 통합** + **launchd 자동 sync** + **휘황찬란한 mac-setup 마법사 (14단계)**.

## 새 맥북 한 줄 셋업

```bash
brew install gh && gh auth login && \
git clone https://github.com/whatamelon/claude-sync.git ~/.config/claude-sync && \
  ~/.config/claude-sync/bin/mac-setup.sh auto
```

또는 인터랙티브:
```bash
~/.config/claude-sync/bin/mac-setup.sh
```

마법사 모드:
- `mac-setup` — 인터랙티브 (모드 선택)
- `mac-setup auto` — 처음부터 끝까지 자동
- `mac-setup verify` — 검증만
- `mac-setup --step N` — 특정 단계 (1~13)
- `mac-setup reset` — 진행 상태 초기화

## 디렉터리 구조
```
~/.config/claude-sync/
├── claude/                     # → ~/.claude/{skills,agents,commands,rules,hooks,hud,CLAUDE.md,notify.sh}
├── shell/zshrc.shared          # ~/.zshrc 가 source. chpwd 훅 포함
├── shell/zprofile.shared       # ~/.zprofile 가 source. 백그라운드 git pull
├── shell/machines/             # hostname별 추가 셸 설정
├── git/gitconfig.shared        # ~/.gitconfig include
├── config/projects/            # → ~/.config/projects (Vercel/Supabase 매핑)
├── bin/                        # 헬퍼 스크립트
│   ├── install.sh              # symlink + 셸 + git config 한 방
│   ├── relink.sh               # 새 디렉터리 추가 시 재링크
│   ├── doctor.sh               # claude-sync 자체 검증
│   ├── bootstrap-doctor.sh     # 시스템 + CLI 인증 광범위 검증
│   ├── sync.sh                 # launchd가 호출 — pull → 자동 commit/push
│   ├── migrate-secrets-to-1password.sh  # 평문 토큰 → vault 이전
│   ├── project-init.sh         # 새 프로젝트 sync 등록
│   ├── env-sync.sh             # .env 재주입 (op inject)
│   ├── export-desktop.sh       # ★ GUI 앱 설정 → SSOT (개인맥에서)
│   ├── import-desktop.sh       # ★ SSOT → 새 머신 (op inject 거침)
│   └── rebuild-agents-md.sh    # ★ ~/AGENTS.md 빌더 (Codex 글로벌)
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
| `cs` | SSOT로 cd |
| `cs-sync` | pull + 변경분 자동 commit/push |
| `cs-doctor` | 환경 검증 |
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
2. **30분마다** (launchd `com.denny.claude-sync`): `bin/sync.sh` 호출 → pull → 변경 있으면 자동 commit + push
3. **수동**: `cs-sync` alias

## CC ↔ Codex 통합

`~/.config/claude-sync` 가 Claude Code와 Codex 양 도구의 단일 진실 원천(SSOT). 양쪽이 동일한 **스킬 풀(165개)**과 **글로벌 컨벤션(`~/AGENTS.md`)**을 공유.

### 자산 출처
| 자산 | 위치 | 출처 |
|------|------|------|
| 외부 스킬 157개 | `~/.agents/skills/` | `agents/skill-lock.json` 기준 6개 GitHub repo (anthropic, vercel, wshobson 등) |
| CC 전용 스킬 7개 | `claude/skills/{react-patterns 등}` (실제 디렉터리) | 사용자 자작 |
| 글로벌 규칙 | `claude/rules/*.md` | 양 도구 공유 |
| 사용자 메모리 인덱스 | `~/.claude/projects/.../memory/MEMORY.md` | CC 자동 누적 |

### `~/AGENTS.md` 자동 갱신 (3-trigger)
1. **PostToolUse hook**: CC가 rules/MEMORY 수정 시 즉시 빌드
2. **launchd sync**: 30분마다 git pull 후 빌드
3. **bootstrap step 13b / mac-setup step 5**: 신규 머신 첫 세팅 시 1회

→ rules 또는 MEMORY 만지면 양 도구가 자동 인지. **`~/AGENTS.md` 직접 편집 금지** (다음 trigger에서 덮어쓰임).

### 수동 명령
```bash
# 외부 스킬 풀 재구성 (회사 맥북 첫 세팅 또는 lock 갱신 후)
~/.config/claude-sync/bootstrap/install-shared-skills.sh

# CC 전용 → Codex 노출
~/.config/claude-sync/bootstrap/install-codex-skills.sh

# 글로벌 컨벤션 강제 재빌드
~/.config/claude-sync/bin/rebuild-agents-md.sh --force
```

### 한계 (Codex 미지원으로 의도된 비대칭)
- 훅 시스템: Codex 미지원 → CC 전용 (file-tracker, quality-check)
- 자동 메모리 누적: Codex 미지원 → 메모리는 CC → Codex **단방향**

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
cd ~/.config/claude-sync && git add desktop && git commit -m "desktop: sync" && git push
```

### 회사맥 — SSOT 설정을 적용
```bash
cs-sync                           # 또는 git pull
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
cs-doctor              # claude-sync 자체
bootstrap-doctor       # 시스템 전체 (CLI 인증까지)
```

## 충돌
양쪽 머신에서 같은 파일 수정 → 표준 git merge.
자동 commit이 켜져 있어 자주 push되니 충돌은 드묾.

## 로그
- 자동 sync: `/tmp/claude-sync.{out,err}.log`
- file-tracker: `~/.claude/logs/file-changes.log`

## 끄기 (자동 sync 임시 중단)
```bash
launchctl unload ~/Library/LaunchAgents/com.denny.claude-sync.plist
# 다시 켜기:
launchctl load ~/Library/LaunchAgents/com.denny.claude-sync.plist
```
