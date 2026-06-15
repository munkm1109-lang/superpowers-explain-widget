import test from "node:test";
import assert from "node:assert/strict";
import { scrubSensitiveFields, createSentryHooks } from "../src/sentry.js";

test("scrubSensitiveFields removes local bridge data", () => {
  const input = {
    linkId: "widget-secret",
    connectPrompt: "Superpowers 위젯에 연결해줘: widget-secret",
    statePath: "C:\\Users\\me\\repo\\.superpowers-widget\\runtime\\states\\widget-secret.json",
    linkRequestPath: "/home/me/repo/.superpowers-widget/runtime/links/widget-secret.json",
    workspacePath: "/home/me/private-project",
    nested: {
      keep: "safe",
      widgetId: "widget-secret"
    }
  };
  assert.deepEqual(scrubSensitiveFields(input), {
    linkId: "[redacted]",
    connectPrompt: "[redacted]",
    statePath: "[redacted]",
    linkRequestPath: "[redacted]",
    workspacePath: "[redacted]",
    nested: {
      keep: "safe",
      widgetId: "[redacted]"
    }
  });
});

test("createSentryHooks is disabled without DSN", () => {
  const hooks = createSentryHooks({});
  assert.equal(hooks.enabled, false);
  assert.doesNotThrow(() => hooks.captureException(new Error("boom"), { linkId: "widget-secret" }));
});

test("createSentryHooks uses injected capture function when DSN exists", () => {
  const calls = [];
  const hooks = createSentryHooks({
    dsn: "https://example@sentry.invalid/1",
    capture: (error, context) => calls.push({ message: error.message, context })
  });
  hooks.captureException(new Error("boom"), { linkId: "widget-secret", safe: "ok" });
  assert.equal(hooks.enabled, true);
  assert.deepEqual(calls, [{ message: "boom", context: { linkId: "[redacted]", safe: "ok" } }]);
});
