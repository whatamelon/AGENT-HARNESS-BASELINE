// account-delete/audit.test.ts — masking never leaks raw email/IP/UA.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  buildAccountAuditEvent,
  maskEmail,
  maskIp,
  truncateUserAgent,
} from "./audit.ts";

Deno.test("maskEmail: keeps 2-char heads + TLD, redacts the rest", () => {
  assertEquals(maskEmail("john.doe@example.com"), "jo****@ex****.com");
  assertEquals(maskEmail("a@b.io"), "a****@b****.io");
  assertEquals(maskEmail("noatsign"), "****");
  assertEquals(maskEmail("@nolocal.com"), "****");
  assertEquals(maskEmail(undefined), undefined);
});

Deno.test("maskIp: drops last octet (v4) / tail (v6)", () => {
  assertEquals(maskIp("203.0.113.42"), "203.0.113.*");
  assert(maskIp("2001:db8:1234:5678::1").endsWith(":*"));
  assertEquals(maskIp(""), "(none)");
});

Deno.test("truncateUserAgent: caps at 80 chars", () => {
  assertEquals(truncateUserAgent("yipark/1.0"), "yipark/1.0");
  const long = "x".repeat(200);
  const out = truncateUserAgent(long)!;
  assert(out.length <= 81); // 80 + ellipsis
  assertEquals(truncateUserAgent(undefined), undefined);
});

Deno.test("buildAccountAuditEvent: never carries the raw email", () => {
  const ev = buildAccountAuditEvent({
    outcome: "deleted",
    userId: "user-1",
    email: "john.doe@example.com",
    ip: "203.0.113.42",
    userAgent: "yipark/1.0",
    softDeletedRows: 5,
    deviceTokensPurged: 2,
  });
  const serialized = JSON.stringify(ev);
  assert(!serialized.includes("john.doe"), "raw email local part leaked");
  assert(!serialized.includes("example.com"), "raw email domain leaked");
  assert(serialized.includes("jo****@ex****.com"));
  assertEquals(ev.action, "account_delete");
  assertEquals(ev.userId, "user-1");
});
