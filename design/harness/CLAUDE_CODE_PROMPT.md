# Claude Code Prompt — DESIGN.md Quality Loop Verification

지금 폴더는 DESIGN.md 품질 루프 검증용 Next.js 샌드박스다.

먼저 아래 파일을 반드시 읽어라:

1. `./getdesign.md`
2. `./DESIGN.md`
3. `./DESIGN_LOOP_TEST_REPORT.md`
4. `./AGENTS.md`
5. Next 로컬 문서:
   - `node_modules/next/dist/docs/01-app/01-getting-started/03-layouts-and-pages.md`
   - `node_modules/next/dist/docs/01-app/01-getting-started/11-css.md`
   - `node_modules/next/dist/docs/01-app/01-getting-started/14-metadata-and-og-images.md`

## 목표

Claude Code에서도 Codex와 동일한 DESIGN.md 기반 디자인 품질 루프가 작동하는지 검증해라.

## 해야 할 일

1. 현재 구현된 UI가 DESIGN.md 규칙을 제대로 따르는지 리뷰해라.
2. 필요하면 `src/app/page.tsx`, `src/app/globals.css`, `src/app/layout.tsx`를 개선해라.
3. 반드시 다음 요소를 유지하거나 더 좋게 만들어라:
   - premium responsive landing page
   - hero with primary/secondary CTA
   - 3 feature cards
   - sync/attestation panel with concrete evidence
   - Loading / Empty / Error / Success 상태 예시
   - polished typography, spacing, elevation, cards, buttons
   - generic AI template 느낌 금지
   - light/dark mode 모두에서 모든 보이는 텍스트 대비 4.5:1 이상
   - 흰 글씨를 쓰는 패널은 배경을 테마 토큰 반전(`var(--text)`)에 의존하지 말고 실제 계산 대비를 검증
   - mobile/tablet/desktop/wide viewport 모두에서 horizontal overflow 없음
   - mobile/tablet 인터랙션 타겟은 최소 44×44px
   - 키보드 Tab 순서는 `View proof -> Run scenario -> Inspect states` 유지
   - 모든 키보드 포커스 대상은 `:focus-visible`과 명확한 2px+ 포커스 indicator를 가져야 함
   - 모든 viewport/theme에서 axe accessibility violation 0개 유지
   - `prefers-reduced-motion: reduce`에서 smooth scroll, transition/animation duration, pulse animation, hover 이동/크기 변화가 없어야 함
   - `forced-colors: active`에서 텍스트 대비, 핵심 UI 경계선, 키보드 포커스, 배경 이미지 제거가 유지되어야 함
   - 150%/200% text zoom에서 horizontal overflow, section clipping, CTA clipping이 없어야 함
   - 긴 한국어/영어/해시/파일경로/명령어 content stress에서도 page overflow, section clipping, unapproved horizontal scroll이 없어야 함
   - CTA/cards/states/protocol 등 `data-density-group`은 최소 spacing을 유지해야 하며, visible CTA/link hit area가 겹치거나 8px 미만으로 붙으면 안 됨
   - 주요 CTA/link는 `data-interaction-probe`로 default/hover/active 스타일 변화가 검증되어야 하며, loading/disabled 컨트롤은 semantic attribute와 시각적 차이를 모두 가져야 함
   - hero/section/card/CTA/evidence panel은 `data-visual-priority` 기반 hierarchy audit에서 명확한 우선순위가 검증되어야 함
   - operator-facing copy는 `data-copy-quality` 기반 copy audit에서 generic AI/SaaS 문구, 증거 없는 주장, 복구 경로 없는 상태 문구가 없어야 함
4. 검증을 실행해라:
   - `pnpm lint`
   - `pnpm build`
   - `pnpm test:visual`
5. 결과 증거를 보고해라:
   - 통과/실패한 명령어
   - light/dark screenshot 경로
   - `artifacts/visual-check.json` 핵심값
   - `contrastAudit.failures`가 빈 배열인지
   - `layoutAudit.horizontalOverflowPx`, `layoutAudit.undersizedAnchorTargets`, `layoutAudit.horizontallyClippedSections`가 비어 있는지
   - `keyboardAudit.actualOrder`가 기대 순서와 일치하는지
   - `keyboardAudit.steps[]`의 `visible`, `focusVisible`, `hasFocusIndicator`가 모두 true인지
   - `axeAudit.violations`가 모든 viewport/theme에서 빈 배열인지
   - `reducedMotionAudit.mediaMatches`가 true인지, `scrollBehavior`가 `auto`인지
   - `reducedMotionAudit.motionOffenders`와 `hoverMotionOffenders`가 모든 viewport/theme에서 빈 배열인지
   - `forcedColorsAudit.mediaMatches`가 true인지
   - `forcedColorsAudit.contrastAudit.failures`, `boundaryAudit.failures`, `backgroundImageOffenders`가 모든 viewport/theme에서 빈 배열인지
   - forced-colors screenshot이 모든 viewport/theme에서 생성됐는지
   - `textZoomAudit.levels[]`의 150%/200%에서 `horizontalOverflowPx`, `horizontallyClippedSections`, `clippedAnchorTargets`가 모두 비어 있는지
   - 200% text-zoom screenshot이 모든 viewport/theme에서 생성됐는지
   - `contentStressAudit`의 `horizontalOverflowPx`, `horizontallyClippedSections`, `clippedStressTargets`, `clippedAnchorTargets`, `scrollContainerOffenders`가 모두 비어 있는지
   - content-stress screenshot이 모든 viewport/theme에서 생성됐는지
   - `densityAudit.groupCount`가 5 이상인지
   - `densityAudit.groupFailures`와 `densityAudit.hitAreaFailures`가 모든 viewport/theme에서 빈 배열인지
   - `interactionAudit.probeCount`가 3 이상인지
   - `interactionAudit.hoverFailures`, `activeFailures`, `stateFailures`가 모든 viewport/theme에서 빈 배열인지
   - `hierarchyAudit.failures`가 모든 viewport/theme에서 빈 배열인지
   - `copyQualityAudit.targetCount`가 24 이상인지
   - `copyQualityAudit.failures`가 모든 viewport/theme에서 빈 배열인지
   - 8개 viewport/theme 시나리오가 모두 실행됐는지
   - light/dark의 최저 contrast ratio
   - Codex 결과와 비교했을 때 디자인 품질이 유지/개선됐는지
6. 완료 전에 DESIGN.md 품질 루프 관점에서 부족한 점이 있으면 수정하고 다시 검증해라.

## 중요

- 추측으로 완료했다고 말하지 마라.
- lint/build/visual check가 통과해야 완료다.
- 특히 다크모드에서 `흰 글씨 + 밝은 배경`이 한 번이라도 나오면 실패로 보고 수정 후 재검증해라.
- 모바일/태블릿에서 horizontal overflow나 44px 미만 터치 타겟이 나오면 실패로 보고 수정 후 재검증해라.
- 키보드 Tab 순서가 `View proof -> Run scenario -> Inspect states`에서 벗어나거나 focus-visible indicator가 없으면 실패로 보고 수정 후 재검증해라.
- axe가 landmark, accessible name, heading, ARIA, name/role/value violation을 하나라도 보고하면 실패로 보고 수정 후 재검증해라.
- reduced motion에서 smooth scroll, transition/animation, pulse, hover translate/resize가 하나라도 남으면 실패로 보고 수정 후 재검증해라.
- forced-colors에서 텍스트 대비 실패, 핵심 boundary border 손실, 배경 이미지 잔존, 포커스 indicator 손실이 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- text zoom 150%/200%에서 horizontal overflow, section clipping, CTA clipping, target size 실패가 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- content stress에서 긴 문자열로 인한 page overflow, clipped target, unapproved horizontal scroll이 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- density audit에서 marked group overlap, group min spacing 미달, hit-area separation 8px 미달이 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- interaction audit에서 hover/active 변화 없음, loading aria-busy/disabled/busy indicator/wait cursor 누락, disabled attribute/aria-disabled/not-allowed cursor 누락이 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- hierarchy audit에서 h1 개수, hero/section/card type ramp, primary/secondary CTA 차별성, verification panel elevation, hero 위치 실패가 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- copy quality audit에서 generic filler, concrete evidence 부족, error recovery path 누락, protocol verb 누락, command/hash/count evidence 누락이 하나라도 있으면 실패로 보고 수정 후 재검증해라.
- `BASE_URL`을 명시하지 않은 `pnpm test:visual`은 stale localhost를 재사용하지 않고 자체 ephemeral `next start` 서버를 띄우는지 확인해라.
- 절대경로는 현재 Mac 전용일 수 있으니 보고서에서는 portability risk로 표시해라.
