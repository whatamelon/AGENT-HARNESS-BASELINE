// sms-verify-code/core.test.ts — verify-flow behaviors via injected fakes.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleVerifyCode } from "./core.ts";
import { hashCode } from "../_shared/code.ts";
import type { VerificationStore, VerificationRow } from "../_shared/store.ts";

const PEPPER = "test-pepper";
const USER = "user-1";
const PHONE = "+821012345678";

interface FakeOpts {
  expiresInMs?: number;
  attempts?: number;
  maxAttempts?: number;
  code?: string;
  noRow?: boolean;
  /** Who the stored code is bound to (defaults to USER). */
  requestedBy?: string;
  /** When true, markPhoneVerified simulates a uq_profiles_phone_verified clash. */
  phoneTakenByOther?: boolean;
}

class FakeVerStore implements VerificationStore {
  public consumed: string[] = [];
  public verified: { userId: string; phone: string } | null = null;
  /** Number of times incrementAttempts was invoked (owner-lockout guard test). */
  public incrementCalls = 0;
  private row: VerificationRow | null = null;
  private attempts: number;

  constructor(private opts: FakeOpts, codeHash: string) {
    this.attempts = opts.attempts ?? 0;
    if (!opts.noRow) {
      this.row = {
        id: "row-1",
        phone: PHONE,
        code_hash: codeHash,
        requested_by: opts.requestedBy ?? USER,
        attempts: this.attempts,
        max_attempts: opts.maxAttempts ?? 5,
        expires_at: new Date(Date.now() + (opts.expiresInMs ?? 180_000)).toISOString(),
        consumed_at: null,
      };
    }
  }
  invalidateOutstanding(): Promise<void> { return Promise.resolve(); }
  insert(): Promise<string> { return Promise.resolve("x"); }
  latestUnconsumed(): Promise<VerificationRow | null> { return Promise.resolve(this.row); }
  incrementAttempts(): Promise<number> {
    this.incrementCalls += 1;
    this.attempts += 1;
    return Promise.resolve(this.attempts);
  }
  consume(id: string): Promise<void> { this.consumed.push(id); return Promise.resolve(); }
  markPhoneVerified(userId: string, phone: string): Promise<boolean> {
    if (this.opts.phoneTakenByOther) return Promise.resolve(false);
    this.verified = { userId, phone };
    return Promise.resolve(true);
  }
}

async function makeStore(opts: FakeOpts): Promise<FakeVerStore> {
  const codeHash = await hashCode(opts.code ?? "246810", PEPPER);
  return new FakeVerStore(opts, codeHash);
}

Deno.test("correct code -> verified:true, consumed, profile flagged (H-6 server write)", async () => {
  const store = await makeStore({ code: "246810" });
  const res = await handleVerifyCode(USER, PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 200);
  assertEquals(res.body, { verified: true });
  assertEquals(store.consumed, ["row-1"]);
  assertEquals(store.verified, { userId: USER, phone: PHONE });
});

Deno.test("wrong code -> verified:false reason invalid, NOT verified", async () => {
  const store = await makeStore({ code: "246810" });
  const res = await handleVerifyCode(USER, PHONE, "000000", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 400);
  assertEquals(res.body, { verified: false, reason: "invalid" });
  assertEquals(store.verified, null);
});

Deno.test("expired code -> reason expired", async () => {
  const store = await makeStore({ code: "246810", expiresInMs: -1000 });
  const res = await handleVerifyCode(USER, PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 400);
  assertEquals(res.body, { verified: false, reason: "expired" });
});

Deno.test("no outstanding code -> reason expired", async () => {
  const store = await makeStore({ noRow: true });
  const res = await handleVerifyCode(USER, PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.body, { verified: false, reason: "expired" });
});

Deno.test("attempt cap: 6th attempt (max 5) -> too_many_attempts + code burned", async () => {
  // attempts already at 5; incrementAttempts -> 6 > max(5).
  const store = await makeStore({ code: "246810", attempts: 5, maxAttempts: 5 });
  const res = await handleVerifyCode(USER, PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 400);
  assertEquals(res.body, { verified: false, reason: "too_many_attempts" });
  assertEquals(store.consumed, ["row-1"]); // burned on lockout
  assertEquals(store.verified, null);      // never verified even if code matched
});

Deno.test("invalid phone -> reason invalid", async () => {
  const store = await makeStore({ code: "246810" });
  const res = await handleVerifyCode(USER, "02-123-4567", "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.body, { verified: false, reason: "invalid" });
});

Deno.test("takeover: code requested by another user -> invalid, attempts NOT touched, not verified", async () => {
  // Code is bound to "owner-user"; a different authenticated user presents the
  // correct code. Must fail as `invalid` WITHOUT consuming the owner's attempts.
  const store = await makeStore({ code: "246810", requestedBy: "owner-user" });
  const res = await handleVerifyCode("attacker-user", PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 400);
  assertEquals(res.body, { verified: false, reason: "invalid" });
  assertEquals(store.verified, null);          // never bound to the attacker
  assertEquals(store.incrementCalls, 0);        // owner is not locked out
  assertEquals(store.consumed, []);             // owner's code not burned
});

Deno.test("takeover: same user that requested the code can verify it", async () => {
  const store = await makeStore({ code: "246810", requestedBy: "owner-user" });
  const res = await handleVerifyCode("owner-user", PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 200);
  assertEquals(res.body, { verified: true });
  assertEquals(store.verified, { userId: "owner-user", phone: PHONE });
});

Deno.test("phone already verified on another account -> invalid (uq conflict), code still consumed", async () => {
  const store = await makeStore({ code: "246810", phoneTakenByOther: true });
  const res = await handleVerifyCode(USER, PHONE, "246810", "1.2.3.4", { verificationStore: store, pepper: PEPPER });
  assertEquals(res.status, 400);
  assertEquals(res.body, { verified: false, reason: "invalid" });
  assertEquals(store.verified, null);     // not bound to this user
  assertEquals(store.consumed, ["row-1"]); // single-use: code burned regardless
});
