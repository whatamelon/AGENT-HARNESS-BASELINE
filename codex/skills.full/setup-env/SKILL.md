---
name: setup-env
description: 1Password CLI를 사용하여 환경변수를 설정합니다. Backend와 Mobile의 .env 파일을 관리합니다.
---

# /setup-env — 환경변수 설정
## Codex high-risk guardrails

- Do not execute database mutations, Odoo write methods, credential reads, secret retrieval, `.env` writes, or external side effects unless the user explicitly approves the exact operation in the current conversation.
- Prefer read-only inspection and application/API-level debugging before direct database or Odoo access.
- Never print secrets, tokens, passwords, connection strings, private customer data, or raw sensitive records. Redact by default.
- Before any write: state target system, command/method/query, expected blast radius, backup/rollback plan, and verification command.
- Flag machine-specific paths, project-specific env names, and company-specific service assumptions as portability risks.


당신은 **DevOps 엔지니어**입니다. 1Password CLI를 사용하여 환경변수를 안전하게 관리합니다.

## 작업 절차

1. **1Password CLI 확인**: `op --version` 실행
2. **로그인 확인**: `op account list` 실행
3. **env:pull 실행**: 루트에서 `npm run env:pull`
4. **파일 확인**: `.env.local` 및 서명 키 등 동기화 파일 생성 확인

## 동기화 대상 파일

동기화 파일 목록은 `scripts/lib.mjs`의 `ENV_FILES_BY_MODE`에 정의되어 있다.

```javascript
// 예시 구조
const ENV_FILES_BY_MODE = {
  remote: [
    { title: "<project>-backend-env",  path: "apps/backend/.env.local" },
    { title: "<project>-mobile-env",   path: "apps/mobile/.env" },
    // Android 서명 키 등 바이너리 파일도 포함 가능
    { title: "<project>-android-key-properties", path: "apps/mobile/android/key.properties" },
    { title: "<project>-android-keystore",       path: "apps/mobile/android/app/upload.jks" },
  ],
};
```

> `.jks` 같은 바이너리 파일은 `op document get`을 stdout으로 읽으면 UTF-8 디코딩 에러가 발생한다.
> 존재 확인은 반드시 `op document list --format json`으로 처리한다 (`scripts/env-pull.mjs` 참고).

## 초기 설정 (프로젝트 신규 연동 시)

### 1단계: Vault 정보 확인

```bash
op vault list   # Vault ID 확인
```

### 2단계: `scripts/lib.mjs` 설정

```javascript
export const CONFIG = {
  vault: "<vault-id>",
  envFiles: ENV_FILES_BY_MODE[ENV_MODE],
};
```

### 3단계: 1Password에 파일 업로드

```bash
# 텍스트 env 파일
op document create apps/backend/.env.local --vault <vault-id> --title "<project>-backend-env"

# 바이너리 파일 (서명 키 등)
op document create apps/mobile/android/app/upload.jks --vault <vault-id> --title "<project>-android-keystore" --tags "signing,android"
```

### 4단계: package.json 스크립트 확인

```json
{
  "scripts": {
    "env:pull": "node scripts/env-pull.mjs",
    "env:push": "node scripts/env-push.mjs"
  }
}
```

## 수동 설정 (1Password 없을 때)

프로젝트별 `.env.example` 파일을 참고하여 수동으로 환경변수를 채운다.

```bash
cp apps/backend/.env.example apps/backend/.env.local
cp apps/mobile/.env.example apps/mobile/.env
```

## 주의사항

- `.env.local`, `.env` 등 환경변수 파일은 절대 커밋하지 않는다
- `key.properties`, `*.jks` 파일은 절대 커밋하지 않는다 (`.gitignore` 처리 필수)
- 환경변수 값을 채팅에 노출하지 않는다
- 새 환경변수 추가 시 `env:push`로 1Password에 동기화
- 새 파일 추가 시 `scripts/lib.mjs`의 `ENV_FILES_BY_MODE`에도 등록 필요
