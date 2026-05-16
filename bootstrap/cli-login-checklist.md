# CLI 로그인 체크리스트 (사람만 가능한 부분)

`bootstrap-new-mac.sh` 가 자동으로 못 하는 OAuth/SSO 인증 모음.
새 맥북마다 한 번씩 진행.

## 🔴 필수 (안 하면 작업 불가)

### 1. 1Password CLI
```bash
# 1) 1Password 앱 → Settings → Developer → "Integrate with 1Password CLI" ON
# 2) CLI 인증
op signin
op vault list   # 결과 보이면 OK
```

### 2. GitHub
```bash
gh auth login
# - github.com 선택
# - HTTPS 또는 SSH 선택 (HTTPS 권장 — 회사 IT 정책 단순)
# - 브라우저 인증
gh auth status
```

### 3. Claude Code 첫 실행
```bash
claude   # OAuth로 Claude 계정 인증
```

---

## 🟡 프로젝트별로 필요한 것

### Vercel
```bash
vercel login                    # 이메일로 로그인
cd ~/development/[프로젝트]
vercel link                     # 프로젝트 연결 (.vercel/project.json 생성)
project-init                    # → ~/.config/projects/vercel.json 자동 등록
```

### Supabase

**중요:** `supabase login` browser OAuth는 종종 `Unknown error` 실패. **PAT 방식 권장.**

```bash
# 1) PAT 생성: https://supabase.com/dashboard/account/tokens
#    → Generate new token → "agent-harness-baseline" 이름 → 복사
# 2) 1Password에 저장 (한 번만)
op item create --category 'API Credential' --title 'supabase-pat' \
  --vault Employee credential='<paste>' --tags agent-harness-baseline,supabase

# 3) login (한 줄, 두 머신 다 같은 토큰)
supabase login --token "$(op read 'op://Employee/supabase-pat/credential')"

# 4) 프로젝트 연결
cd ~/development/[프로젝트]
supabase link --project-ref XXX
project-init                    # → ~/.config/projects/supabase.json 자동 등록
```

### Google Workspace (gws) — Gmail / Drive / Sheets / Docs / Calendar
Workspace 작업은 무조건 `gws` 우선. `gcloud`는 GCP 인프라용으로만.

```bash
# 첫 실행 시 OAuth (1회) — keyring에 refresh token 영구 저장
gws schema gmail.users.messages.list >/dev/null

# 검증
gws gmail users labels list --params '{"userId":"me"}' | head -5
```

세션마다 재인증 X. 권한 부족 에러 발생 시에만 토큰 재발급.

### Google Cloud (GCP 전용)
Workspace API는 위 `gws` 사용. `gcloud`는 Cloud Run / BigQuery / GCS 등 인프라 용도.

```bash
gcloud init
gcloud auth login                       # 사용자 인증
gcloud auth application-default login   # 앱 기본 자격증명 (라이브러리용)
gcloud config set project [PROJECT_ID]
```

### Firebase
```bash
firebase login    # 브라우저 OAuth
firebase projects:list
```

### Cloudflare Workers (wrangler)
```bash
wrangler login    # 브라우저 OAuth
```

### Docker
```bash
docker login                    # Docker Hub
# 또는 회사 레지스트리:
# docker login ghcr.io          # GitHub Container Registry
# docker login [회사].dkr.ecr.[region].amazonaws.com
```

### AWS
```bash
aws configure                   # access key + secret + region 입력
# 또는 SSO: aws sso login
```

---

## 🟢 선택 (필요한 사람만)

### npm registry
```bash
# 회사 private registry 쓸 경우
npm login --registry=https://npm.[회사].com
```

### Homebrew GitHub API rate limit
```bash
# 익명 60/h → 5000/h 로 늘림
brew install gh && gh auth login   # gh가 깔리면 자동 사용
```

### Android Studio / Xcode
- 처음 실행 시 라이선스 동의 + SDK 설치
- Java JBR 활성화: `~/.zshrc.shared` 가 자동 PATH 잡음

### macOS 시스템 권한 (한 번 클릭)
- 터미널/iTerm → 시스템 설정 → 개인정보 보호 → 전체 디스크 접근
- 알림 → Claude Code: 알림 허용
- 키보드 단축키 충돌 확인

---

## 트러블슈팅

### `Load failed: 5: Input/output error` — launchctl
- macOS 26.x에서 `~/Library/LaunchAgents/` 심링크 차단 케이스. **plist는 심링크 X, cp 필수**.
- 옛 syntax 사용 중일 수 있음. modern syntax로:
  ```bash
  launchctl bootout "gui/$UID/<label>" 2>/dev/null
  launchctl bootstrap "gui/$UID" "$HOME/Library/LaunchAgents/<label>.plist"
  ```

### SSOT plist 0 bytes로 변형
드물지만 새 머신 setup 중 발생 가능. git 복구:
```bash
cd ~/.config/agent-harness-baseline
git status -s launchd/
git checkout HEAD -- launchd/<broken>.plist
```

### `supabase login` Unknown error
browser OAuth 실패. PAT 방식 사용. 위 Supabase section 참고.

### paste 시 명령 줄바꿈으로 깨짐
긴 명령은 짧게 디렉토리 이동 후 상대경로로:
```bash
cd ~/Library/LaunchAgents
launchctl bootstrap gui/$UID ./<plist>
```

---

## 검증
모든 로그인 끝나면:
```bash
ahb-doctor                                                       # agent-harness-baseline 환경 검증
gh auth status                                                  # GitHub
op vault list                                                   # 1Password
gws gmail users labels list --params '{"userId":"me"}' >/dev/null && echo "gws OK"
supabase projects list >/dev/null 2>&1 && echo "supabase OK"
vercel whoami                                                   # Vercel
gcloud auth list                                                # GCP
docker info                                                     # Docker
firebase projects:list                                          # Firebase
wrangler whoami                                                 # Cloudflare
```

---

## 회전 주기 (참고)

| 토큰 | 권장 회전 주기 | 회전 후 액션 |
|------|---------------|--------------|
| GitHub PAT | 90일 | 1Password 항목 password 수정 → `env-sync` |
| Vercel token | 매년 | 동일 |
| Supabase token | 6개월 | 동일 |
| AWS access key | 90일 | `aws configure` 다시 |
| 1Password 마스터 비밀번호 | 1년 | 데스크톱 앱에서 변경 |

토큰 회전한 뒤 영향받는 프로젝트들에서 한 줄:
```bash
env-sync   # .env 재주입
```
