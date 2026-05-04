# Google Workspace / Gmail 작업 규칙

## 핵심 규칙

> **Gmail·Calendar·Drive·Sheets·Docs 등 Google Workspace 작업은 `gws` CLI를 1순위로 사용한다.**

`gws` (Google Workspace CLI, Homebrew로 설치)는 keyring에 OAuth refresh token을 영구 저장해서 한 번 인증하면 모든 세션에서 그대로 동작한다. MCP 서버 추가 설치나 별도 OAuth 클라이언트 셋업 없이 즉시 호출 가능.

## 우선순위

| 순위 | 도구 | 사용 조건 |
|------|------|-----------|
| 1 | `gws` CLI | 기본 — Gmail/Drive/Sheets/Docs/Calendar 등 Workspace 전 영역 |
| 2 | `gcloud auth print-access-token` + `curl` Workspace REST | `gws`가 미지원하는 신규/베타 엔드포인트만 (단, gcloud 토큰에 해당 스코프가 있어야 함) |
| 3 | Gmail / Google MCP 서버 | `gws` 미설치 환경 또는 사용자가 명시적으로 MCP를 요청한 경우 |
| 4 | 자체 OAuth 클라이언트 / `googleapis` SDK | 위 셋 모두 부적합한 특수 케이스 |

## `gws` 기본 사용 패턴

```bash
# 메시지 목록 (Gmail 검색 쿼리 그대로 사용 가능)
gws gmail users messages list --params '{"userId":"me","maxResults":10,"q":"is:unread"}'

# 메시지 본문
gws gmail users messages get --params '{"userId":"me","id":"<MSG_ID>","format":"full"}'

# 라벨 / 스레드
gws gmail users labels list --params '{"userId":"me"}'
gws gmail users threads get --params '{"userId":"me","id":"<THREAD_ID>"}'

# Drive / Sheets
gws drive files list --params '{"pageSize":10}'
gws sheets spreadsheets get --params '{"spreadsheetId":"..."}'

# 사용 가능한 메서드 스키마 조회
gws schema gmail.users.messages.list
```

`q` 파라미터는 Gmail 검색 문법(`from:`, `subject:`, `after:YYYY/MM/DD`, `has:attachment` 등) 그대로 사용.

## 인증 / 스코프

- 인증은 **영구**다. `gws` 첫 실행 시 OAuth 1회 → keyring에 refresh token 저장 → 이후 모든 세션에서 자동 갱신.
- 세션마다 재인증 요구하지 말 것. 권한 부족 에러(`insufficient scope`)가 아니라면 토큰을 다시 받지 않는다.
- `gcloud auth print-access-token` 의 토큰은 기본 스코프에 Gmail/Workspace가 없으니, REST 직접 호출이 꼭 필요할 때만 `gcloud auth login --scopes=...` 로 별도 추가.

## 금지 사항

| 금지 | 이유 |
|------|------|
| Gmail 작업 위해 새 MCP 서버를 사용자 동의 없이 설치 | `gws`가 이미 동작하는데 도구 중복 추가 |
| `gws` 미시도 후 곧바로 `googleapis` Node/Python SDK 코드 작성 | 일회성 조회/추출은 CLI 한 줄이면 끝 |
| 메일 발송(`gws gmail users messages send`)을 사용자 명시 승인 없이 실행 | Slack 규칙과 동일 — 외부 발신은 사전 승인 필수 |

## How to apply

- "이메일 가져와", "메일 검색해", "Gmail 확인해", "Drive에서 파일 찾아" 등 Workspace 관련 요청 → 먼저 `command -v gws` 확인 → 있으면 `gws` 사용
- 부재 시에만 fallback 후보(MCP/SDK)를 사용자에게 제안
- 메일 **발송**은 Slack 메시지 전송과 동일하게 초안 → 대상 명시 → 사용자 명시 승인 → 실행 → 결과 보고 절차
