// hardening_test.ts — pure tests for app-token / rate-limit / diagnostics helpers.
// No network, no server import (index.ts starts a server on import). Run: `deno test`.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  clientKey,
  InMemoryRateLimiter,
  resolveEnv,
  shouldIncludeDiagnostics,
  validateAppToken,
} from "./hardening.ts";

Deno.test("validateAppToken: unconfigured when no env token", () => {
  assertEquals(validateAppToken(undefined, "anything"), "unconfigured");
  assertEquals(validateAppToken("", "anything"), "unconfigured");
  assertEquals(validateAppToken("   ", "anything"), "unconfigured");
});

Deno.test("validateAppToken: missing header when configured", () => {
  assertEquals(validateAppToken("secret-abc", null), "missing");
  assertEquals(validateAppToken("secret-abc", ""), "missing");
  assertEquals(validateAppToken("secret-abc", "   "), "missing");
});

Deno.test("validateAppToken: invalid vs ok", () => {
  assertEquals(validateAppToken("secret-abc", "wrong"), "invalid");
  assertEquals(validateAppToken("secret-abc", "secret-abcd"), "invalid"); // length differs
  assertEquals(validateAppToken("secret-abc", "secret-abc"), "ok");
  assertEquals(validateAppToken("secret-abc", "  secret-abc  "), "ok"); // trimmed
});

Deno.test("validateAppToken returns only enum values (never echoes token)", () => {
  const allowed = new Set(["ok", "missing", "invalid", "unconfigured"]);
  for (const [exp, got] of [["t", "t"], ["t", "x"], ["t", ""], ["", "x"]] as const) {
    assert(allowed.has(validateAppToken(exp, got)));
  }
});

Deno.test("resolveEnv + shouldIncludeDiagnostics", () => {
  assertEquals(resolveEnv("production"), "production");
  assertEquals(resolveEnv("PRODUCTION"), "production");
  assertEquals(resolveEnv("development"), "development");
  assertEquals(resolveEnv(undefined), "development"); // default
  assertEquals(resolveEnv("anything-else"), "development");
  assertEquals(shouldIncludeDiagnostics("development"), true);
  assertEquals(shouldIncludeDiagnostics("production"), false);
});

Deno.test("InMemoryRateLimiter: allows under limit, 429 over, resets after window", () => {
  const rl = new InMemoryRateLimiter(3, 1000);
  const t = 10_000;
  assertEquals(rl.check("a", t).allowed, true); // 1
  assertEquals(rl.check("a", t).allowed, true); // 2
  const third = rl.check("a", t); // 3
  assertEquals(third.allowed, true);
  assertEquals(third.remaining, 0);
  const fourth = rl.check("a", t); // 4 → over
  assertEquals(fourth.allowed, false);
  assertEquals(fourth.limit, 3);
  assert(fourth.retryAfterSeconds >= 1);
  // a different key is independent
  assertEquals(rl.check("b", t).allowed, true);
  // after the window elapses, key "a" is allowed again
  assertEquals(rl.check("a", t + 1001).allowed, true);
});

Deno.test("clientKey extracts first forwarded IP, else fallbacks", () => {
  assertEquals(clientKey(new Headers({ "x-forwarded-for": "1.2.3.4, 5.6.7.8" })), "1.2.3.4");
  assertEquals(clientKey(new Headers({ "x-real-ip": "9.9.9.9" })), "9.9.9.9");
  assertEquals(clientKey(new Headers()), "unknown");
});
