// sms-request-code/core.ts
//
// Pure, dependency-injected core for the request-code flow (§8-A C-1). Kept
// free of the Deno serve runtime so it is unit-testable: all I/O (rate limit
// store, verification store, gateway, clock, code factory) is injected.

import { hashCode } from "../_shared/code.ts";
import { isValidKrMobile, normalizeKrPhone, isAllowed } from "../_shared/phone.ts";
import { enforce, type RateLimitConfig, type RateLimitStore, DEFAULT_CONFIG } from "../_shared/rate_limit.ts";
import type { VerificationStore } from "../_shared/store.ts";
import type { SmsGateway } from "../_shared/sms_gateway.ts";
import { buildAuditEvent, emitAudit } from "../_shared/audit.ts";

export const CODE_TTL_SECONDS = 180;
export const MAX_ATTEMPTS = 5;

export interface RequestCodeDeps {
  rateLimitStore: RateLimitStore;
  verificationStore: VerificationStore;
  gateway: SmsGateway;
  allowlist: Set<string>;
  pepper: string;
  rateLimitConfig?: RateLimitConfig;
  /** Injectable for tests; defaults to CSPRNG generator. */
  makeCode: () => string;
  /** Injectable clock for deterministic expiry in tests. */
  now?: () => Date;
}

export interface RequestCodeResult {
  status: number;
  /** Uniform success body, or rate-limit body. */
  body: { ok: true; ttlSeconds: number } | { ok: false; retryAfter: number };
}

/**
 * Core request-code logic.
 *
 * AuthN: the caller is already authenticated (JWT validated at the edge); their
 * `userId` is bound to the issued code via `requested_by` so only that same
 * user can later redeem it (HIGH fix: number-takeover block). Because the caller
 * is authenticated, this endpoint is no longer an unauthenticated enumeration
 * oracle; the uniform-200 response is retained as defense-in-depth (an
 * authenticated user still cannot probe which numbers are registered/allowed).
 *
 * Anti-enumeration: invalid phone / not-on-allowlist returns the SAME uniform
 * `200 {ok:true, ttlSeconds}` as a real send, but dispatches NOTHING. Only a
 * rate-limit breach returns `429`. This hides whether a number is valid,
 * registered, or allowlisted.
 */
export async function handleRequestCode(
  userId: string,
  rawPhone: string,
  ip: string,
  deps: RequestCodeDeps,
): Promise<RequestCodeResult> {
  const cfg = deps.rateLimitConfig ?? DEFAULT_CONFIG;
  const uniformOk: RequestCodeResult = {
    status: 200,
    body: { ok: true, ttlSeconds: CODE_TTL_SECONDS },
  };

  const normalized = normalizeKrPhone(rawPhone);

  // Invalid KR mobile -> uniform success, no send (anti-enumeration).
  if (normalized === null || !isValidKrMobile(normalized)) {
    emitAudit(buildAuditEvent({
      action: "sms_request_code",
      outcome: "suppressed_invalid_phone",
      phone: rawPhone,
      ip,
    }));
    return uniformOk;
  }

  // Rate limit BEFORE any allowlist branch so probing cost is bounded and the
  // 429 cannot itself be used to distinguish allowlisted numbers.
  const decision = await enforce(deps.rateLimitStore, normalized, ip, cfg);
  if (!decision.allowed) {
    emitAudit(buildAuditEvent({
      action: "sms_request_code",
      outcome: "rate_limited",
      phone: normalized,
      ip,
      exceededRule: decision.exceeded,
    }));
    return {
      status: 429,
      body: { ok: false, retryAfter: decision.retryAfter ?? cfg.phone5min.windowSeconds },
    };
  }

  // Not on allowlist -> uniform success, no send.
  if (!isAllowed(normalized, deps.allowlist)) {
    emitAudit(buildAuditEvent({
      action: "sms_request_code",
      outcome: "suppressed_not_allowed",
      phone: normalized,
      ip,
    }));
    return uniformOk;
  }

  // Generate + persist (hash only) + dispatch.
  const code = deps.makeCode();
  const codeHash = await hashCode(code, deps.pepper);
  const now = (deps.now ?? (() => new Date()))();
  const expiresAt = new Date(now.getTime() + CODE_TTL_SECONDS * 1000).toISOString();

  // Single active code per phone: invalidate any prior unconsumed codes first.
  await deps.verificationStore.invalidateOutstanding(normalized);
  await deps.verificationStore.insert({
    phone: normalized,
    code_hash: codeHash,
    requested_by: userId, // takeover binding: only this user may redeem the code
    max_attempts: MAX_ATTEMPTS,
    expires_at: expiresAt,
    request_ip: ip,
  });

  // AlimTalk template preferred in production (see sms_gateway adapters).
  const text = `[인증] 인증번호 ${code} (유효시간 3분)`;
  try {
    await deps.gateway.send(normalized, text);
  } catch (_err) {
    // Dispatch failure is NOT surfaced (uniform response). Audited as error.
    emitAudit(buildAuditEvent({
      action: "sms_request_code",
      outcome: "error",
      phone: normalized,
      ip,
    }));
    return uniformOk;
  }

  emitAudit(buildAuditEvent({
    action: "sms_request_code",
    outcome: "sent",
    phone: normalized,
    ip,
  }));
  return uniformOk;
}
