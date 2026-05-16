---
name: agent-harness-baseline
description: Claude Code와 Codex가 공유하는 AGENT-HARNESS-BASELINE 설정/스킬/에이전트/디자인 하네스를 설치, 검증, 동기화한다. 사용자가 agent harness, AGENT-HARNESS-BASELINE, 하네스, getdesign, designslop, 공유 설정, 다른 머신 동기화, Codex/Claude 설정 일관성을 언급할 때 사용한다.
---

# AGENT-HARNESS-BASELINE

Claude Code와 Codex가 함께 쓰는 에이전트 하네스 기준선이다. 이전 `claude-sync` 이름은 Claude 전용처럼 보여 더 이상 주 이름으로 쓰지 않는다.

## 핵심 경로

- canonical home: `~/.config/agent-harness-baseline`
- legacy compatibility: `~/.config/claude-sync` may remain as a symlink only
- GitHub repo: `whatamelon/AGENT-HARNESS-BASELINE`
- primary env: `AGENT_HARNESS_BASELINE_HOME`

## 자주 쓰는 명령

```bash
ahb          # repo로 이동
ahb-sync     # pull/push 동기화
ahb-doctor   # 설치/링크 검증
ahb-pause    # launchd sync 일시정지
ahb-resume   # launchd sync 재개
```

직접 실행해야 할 때는 canonical path를 쓴다:

```bash
~/.config/agent-harness-baseline/bin/doctor.sh
~/.config/agent-harness-baseline/bin/sync-attest.sh
~/.config/agent-harness-baseline/bin/getdesign.sh doctor
~/.config/agent-harness-baseline/bin/designslop-doctor.sh
```

## 작업 규칙

1. 새 문서/스크립트에는 `claude-sync`를 쓰지 말고 `AGENT-HARNESS-BASELINE` 또는 `agent-harness-baseline`을 쓴다.
2. 프로젝트별 legacy marker `.claude-sync.json`은 읽기 전용 migration fallback으로만 유지한다.
3. 디자인 작업 자동화는 `getdesign`과 `designslop` 하네스를 함께 확인한다.
4. 머신 이식성 때문에 `/Users/<name>/...` 절대경로를 새로 고정하지 말고 `~` 또는 env var를 우선한다.
5. 변경 후 최소 검증:

```bash
bash -n bin/*.sh bootstrap/*.sh shell/saas/*.sh tests/*.bash
plutil -lint launchd/*.plist
bash bin/getdesign.sh doctor
bash bin/designslop-doctor.sh
bash bin/sync-attest.sh --skip-doctor
```
