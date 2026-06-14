const sensitiveKeys = new Set([
  "linkId",
  "widgetId",
  "connectPrompt",
  "statePath",
  "linkRequestPath",
  "workspacePath",
  "registryPath"
]);

export function scrubSensitiveFields(value) {
  if (Array.isArray(value)) {
    return value.map((item) => scrubSensitiveFields(item));
  }
  if (value && typeof value === "object") {
    const scrubbed = {};
    for (const [key, nestedValue] of Object.entries(value)) {
      scrubbed[key] = sensitiveKeys.has(key) ? "[redacted]" : scrubSensitiveFields(nestedValue);
    }
    return scrubbed;
  }
  return value;
}

export function createSentryHooks({ dsn = process.env.SENTRY_DSN, capture = null } = {}) {
  if (!dsn) {
    return {
      enabled: false,
      captureException() {}
    };
  }
  return {
    enabled: true,
    captureException(error, context = {}) {
      if (capture) {
        capture(error, scrubSensitiveFields(context));
      }
    }
  };
}
