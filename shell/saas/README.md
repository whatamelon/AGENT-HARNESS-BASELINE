# SaaS 플러그인 디렉터리

`__load_project_secrets()` 훅이 cd마다 이 디렉터리의 모든 `*.sh` 를 자동으로 source + 호출.

## 인터페이스 규약

각 플러그인은 `__load_<saas_name>()` 함수 1개를 정의해야 함. 파일명과 동일.

예: `shell/saas/sentry.sh` → `__load_sentry()` 함수

```bash
__load_<name>() {
  # 1) 마커 파일을 위로 거슬러 찾기 (프로젝트 루트 자동 감지)
  local d="$PWD"
  while [[ "$d" != "/" && "$d" != "$HOME" ]]; do
    if [[ -f "$d/<MARKER>" ]]; then

      # 2) 마커에서 프로젝트 ID 추출
      # 3) ~/.config/projects/<name>.json 매핑에서 op 참조 조회
      # 4) op read로 시크릿 가져와서 export

      # 5) export한 환경변수 이름들을 공백 구분 stdout 출력
      echo "VAR1 VAR2 VAR3"
      break
    fi
    d="${d:h}"
  done
}
```

## 출력 약속

- **export한 변수명을 stdout으로 출력** — 훅이 다음 cd 때 unset할 수 있게 기록
- 빈 출력 = 이 디렉터리에선 적용 안 됨
- export 자체는 함수 내부에서 (서브셸 X)

## 새 SaaS 추가
```bash
saas-add <name>   # 인터랙티브로 자동 생성
```
또는 수동:
1. 이 디렉터리에 `<name>.sh` 작성
2. `~/.config/projects/<name>.json` 빈 매핑 생성
3. 1Password vault 항목 만들기
4. cd 테스트
