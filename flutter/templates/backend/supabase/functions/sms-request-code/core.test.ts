// sms-request-code/core.test.ts — C-1 behaviors via injected fakes.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleRequestCode } from "./core.ts";
import { hashCode } from "../_shared/code.ts";
import type { RateLimitStore } from "../_shared/rate_limit.ts";
import type { VerificationStore, VerificationRow } from "../_shared/store.ts";
import type { SmsGateway } from "../_shared/sms_gateway.ts";

const PEPPER = "test-pepper";
const USER = "user-1";

class FakeRate implements RateLimitStore {
  private hits = new Map<string, number>();
  hit(key: string): Promise<number> {
    const n = (this.hits.get(key) ?? 0) + 1;
    this.hits.set(key, n);
    return Promise.resolve(n);
  }
  count(key: string): Promise<number> {
    return Promise.resolve(this.hits.get(key) ?? 0);
  }
}

class FakeVerStore implements VerificationStore {
  public rows: VerificationRow[] = [];
  public invalidatedFor: string[] = [];
  invalidateOutstanding(phone: string): Promise<void> {
    this.invalidatedFor.push(phone);
    this.rows = this.rows.map((r) =>
      r.phone === phone && r.consumed_at === null
        ? { ...r, consumed_at: new Date().toISOString() }
        : r
    );
    return Promise.resolve();
  }
  insert(row: { phone: string; code_hash: string; requested_by: string; max_attempts: number; expires_at: string; request_ip: string }): Promise<string> {
    const id = `id-${this.rows.length}`;
    this.rows.push({ id, phone: row.phone, code_hash: row.code_hash, requested_by: row.requested_by, attempts: 0, max_attempts: row.max_attempts, expires_at: row.expires_at, consumed_at: null });
    return Promise.resolve(id);
  }
  latestUnconsumed(): Promise<VerificationRow | null> { return Promise.resolve(null); }
  incrementAttempts(): Promise<number> { return Promise.resolve(1); }
  consume(): Promise<void> { return Promise.resolve(); }
  markPhoneVerified(): Promise<boolean> { return Promise.resolve(true); }
}

class CapturingGateway implements SmsGateway {
  public sent: { phone: string; text: string }[] = [];
  send(phone: string, text: string): Promise<void> {
    this.sent.push({ phone, text });
    return Promise.resolve();
  }
}

function deps(over: Partial<Parameters<typeof handleRequestCode>[3]> = {}) {
  return {
    rateLimitStore: new FakeRate(),
    verificationStore: new FakeVerStore(),
    gateway: new CapturingGateway(),
    allowlist: new Set<string>(),
    pepper: PEPPER,
    makeCode: () => "246810",
    ...over,
  };
}

Deno.test("valid phone -> 200 uniform, code stored as HASH (not plaintext), SMS sent", async () => {
  const d = deps();
  const res = await handleRequestCode(USER, "010-1234-5678", "1.2.3.4", d);
  assertEquals(res.status, 200);
  assertEquals(res.body, { ok: true, ttlSeconds: 180 });

  const store = d.verificationStore as FakeVerStore;
  assertEquals(store.rows.length, 1);
  // Stored value must be the HMAC hash, never the plaintext "246810".
  assert(store.rows[0].code_hash !== "246810");
  assertEquals(store.rows[0].code_hash, await hashCode("246810", PEPPER));

  const gw = d.gateway as CapturingGateway;
  assertEquals(gw.sent.length, 1);
  assert(gw.sent[0].text.includes("246810"));
  assertEquals(gw.sent[0].phone, "+821012345678");
});

Deno.test("invalid phone -> uniform 200, NO send (anti-enumeration)", async () => {
  const d = deps();
  const res = await handleRequestCode(USER, "02-123-4567", "1.2.3.4", d);
  assertEquals(res.status, 200);
  assertEquals(res.body, { ok: true, ttlSeconds: 180 });
  assertEquals((d.gateway as CapturingGateway).sent.length, 0);
  assertEquals((d.verificationStore as FakeVerStore).rows.length, 0);
});

Deno.test("not on allowlist -> uniform 200, NO send", async () => {
  const d = deps({ allowlist: new Set(["+829999990000"]) });
  const res = await handleRequestCode(USER, "010-1234-5678", "1.2.3.4", d);
  assertEquals(res.status, 200);
  assertEquals(res.body, { ok: true, ttlSeconds: 180 });
  assertEquals((d.gateway as CapturingGateway).sent.length, 0);
});

Deno.test("rate limit second request -> 429 with retryAfter", async () => {
  const d = deps();
  const first = await handleRequestCode(USER, "010-1234-5678", "1.2.3.4", d);
  assertEquals(first.status, 200);
  const second = await handleRequestCode(USER, "010-1234-5678", "1.2.3.4", d);
  assertEquals(second.status, 429);
  assert("retryAfter" in second.body && second.body.retryAfter > 0);
});

Deno.test("new code invalidates prior outstanding code (single active code)", async () => {
  const d = deps();
  await handleRequestCode(USER, "010-1234-5678", "1.2.3.4", d);
  const store = d.verificationStore as FakeVerStore;
  assert(store.invalidatedFor.includes("+821012345678"));
});

Deno.test("issued code is bound to the requesting user (requested_by)", async () => {
  const d = deps();
  await handleRequestCode("user-42", "010-1234-5678", "1.2.3.4", d);
  const store = d.verificationStore as FakeVerStore;
  assertEquals(store.rows.length, 1);
  assertEquals(store.rows[0].requested_by, "user-42");
});

Deno.test("gateway failure still returns uniform 200 (no leak)", async () => {
  const failing: SmsGateway = { send: () => Promise.reject(new Error("boom")) };
  const d = deps({ gateway: failing });
  const res = await handleRequestCode(USER, "010-1234-5678", "1.2.3.4", d);
  assertEquals(res.status, 200);
  assertEquals(res.body, { ok: true, ttlSeconds: 180 });
});
