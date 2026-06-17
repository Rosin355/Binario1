// hardening.ts — pure helpers for Hardening Phase 1 of the `board` Edge Function:
// lightweight app-token validation, best-effort in-memory rate limiting, and an
// environment flag gating diagnostics. Pure (no Deno APIs, `now` passed in) so they
// are unit-testable with `deno test` and never call the network.
//
// SECURITY NOTE: the app token is a lightweight ABUSE-REDUCTION measure, not real
// security — a token shipped in a mobile app can be extracted. It is NOT user auth
// and NOT equivalent to a Supabase service_role key.

export type AppEnv = "development" | "production";

export function resolveEnv(raw: string | null | undefined): AppEnv {
  return (raw ?? "").trim().toLowerCase() === "production" ? "production" : "development";
}

/** Diagnostics are exposed only in development; reduced/omitted in production. */
export function shouldIncludeDiagnostics(env: AppEnv): boolean {
  return env === "development";
}

export type TokenResult = "ok" | "missing" | "invalid" | "unconfigured";

/**
 * Validate the incoming `X-Binario-App-Token` against the configured env token.
 * - env token empty/unset → "unconfigured" (caller decides: allow in dev, reject in prod)
 * - header empty/missing → "missing"
 * - mismatch → "invalid"
 * - match → "ok"
 * Never logs or echoes token values.
 */
export function validateAppToken(expected: string | null | undefined, provided: string | null | undefined): TokenResult {
  const exp = (expected ?? "").trim();
  if (exp.length === 0) return "unconfigured";
  const got = (provided ?? "").trim();
  if (got.length === 0) return "missing";
  return constantTimeEqual(exp, got) ? "ok" : "invalid";
}

/** Constant-time-ish byte compare (length may leak; acceptable for this measure). */
function constantTimeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const ab = enc.encode(a);
  const bb = enc.encode(b);
  if (ab.length !== bb.length) return false;
  let diff = 0;
  for (let i = 0; i < ab.length; i++) diff |= ab[i] ^ bb[i];
  return diff === 0;
}

export interface RateLimitResult {
  allowed: boolean;
  limit: number;
  remaining: number;
  retryAfterSeconds: number;
}

/**
 * Best-effort in-memory fixed-window rate limiter, keyed by approximate client id.
 * NOTE: per warm edge instance only — NOT globally reliable across instances.
 * TODO(prod): replace with a shared/distributed limiter (Upstash/Redis or
 * Supabase-backed) for correct global limits.
 */
export class InMemoryRateLimiter {
  private hits = new Map<string, number[]>();
  constructor(private readonly limit = 60, private readonly windowMs = 60_000) {}

  check(key: string, now: number): RateLimitResult {
    const windowStart = now - this.windowMs;
    const recent = (this.hits.get(key) ?? []).filter((t) => t > windowStart);
    if (recent.length >= this.limit) {
      const oldest = recent[0];
      const retryAfterSeconds = Math.max(1, Math.ceil((oldest + this.windowMs - now) / 1000));
      this.hits.set(key, recent);
      return { allowed: false, limit: this.limit, remaining: 0, retryAfterSeconds };
    }
    recent.push(now);
    this.hits.set(key, recent);
    return { allowed: true, limit: this.limit, remaining: Math.max(0, this.limit - recent.length), retryAfterSeconds: 0 };
  }
}

/** Approximate client key from proxy headers (best-effort; spoofable). */
export function clientKey(headers: Headers): string {
  const fwd = headers.get("x-forwarded-for");
  if (fwd) return fwd.split(",")[0].trim();
  return headers.get("cf-connecting-ip") ?? headers.get("x-real-ip") ?? "unknown";
}
