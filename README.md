# claude-sync

두 맥북 (개인 / 회사) 간 Claude Code 환경 + 셸 설정 + 프로젝트별 시크릿 매핑을 git으로 동기화하는 SSOT.

## 구조
```
~/.config/claude-sync/
├── claude/         → ~/.claude/{skills,agents,commands,rules,hooks,hud}, CLAUDE.md, notify.sh, mcp.shared.json
├── shell/          → ~/.zshrc / ~/.zprofile 가 source 함
├── git/            → ~/.gitconfig include
├── config/projects → ~/.config/projects (Vercel/Supabase 매핑)
├── bin/            → install.sh, relink.sh, doctor.sh, sync.sh
└── launchd/        → 자동 sync plist
```

## 새 머신 셋업
```bash
brew install --cask 1password-cli
brew install jq
git clone git@github.com:whatamelon/claude-sync.git ~/.config/claude-sync
~/.config/claude-sync/bin/install.sh
exec zsh
```

## 일상 명령
- `cs` — SSOT로 cd
- `cs-sync` — pull + 변경 있으면 commit/push
- `cs-doctor` — 환경 점검

## 자동화
- 셸 시작 시: `~/.zprofile` 백그라운드 pull
- 30분마다: launchd `com.denny.claude-sync` (sync.sh 호출 → pull → 변경 있으면 commit/push)

## 시크릿
- `settings.local.json` — env 토큰 (gitignored)
- `~/.zshrc.local` — 머신별 alias/이메일/PATH (gitignored)
- 프로젝트별 Vercel/Supabase 토큰 — 1Password 참조 (`op://...`) → cd 시 자동 export

## 디렉터리 추가 시
새 카테고리 (예: `claude/templates/`) 추가했으면:
```bash
~/.config/claude-sync/bin/relink.sh
```

## 충돌 시
양쪽 맥북에서 같은 파일 수정 → 표준 git merge.
