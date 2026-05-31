// _shared/audit.test.ts — masking never leaks raw phone/IP.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { buildAuditEvent, maskIp, maskPhone } from "./audit.ts";

Deno.test("maskPhone: redacts middle, keeps head + last 4", () => {
  assertEquals(maskPhone("+821012345678"), "+8210****5678");
  assertEquals(maskPhone("short"), "****");
  assertEquals(maskPhone(""), "(none)");
});

Deno.test("maskIp: drops last octet (v4) / tail (v6)", () => {
  assertEquals(maskIp("203.0.113.42"), "203.0.113.*");
  assert(maskIp("2001:db8:1234:5678::1").endsWith(":*"));
  assertEquals(maskIp(""), "(none)");
});

Deno.test("buildAuditEvent: never carries the raw phone", () => {
  const ev = buildAuditEvent({
    action: "sms_request_code",
    outcome: "sent",
    phone: "+821012345678",
    ip: "203.0.113.42",
  });
  const serialized = JSON.stringify(ev);
  assert(!serialized.includes("1012345678"), "raw phone leaked into audit event");
  assert(serialized.includes("+8210****5678"));
});
