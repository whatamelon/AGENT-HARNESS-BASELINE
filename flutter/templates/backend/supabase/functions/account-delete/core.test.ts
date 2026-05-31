// account-delete/core.test.ts — deletion behaviors via injected fakes.
//
// Covers: happy-path full delete, self-only authorization (forbidden), the two
// idempotency paths (user already gone up front, and a concurrent winner that
// removes the user between exists-check and delete), the order-of-operations
// invariant (domain scrub + token purge run BEFORE the auth delete), and the
// error path (a throwing step never removes the auth user and reports
// server_error).

import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { handleDeleteAccount } from "./core.ts";
import type { AccountDeletionStore } from "./store.ts";

const USER = "user-1";

interface FakeOpts {
  /** Auth user exists at the first check (default true). */
  exists?: boolean;
  /** Rows the domain cascade reports soft-deleted (default 3). */
  softDeleted?: number;
  /** Device tokens purged (default 2). */
  tokens?: number;
  /**
   * deleteAuthUser return — true=removed, false=already gone (concurrent
   * winner). Default true.
   */
  deletedNow?: boolean;
  /** When set, the named step throws to exercise the error path. */
  throwOn?: "exists" | "soft" | "tokens" | "delete";
}

class FakeStore implements AccountDeletionStore {
  /** Ordered log of operations to assert order-of-operations. */
  public calls: string[] = [];
  constructor(private opts: FakeOpts) {}

  authUserExists(): Promise<boolean> {
    this.calls.push("exists");
    if (this.opts.throwOn === "exists") throw new Error("boom");
    return Promise.resolve(this.opts.exists ?? true);
  }
  softDeleteDomainData(): Promise<number> {
    this.calls.push("soft");
    if (this.opts.throwOn === "soft") throw new Error("boom");
    return Promise.resolve(this.opts.softDeleted ?? 3);
  }
  purgeDeviceTokens(): Promise<number> {
    this.calls.push("tokens");
    if (this.opts.throwOn === "tokens") throw new Error("boom");
    return Promise.resolve(this.opts.tokens ?? 2);
  }
  deleteAuthUser(): Promise<boolean> {
    this.calls.push("delete");
    if (this.opts.throwOn === "delete") throw new Error("boom");
    return Promise.resolve(this.opts.deletedNow ?? true);
  }
}

function ctx(over: Partial<{ callerId: string; targetId?: string }> = {}) {
  return {
    callerId: over.callerId ?? USER,
    targetId: "targetId" in over ? over.targetId : undefined,
    email: "john.doe@example.com",
    ip: "1.2.3.4",
    userAgent: "yipark/1.0 (iPhone)",
  };
}

Deno.test("happy path: existing user -> deleted, scrub+purge run before auth delete", async () => {
  const store = new FakeStore({});
  const res = await handleDeleteAccount(ctx(), { store });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "deleted" });
  // Order-of-operations invariant: identity removed LAST.
  assertEquals(store.calls, ["exists", "soft", "tokens", "delete"]);
});

Deno.test("self-only: targetId matching callerId is allowed", async () => {
  const store = new FakeStore({});
  const res = await handleDeleteAccount(ctx({ targetId: USER }), { store });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "deleted" });
});

Deno.test("self-only: targetId for ANOTHER user -> forbidden, nothing touched", async () => {
  const store = new FakeStore({});
  const res = await handleDeleteAccount(ctx({ callerId: USER, targetId: "other-user" }), { store });
  assertEquals(res.status, 403);
  assertEquals(res.body, { error: "forbidden" });
  assertEquals(store.calls, []); // no store call at all
});

Deno.test("idempotent: user already gone at first check -> already_deleted, no delete call", async () => {
  const store = new FakeStore({ exists: false });
  const res = await handleDeleteAccount(ctx(), { store });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "already_deleted" });
  // Only the existence probe ran; we never scrubbed or deleted.
  assertEquals(store.calls, ["exists"]);
});

Deno.test("idempotent: concurrent winner removed the user mid-flight -> already_deleted", async () => {
  // exists() saw the user, but deleteAuthUser() finds it already gone (false).
  const store = new FakeStore({ exists: true, deletedNow: false });
  const res = await handleDeleteAccount(ctx(), { store });
  assertEquals(res.status, 200);
  assertEquals(res.body, { status: "already_deleted" });
  assertEquals(store.calls, ["exists", "soft", "tokens", "delete"]);
});

Deno.test("error path: a throwing scrub step -> server_error and auth user NOT deleted", async () => {
  const store = new FakeStore({ throwOn: "soft" });
  const res = await handleDeleteAccount(ctx(), { store });
  assertEquals(res.status, 500);
  assertEquals(res.body, { error: "server_error" });
  // delete was never reached -> identity preserved, client may retry.
  assertEquals(store.calls, ["exists", "soft"]);
});

Deno.test("error path: a throwing auth delete -> server_error (retryable)", async () => {
  const store = new FakeStore({ throwOn: "delete" });
  const res = await handleDeleteAccount(ctx(), { store });
  assertEquals(res.status, 500);
  assertEquals(res.body, { error: "server_error" });
  assertEquals(store.calls, ["exists", "soft", "tokens", "delete"]);
});
