# claude-sync

두 맥북(개인/회사) 간 Claude Code + 셸 + 프로젝트 시크릿을 git으로 동기화하는 SSOT.
**1Password 통합** + **launchd 자동 sync** + **새 맥북 한 줄 부트스트랩**.

## 한 줄 새 맥북 셋업
```bash
git clone https://github.com/whatamelon/claude-sync.git ~/.config/claude-sync && \
  ~/.config/claude-sync/bootstrap/bootstrap-new-mac.sh
```
이후 [`bootstrap/cli-login-checklist.md`](bootstrap/cli-login-checklist.md) 의 OAuth 로그인 한 번씩.

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
│   └── env-sync.sh             # .env 재주입 (op inject)
├── bootstrap/
│   ├── bootstrap-new-mac.sh    # ★ 한 줄 셋업
│   ├── Brewfile                # brew 패키지 일괄
│   ├── npm-globals.txt         # npm 글로벌 패키지
│   └── cli-login-checklist.md  # OAuth 안내
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

## 새 프로젝트 등록
```bash
cd ~/development/new-project
vercel link            # 또는 supabase link --project-ref XXX
project-init           # 매핑 자동 추가 + 1Password 항목 자동 생성 + .env 자동 주입
```
이후 `cd` 할 때마다 자동으로 그 프로젝트의 토큰이 export.

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
