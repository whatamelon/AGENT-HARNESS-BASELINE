# Slack 사용 규칙

Slack MCP 서버(`slack-mcp-server`) 및 Slack CLI(`slack`)를 사용할 때 반드시 따라야 할 규칙.

## 핵심 원칙

> **읽기: 무제한 허용. 쓰기: 사용자 명시적 승인 필수.**

워크스페이스에 외부로 나가는 모든 행위(메시지 전송, 워크스페이스 상태 변경)는 사용자가 명확히 동의하기 전까지 절대 실행 금지.

## 🟢 사용자 승인 없이 자유롭게 사용 가능 (READ-ONLY)

다음 도구는 워크스페이스에 흔적을 남기지 않고 정보를 가져오기만 하므로 자유롭게 호출:

| MCP 도구 | 용도 |
|---|---|
| `channels_list` | 채널 목록 조회 |
| `users_search` | 사용자 검색 |
| `usergroups_list` | 유저그룹 목록 |
| `usergroups_me` | 내가 속한 그룹 조회 |
| `conversations_history` | 채널/DM 메시지 가져오기 |
| `conversations_replies` | 스레드 답글 가져오기 |
| `conversations_search_messages` | 메시지 검색 |
| `conversations_unreads` | 안 읽은 메시지 조회 |

CLI 측 read 명령(`slack auth list`, `slack app list` 등)도 자유롭게 사용.

## 🔴 사용자 명시적 승인 없이 절대 호출 금지 (WRITE / SIDE-EFFECT)

다음 도구는 **반드시** 사용자가 "보내", "전송해", "OK", "승인" 등 명확한 GO 신호를 줄 때까지 호출 금지:

| MCP 도구 | 부작용 |
|---|---|
| `conversations_add_message` | **채널/DM에 메시지 전송** — 다른 사람에게 보임 |
| `conversations_mark` | 읽음 상태 변경 — 사용자가 안 본 것을 본 것으로 만듦 |
| `usergroups_create` | 워크스페이스에 유저그룹 신규 생성 |
| `usergroups_update` | 유저그룹 메타데이터 변경 |
| `usergroups_users_update` | 유저그룹 멤버 **전체 교체** (덮어쓰기) |

CLI 측: `slack chat`, `slack message`, `slack deploy`, `slack run`, `slack app install/uninstall`, `slack collaborator add` 등 워크스페이스 상태를 변경하거나 외부에 발신하는 모든 명령.

## 메시지 전송 절차 (필수)

write 도구를 호출하기 **전에** 반드시 다음 순서로 진행:

1. **초안 표시**: 보낼 메시지 본문을 코드블록으로 정확히 보여주기
2. **대상 명시**: 채널 이름/ID 또는 DM 상대 이름/ID를 명시
3. **승인 대기**: 사용자가 명확한 GO 신호를 줄 때까지 대기 (모호하면 다시 물어보기)
4. **전송 실행**: 승인 받은 후에만 도구 호출
5. **결과 보고**: 전송된 메시지의 timestamp, permalink 등을 사용자에게 보고

**모호한 표현은 승인이 아님:**
- ❌ "그렇게 해줘" (대상이 메시지인지 다른 작업인지 불명)
- ❌ "확인했어" (단순 ack일 수 있음)
- ✅ "보내", "전송", "OK 보내", "go", "승인", "맞아 그대로 보내"

## 위반 시 대처

만약 실수로 승인 없이 메시지를 보냈다면:
1. **즉시** 사용자에게 알림 (전송된 메시지 내용, 대상, timestamp 포함)
2. Slack은 일정 시간 내 메시지 편집/삭제 가능 — 사용자에게 삭제 의사 확인
3. 승인 시 `chat.delete` 또는 동등한 절차로 회수 시도

## 예외 사항

다음 경우에는 사전 승인 없이 메시지 전송 가능 (단, 시작 시점에 사용자가 명시적으로 위임한 경우만):

- 사용자가 "지금부터 다음 N개 메시지는 자동으로 보내도 돼"라고 명시한 경우
- 사용자가 자동 알림 훅(`setup-notify-hooks` 등)을 직접 설정한 경우 — 해당 훅이 보내는 알림은 본 규칙 적용 대상 아님

위임은 **단일 작업/세션 범위**로만 유효. 다음 세션에는 다시 본 규칙이 기본으로 적용.
