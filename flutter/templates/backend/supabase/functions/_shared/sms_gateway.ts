// _shared/sms_gateway.ts
//
// SMS gateway adapter abstraction (§8-A C-1 / H-4).
//
// SECURITY: NO API keys, tokens, or secrets appear in this file. Every adapter
// reads its credentials from the Edge runtime environment ONLY
// (`Deno.env.get(...)`). The placeholders below are env-var NAMES, not values.
//
// Provider note: for production prefer KakaoTalk 알림톡 (AlimTalk) templates over
// raw SMS — higher deliverability, lower spam risk, and a pre-approved template
// avoids per-message content review. Both Solapi and Aligo expose AlimTalk; the
// adapters here send plain SMS as the lowest-common-denominator fallback and
// document where to switch the endpoint/payload to an AlimTalk template.

/** A pluggable SMS sender. Handlers depend on this interface, not a provider. */
export interface SmsGateway {
  /**
   * Deliver `text` to `phone` (E.164). Resolves on accepted-for-delivery;
   * throws on transport/auth failure so the caller can audit-log and decide
   * whether to surface a uniform success (anti-enumeration) regardless.
   */
  send(phone: string, text: string): Promise<void>;
}

/** Read a required env var or throw (fail-closed: never send without creds). */
function requireEnv(name: string): string {
  // `Deno` is the Supabase Edge runtime global. Typed loosely to keep this file
  // runtime-portable for off-edge unit imports (the adapters are not exercised
  // in pure-logic tests; the NoopGateway is used there instead).
  const env = (globalThis as { Deno?: { env: { get(k: string): string | undefined } } }).Deno?.env;
  const value = env?.get(name);
  if (!value) {
    throw new Error(`sms_gateway: missing required env ${name}`);
  }
  return value;
}

/**
 * Solapi (CoolSMS) adapter.
 *
 * Env (set in Supabase Edge function secrets — values NEVER in code):
 *   - SOLAPI_API_KEY
 *   - SOLAPI_API_SECRET
 *   - SMS_SENDER_NUMBER   (registered, pre-approved sender)
 *
 * Auth: Solapi uses HMAC over `date + salt` with the API secret (computed at
 * call time from env). To switch to AlimTalk, POST to the messages endpoint
 * with `type: "ATA"` + `kakaoOptions.templateId` instead of `type: "SMS"`.
 */
export class SolapiGateway implements SmsGateway {
  async send(phone: string, text: string): Promise<void> {
    const apiKey = requireEnv("SOLAPI_API_KEY");
    const apiSecret = requireEnv("SOLAPI_API_SECRET");
    const from = requireEnv("SMS_SENDER_NUMBER");

    const date = new Date().toISOString();
    const salt = crypto.randomUUID();
    const signature = await hmacHex(apiSecret, `${date}${salt}`);
    const authorization =
      `HMAC-SHA256 apiKey=${apiKey}, date=${date}, salt=${salt}, signature=${signature}`;

    const res = await fetch("https://api.solapi.com/messages/v4/send", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: authorization,
      },
      body: JSON.stringify({
        message: {
          to: phone.replace(/^\+82/, "0"), // domestic dialable form
          from,
          text,
          type: "SMS", // switch to "ATA" + kakaoOptions.templateId for AlimTalk
        },
      }),
    });

    if (!res.ok) {
      throw new Error(`SolapiGateway: send failed (${res.status})`);
    }
  }
}

/**
 * Aligo adapter.
 *
 * Env (Supabase Edge secrets — values NEVER in code):
 *   - ALIGO_API_KEY
 *   - ALIGO_USER_ID
 *   - SMS_SENDER_NUMBER
 *
 * Aligo posts form-encoded credentials per request. For AlimTalk use Aligo's
 * `/akv10/alimtalk/send/` endpoint with `tpl_code` instead of `/send/`.
 */
export class AligoGateway implements SmsGateway {
  async send(phone: string, text: string): Promise<void> {
    const apiKey = requireEnv("ALIGO_API_KEY");
    const userId = requireEnv("ALIGO_USER_ID");
    const sender = requireEnv("SMS_SENDER_NUMBER");

    const form = new URLSearchParams({
      key: apiKey,
      user_id: userId,
      sender,
      receiver: phone.replace(/^\+82/, "0"),
      msg: text,
    });

    const res = await fetch("https://apis.aligo.in/send/", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    });

    if (!res.ok) {
      throw new Error(`AligoGateway: send failed (${res.status})`);
    }
  }
}

/**
 * No-op gateway for local/dev and pure-logic tests. Never contacts a provider;
 * records the last message for assertions. NEVER select this in production —
 * `selectGateway` guards against it.
 */
export class NoopGateway implements SmsGateway {
  public lastPhone: string | null = null;
  public lastText: string | null = null;
  send(phone: string, text: string): Promise<void> {
    this.lastPhone = phone;
    this.lastText = text;
    return Promise.resolve();
  }
}

/**
 * Choose the gateway from `SMS_PROVIDER` env (`solapi` | `aligo` | `noop`).
 * `noop` is permitted only when `SMS_ALLOW_NOOP=1` (dev guard) so production
 * cannot silently drop codes.
 */
export function selectGateway(
  provider: string | undefined,
  allowNoop: boolean,
): SmsGateway {
  switch ((provider ?? "").toLowerCase()) {
    case "solapi":
      return new SolapiGateway();
    case "aligo":
      return new AligoGateway();
    case "noop":
      if (!allowNoop) {
        throw new Error("selectGateway: noop gateway requires SMS_ALLOW_NOOP=1");
      }
      return new NoopGateway();
    default:
      throw new Error(`selectGateway: unknown SMS_PROVIDER '${provider}'`);
  }
}

/** HMAC-SHA256 hex helper for provider auth (secret comes from env at call site). */
async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  const view = new Uint8Array(sig);
  let out = "";
  for (let i = 0; i < view.length; i++) out += view[i].toString(16).padStart(2, "0");
  return out;
}
