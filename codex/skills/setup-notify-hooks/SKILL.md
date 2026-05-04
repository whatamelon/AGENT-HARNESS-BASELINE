---
name: setup-notify-hooks
description: Claude Code 작업 완료/알림 시 Telegram + Slack으로 푸시 알림을 보내는 훅을 설치한다.
---
---

## 절차

### Step 1: OS 감지

```bash
uname -s 2>/dev/null || echo "Windows"
```

- `Darwin` → macOS → `notify.sh` 사용
- `Linux` → Linux → `notify.sh` 사용
- 그 외 (Git Bash / PowerShell) → Windows → `notify.ps1` 사용

---
---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---
---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---
---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---
---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---

<!-- AUTO-GENERATED by codex-bridge.sh from $CLAUDE_SYNC_HOME/claude/skills/setup-notify-hooks/SKILL.md with Codex-compatible name metadata. -->

---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---
---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---

<!-- AUTO-GENERATED by codex-bridge.sh from $CLAUDE_SYNC_HOME/claude/skills/setup-notify-hooks/SKILL.md with Codex-compatible name metadata. -->

---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---
---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---
---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---
---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---

<!-- AUTO-GENERATED by codex-bridge.sh from $CLAUDE_SYNC_HOME/claude/skills/setup-notify-hooks/SKILL.md with Codex-compatible name metadata. -->

---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---
---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---
---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
---

<!-- AUTO-GENERATED by codex-bridge.sh from $CLAUDE_SYNC_HOME/claude/skills/setup-notify-hooks/SKILL.md with Codex-compatible name metadata. -->


## 절차

### Step 1: OS 감지

```bash
uname -s 2>/dev/null || echo "Windows"
```

- `Darwin` → macOS → `notify.sh` 사용
- `Linux` → Linux → `notify.sh` 사용
- 그 외 (Git Bash / PowerShell) → Windows → `notify.ps1` 사용

---

### Step 2: 기존 설정 확인

`~/.claude/settings.json`을 읽어 아래 항목이 이미 있는지 확인한다.

| 확인 항목 | 경로 |
|-----------|------|
| Telegram 토큰 | `env.TELEGRAM_TOKEN` |
| Telegram Chat ID | `env.TELEGRAM_CHAT_ID` |
| Slack Bot 토큰 | `env.SLACK_BOT_TOKEN` |
| Slack User ID | `env.SLACK_USER_ID` |
| Stop 훅 | `hooks.Stop` |
| Notification 훅 | `hooks.Notification` |

이미 있는 항목은 건너뛰고 없는 항목만 수집한다.

---

### Step 3: 자격증명 수집

없는 항목에 대해 사용자에게 질문한다.

**Telegram 설정 안내** (처음 설정하는 경우):
```
1. Telegram에서 @BotFather 에게 /newbot 명령으로 봇 생성
2. 발급받은 토큰을 입력 (예: 1234567890:AAGxxx...)
3. 본인 Chat ID는 @userinfobot 에게 메시지 보내면 확인 가능
```

**Slack 설정 안내** (처음 설정하는 경우):
```
1. https://api.slack.com/apps 에서 앱 생성 또는 기존 봇 토큰 사용
2. Bot Token (xoxb-...) 입력
3. 본인 Slack User ID는 프로필 → More → Copy member ID
```

수집할 값:
- `TELEGRAM_TOKEN` (선택: 없으면 Telegram 알림 비활성)
- `TELEGRAM_CHAT_ID` (선택)
- `SLACK_BOT_TOKEN` (선택: 없으면 Slack 알림 비활성)
- `SLACK_USER_ID` (선택)

> Telegram, Slack 중 하나만 설정해도 동작한다.

---

### Step 4: 스크립트 복사

이 레포의 `.claude/hooks/` 에서 OS에 맞는 스크립트를 `~/.claude/`로 복사한다.

**Windows (Git Bash):**
```bash
cp .claude/hooks/notify.ps1 ~/.claude/notify.ps1
```

**macOS / Linux:**
```bash
cp .claude/hooks/notify.sh ~/.claude/notify.sh
chmod +x ~/.claude/notify.sh
```

스크립트 원본 위치: 이 저장소 `.claude/hooks/notify.ps1` / `.claude/hooks/notify.sh`

---

### Step 5: settings.json 업데이트

`~/.claude/settings.json`을 읽어 아래 구조를 병합한다. 기존 내용을 덮어쓰지 않도록 **merge** 방식으로 적용한다.

**Windows 훅 커맨드:**
```
powershell.exe -WindowStyle Hidden -File "C:\Users\<USERNAME>\.claude\notify.ps1"
```

**macOS 훅 커맨드:**
```
~/.claude/notify.sh
```

USERNAME은 아래로 확인:
```bash
# Windows
echo $USERNAME
# macOS/Linux
echo $USER
```

**병합할 구조:**
```json
{
  "env": {
    "TELEGRAM_TOKEN": "<입력값>",
    "TELEGRAM_CHAT_ID": "<입력값>",
    "SLACK_BOT_TOKEN": "<입력값>",
    "SLACK_USER_ID": "<입력값>"
  },
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "<OS별 커맨드>"
          }
        ]
      }
    ]
  }
}
```

> `settings.json`이 없으면 새로 생성한다.
> 이미 있는 `env` 키는 유지하고 새 키만 추가한다.
> 이미 훅이 있으면 덮어쓰지 않고 사용자에게 확인을 구한다.

---

### Step 6: 검증

설치 후 동작을 확인한다.

**Windows:**
```bash
powershell.exe -WindowStyle Hidden -File "$HOME/.claude/notify.ps1"
```

**macOS / Linux:**
```bash
echo '{"message":"훅 설치 테스트"}' | ~/.claude/notify.sh
```

Telegram / Slack에 테스트 메시지가 도착하면 설치 완료.

---

## 완료 체크리스트

- [ ] OS 감지 완료
- [ ] 스크립트가 `~/.claude/` 에 복사됨
- [ ] `~/.claude/settings.json` 에 `env` + `hooks` 추가됨
- [ ] 테스트 알림 전송 확인
