# Superpowers Web Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a cross-platform Node.js web widget that matches the current Windows widget behavior while preventing Windows/Web runtime file collisions.

**Architecture:** Keep static guide data in `.superpowers-widget/flow-guide.json`, split runtime link and state files by widget ID under `.superpowers-widget/runtime/`, and expose the web widget through a localhost-only Node server. The existing Windows WPF widget is migrated to the same widget-ID runtime model while retaining legacy read compatibility for `.superpowers-widget/link-request.json` and `.superpowers-widget/state.json`.

**Tech Stack:** Node.js built-ins (`http`, `fs/promises`, `path`, `crypto`, `node:test`), browser HTML/CSS/JavaScript, existing PowerShell/WPF script, local JSON files, optional Sentry design scaffold via `npx getdesign@latest add sentry`.

---

## File Structure

- Create: `web/package.json`
  - Defines Node scripts for starting and testing the web widget.

- Create: `web/server.js`
  - Starts the localhost HTTP server and serves static files plus `/api/*` endpoints.

- Create: `web/src/paths.js`
  - Resolves project root, `.superpowers-widget` paths, widget-specific runtime paths, and OS-specific registry paths.

- Create: `web/src/json-store.js`
  - Provides safe JSON read/write helpers with atomic writes.

- Create: `web/src/widget-runtime.js`
  - Creates widget IDs, link requests, state paths, status responses, disconnect behavior, and registry entries.

- Create: `web/src/sentry.js`
  - Provides disabled-by-default Sentry hooks and sensitive-field scrubbing.

- Create: `web/public/index.html`
  - Browser shell for the web widget.

- Create: `web/public/app.js`
  - Polls server APIs and renders guide/status/detail UI.

- Create: `web/public/styles.css`
  - Web widget styling matching the current dark compact UI.

- Create: `web/tests/*.test.js`
  - Node test coverage for paths, JSON store, runtime state separation, status modes, and Sentry scrubbing.

- Modify: `superpowers-widget.ps1`
  - Move Windows widget link/state creation to widget-ID-specific runtime files.
  - Keep legacy read compatibility.
  - Keep `-ConnectSession`, `-ConnectionStatus`, and `-SelfTest` working.

- Modify: `.gitignore`
  - Ensure runtime files and Node install artifacts are ignored.

- Modify: `README.md`
  - Document Windows and Web launch paths.
  - Explain widget-ID runtime files and simultaneous Windows/Web use.

---

### Task 1: Add Node Project Shell

**Files:**
- Create: `web/package.json`
- Modify: `.gitignore`

- [ ] **Step 1: Create `web/package.json`**

Create `web/package.json` with this content:

```json
{
  "name": "superpowers-explain-web-widget",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "test": "node --test tests/*.test.js"
  },
  "engines": {
    "node": ">=20"
  }
}
```

- [ ] **Step 2: Extend `.gitignore`**

Ensure `.gitignore` contains these lines:

```text
.superpowers-widget/link-request.json
.superpowers-widget/state.json
.superpowers-widget/runtime/
.superpowers/
web/node_modules/
web/.env
```

- [ ] **Step 3: Run package script discovery**

Run:

```powershell
npm --prefix web run
```

Expected output includes:

```text
Lifecycle scripts included in superpowers-explain-web-widget
  start
    node server.js
available via `npm run-script`:
  test
    node --test tests/*.test.js
```

- [ ] **Step 4: Commit**

Run:

```powershell
git add .gitignore web/package.json
git commit -m "Add the web widget Node project shell"
```

Do not push unless the user explicitly asks.

---

### Task 2: Implement Cross-Platform Runtime Paths

**Files:**
- Create: `web/src/paths.js`
- Create: `web/tests/paths.test.js`

- [ ] **Step 1: Write the failing path tests**

Create `web/tests/paths.test.js`:

```js
import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import {
  getProjectRoot,
  getWidgetDir,
  getRuntimePaths,
  getRegistryPathForPlatform
} from "../src/paths.js";

test("resolves project root from web directory", () => {
  const root = getProjectRoot();
  assert.equal(path.basename(root), "Superpowers_Expain_Widget");
});

test("resolves shared widget directory", () => {
  const root = getProjectRoot();
  assert.equal(getWidgetDir(root), path.join(root, ".superpowers-widget"));
});

test("resolves widget-specific runtime paths", () => {
  const root = "C:\\repo";
  const paths = getRuntimePaths(root, "widget-test-123");
  assert.equal(paths.linkId, "widget-test-123");
  assert.equal(paths.linkRequestPath, path.join(root, ".superpowers-widget", "runtime", "links", "widget-test-123.json"));
  assert.equal(paths.statePath, path.join(root, ".superpowers-widget", "runtime", "states", "widget-test-123.json"));
});

test("resolves registry paths by platform", () => {
  assert.equal(
    getRegistryPathForPlatform("win32", "C:\\Users\\me\\AppData\\Local", "widget-1"),
    path.join("C:\\Users\\me\\AppData\\Local", "SuperpowersExplainWidget", "links", "widget-1.json")
  );
  assert.equal(
    getRegistryPathForPlatform("linux", "/home/me/.local/state", "widget-1"),
    path.join("/home/me/.local/state", "superpowers-explain-widget", "links", "widget-1.json")
  );
  assert.equal(
    getRegistryPathForPlatform("darwin", "/Users/me/Library/Application Support", "widget-1"),
    path.join("/Users/me/Library/Application Support", "SuperpowersExplainWidget", "links", "widget-1.json")
  );
});
```

- [ ] **Step 2: Run the path tests to verify they fail**

Run:

```powershell
npm --prefix web test -- paths.test.js
```

Expected:

```text
ERR_MODULE_NOT_FOUND
```

- [ ] **Step 3: Create `web/src/paths.js`**

Create `web/src/paths.js`:

```js
import path from "node:path";
import { fileURLToPath } from "node:url";

const currentFile = fileURLToPath(import.meta.url);
const webSrcDir = path.dirname(currentFile);

export function getProjectRoot() {
  return path.resolve(webSrcDir, "..", "..");
}

export function getWidgetDir(projectRoot = getProjectRoot()) {
  return path.join(projectRoot, ".superpowers-widget");
}

export function sanitizeLinkId(linkId) {
  return String(linkId).replace(/[^a-zA-Z0-9_.-]/g, "_");
}

export function getRuntimePaths(projectRoot, linkId) {
  const safeLinkId = sanitizeLinkId(linkId);
  const widgetDir = getWidgetDir(projectRoot);
  const runtimeDir = path.join(widgetDir, "runtime");
  return {
    linkId: safeLinkId,
    widgetDir,
    runtimeDir,
    linksDir: path.join(runtimeDir, "links"),
    statesDir: path.join(runtimeDir, "states"),
    linkRequestPath: path.join(runtimeDir, "links", `${safeLinkId}.json`),
    statePath: path.join(runtimeDir, "states", `${safeLinkId}.json`),
    guidePath: path.join(widgetDir, "flow-guide.json"),
    legacyLinkRequestPath: path.join(widgetDir, "link-request.json"),
    legacyStatePath: path.join(widgetDir, "state.json")
  };
}

export function getRegistryRootForPlatform(platform = process.platform, env = process.env) {
  if (platform === "win32") {
    return path.join(env.LOCALAPPDATA || path.join(env.USERPROFILE || "", "AppData", "Local"), "SuperpowersExplainWidget");
  }
  if (platform === "darwin") {
    return path.join(env.HOME || "", "Library", "Application Support", "SuperpowersExplainWidget");
  }
  return path.join(env.XDG_STATE_HOME || path.join(env.HOME || "", ".local", "state"), "superpowers-explain-widget");
}

export function getRegistryPathForPlatform(platform, baseDir, linkId) {
  const safeLinkId = sanitizeLinkId(linkId);
  const registryRoot = platform === "linux"
    ? path.join(baseDir, "superpowers-explain-widget")
    : path.join(baseDir, "SuperpowersExplainWidget");
  return path.join(registryRoot, "links", `${safeLinkId}.json`);
}

export function getRegistryPath(linkId, platform = process.platform, env = process.env) {
  const registryRoot = getRegistryRootForPlatform(platform, env);
  return path.join(registryRoot, "links", `${sanitizeLinkId(linkId)}.json`);
}
```

- [ ] **Step 4: Run the path tests to verify they pass**

Run:

```powershell
npm --prefix web test -- paths.test.js
```

Expected:

```text
# pass 4
# fail 0
```

- [ ] **Step 5: Commit**

Run:

```powershell
git add web/src/paths.js web/tests/paths.test.js
git commit -m "Add cross-platform web widget runtime paths"
```

Do not push unless the user explicitly asks.

---

### Task 3: Implement JSON Store Helpers

**Files:**
- Create: `web/src/json-store.js`
- Create: `web/tests/json-store.test.js`

- [ ] **Step 1: Write failing JSON store tests**

Create `web/tests/json-store.test.js`:

```js
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { readJsonFile, writeJsonFile, removeFileIfExists } from "../src/json-store.js";

test("writeJsonFile creates parent directories and readJsonFile returns parsed data", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sp-json-"));
  const file = path.join(dir, "nested", "state.json");
  await writeJsonFile(file, { linkId: "widget-1", ok: true });
  assert.deepEqual(await readJsonFile(file), { linkId: "widget-1", ok: true });
});

test("readJsonFile returns null for missing optional files", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sp-json-"));
  assert.equal(await readJsonFile(path.join(dir, "missing.json")), null);
});

test("readJsonFile throws clear error for invalid JSON", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sp-json-"));
  const file = path.join(dir, "bad.json");
  await fs.writeFile(file, "{bad", "utf8");
  await assert.rejects(
    () => readJsonFile(file),
    /Invalid JSON/
  );
});

test("removeFileIfExists removes files and ignores missing files", async () => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), "sp-json-"));
  const file = path.join(dir, "delete.json");
  await writeJsonFile(file, { ok: true });
  await removeFileIfExists(file);
  assert.equal(await readJsonFile(file), null);
  await removeFileIfExists(file);
});
```

- [ ] **Step 2: Run JSON store tests to verify they fail**

Run:

```powershell
npm --prefix web test -- json-store.test.js
```

Expected:

```text
ERR_MODULE_NOT_FOUND
```

- [ ] **Step 3: Create `web/src/json-store.js`**

Create `web/src/json-store.js`:

```js
import fs from "node:fs/promises";
import path from "node:path";

export async function readJsonFile(filePath, { required = false } = {}) {
  try {
    const raw = await fs.readFile(filePath, "utf8");
    return JSON.parse(raw);
  } catch (error) {
    if (error.code === "ENOENT" && !required) {
      return null;
    }
    if (error instanceof SyntaxError) {
      throw new Error(`Invalid JSON in ${filePath}: ${error.message}`);
    }
    throw error;
  }
}

export async function writeJsonFile(filePath, value) {
  await fs.mkdir(path.dirname(filePath), { recursive: true });
  const tempPath = `${filePath}.${process.pid}.${Date.now()}.tmp`;
  const json = `${JSON.stringify(value, null, 2)}\n`;
  await fs.writeFile(tempPath, json, "utf8");
  await fs.rename(tempPath, filePath);
}

export async function removeFileIfExists(filePath) {
  try {
    await fs.unlink(filePath);
  } catch (error) {
    if (error.code !== "ENOENT") {
      throw error;
    }
  }
}
```

- [ ] **Step 4: Run JSON store tests to verify they pass**

Run:

```powershell
npm --prefix web test -- json-store.test.js
```

Expected:

```text
# pass 4
# fail 0
```

- [ ] **Step 5: Commit**

Run:

```powershell
git add web/src/json-store.js web/tests/json-store.test.js
git commit -m "Add JSON storage helpers for widget runtime files"
```

Do not push unless the user explicitly asks.

---

### Task 4: Implement Widget Runtime Logic

**Files:**
- Create: `web/src/widget-runtime.js`
- Create: `web/tests/widget-runtime.test.js`

- [ ] **Step 1: Write failing runtime tests**

Create `web/tests/widget-runtime.test.js`:

```js
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import {
  createWidgetRuntime,
  createLinkRequest,
  getStatus,
  disconnectWidget
} from "../src/widget-runtime.js";
import { readJsonFile, writeJsonFile } from "../src/json-store.js";

async function makeRoot() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "sp-runtime-"));
  await fs.mkdir(path.join(root, ".superpowers-widget"), { recursive: true });
  await writeJsonFile(path.join(root, ".superpowers-widget", "flow-guide.json"), {
    items: [
      {
        flow: "Brainstorming",
        situation: "뭘 해야 할지 모를 때",
        previousPlugin: "없음",
        nowAction: "현재 상황과 목표를 정리합니다.",
        reason: "다음 행동을 고르기 위해서입니다.",
        nextPlugin: "writing-plans"
      }
    ]
  });
  return root;
}

test("createLinkRequest writes widget-specific link and registry files", async () => {
  const root = await makeRoot();
  const registryRoot = path.join(root, "registry");
  const runtime = createWidgetRuntime({ projectRoot: root, linkId: "widget-web-1", registryRoot });
  const request = await createLinkRequest(runtime);
  assert.equal(request.linkId, "widget-web-1");
  assert.match(request.connectPrompt, /Superpowers 위젯에 연결해줘: widget-web-1/);
  assert.equal((await readJsonFile(runtime.paths.linkRequestPath)).linkId, "widget-web-1");
  assert.equal((await readJsonFile(runtime.registryPath)).statePath, runtime.paths.statePath);
});

test("getStatus returns Waiting before state exists", async () => {
  const root = await makeRoot();
  const runtime = createWidgetRuntime({ projectRoot: root, linkId: "widget-web-2", registryRoot: path.join(root, "registry") });
  await createLinkRequest(runtime);
  const status = await getStatus(runtime);
  assert.equal(status.Mode, "Waiting");
});

test("getStatus returns Linked with matching fresh state", async () => {
  const root = await makeRoot();
  const runtime = createWidgetRuntime({ projectRoot: root, linkId: "widget-web-3", registryRoot: path.join(root, "registry") });
  await createLinkRequest(runtime);
  const now = new Date();
  await writeJsonFile(runtime.paths.statePath, {
    linkId: "widget-web-3",
    currentFlow: "Brainstorming",
    updatedAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + 60 * 60 * 1000).toISOString()
  });
  const status = await getStatus(runtime);
  assert.equal(status.Mode, "Linked");
  assert.equal(status.State.currentFlow, "Brainstorming");
});

test("getStatus returns Stale for expired state", async () => {
  const root = await makeRoot();
  const runtime = createWidgetRuntime({ projectRoot: root, linkId: "widget-web-4", registryRoot: path.join(root, "registry") });
  await createLinkRequest(runtime);
  await writeJsonFile(runtime.paths.statePath, {
    linkId: "widget-web-4",
    currentFlow: "Brainstorming",
    updatedAt: new Date(Date.now() - 10 * 60 * 60 * 1000).toISOString(),
    expiresAt: new Date(Date.now() - 1000).toISOString()
  });
  const status = await getStatus(runtime);
  assert.equal(status.Mode, "Stale");
});

test("two widget IDs keep independent states", async () => {
  const root = await makeRoot();
  const registryRoot = path.join(root, "registry");
  const first = createWidgetRuntime({ projectRoot: root, linkId: "widget-first", registryRoot });
  const second = createWidgetRuntime({ projectRoot: root, linkId: "widget-second", registryRoot });
  await createLinkRequest(first);
  await createLinkRequest(second);
  await writeJsonFile(first.paths.statePath, { linkId: "widget-first", currentFlow: "Brainstorming", updatedAt: new Date().toISOString() });
  await writeJsonFile(second.paths.statePath, { linkId: "widget-second", currentFlow: "Writing Plans", updatedAt: new Date().toISOString() });
  assert.equal((await getStatus(first)).State.currentFlow, "Brainstorming");
  assert.equal((await getStatus(second)).State.currentFlow, "Writing Plans");
});

test("disconnectWidget removes only this widget state and link", async () => {
  const root = await makeRoot();
  const runtime = createWidgetRuntime({ projectRoot: root, linkId: "widget-web-5", registryRoot: path.join(root, "registry") });
  await createLinkRequest(runtime);
  await writeJsonFile(runtime.paths.statePath, { linkId: "widget-web-5", updatedAt: new Date().toISOString() });
  await disconnectWidget(runtime);
  assert.equal(await readJsonFile(runtime.paths.linkRequestPath), null);
  assert.equal(await readJsonFile(runtime.paths.statePath), null);
});
```

- [ ] **Step 2: Run runtime tests to verify they fail**

Run:

```powershell
npm --prefix web test -- widget-runtime.test.js
```

Expected:

```text
ERR_MODULE_NOT_FOUND
```

- [ ] **Step 3: Create `web/src/widget-runtime.js`**

Create `web/src/widget-runtime.js`:

```js
import crypto from "node:crypto";
import path from "node:path";
import { getProjectRoot, getRuntimePaths, getRegistryPath } from "./paths.js";
import { readJsonFile, writeJsonFile, removeFileIfExists } from "./json-store.js";

export function newWidgetId(prefix = "widget") {
  const now = new Date();
  const stamp = now.toISOString().replace(/[-:]/g, "").replace(/\..+/, "").replace("T", "-");
  return `${prefix}-${stamp}-${crypto.randomUUID().replace(/-/g, "").slice(0, 8)}`;
}

export function createWidgetRuntime({ projectRoot = getProjectRoot(), linkId = newWidgetId(), registryRoot = null } = {}) {
  const paths = getRuntimePaths(projectRoot, linkId);
  const registryPath = registryRoot
    ? path.join(registryRoot, "links", `${paths.linkId}.json`)
    : getRegistryPath(paths.linkId);
  return {
    projectRoot,
    linkId: paths.linkId,
    paths,
    registryPath
  };
}

export function getConnectPrompt(request) {
  return `Superpowers 위젯에 연결해줘: ${request.linkId}. 같은 사용자라면 ${request.registryPath} 를 읽고, 그 안의 statePath/linkRequestPath에 연결 상태를 써줘. 이 파일을 못 찾으면 connectCommand를 실행해줘.`;
}

export async function createLinkRequest(runtime) {
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 6 * 60 * 60 * 1000);
  const request = {
    linkId: runtime.linkId,
    workspacePath: runtime.projectRoot,
    requestedAt: now.toISOString(),
    expiresAt: expiresAt.toISOString(),
    statePath: runtime.paths.statePath,
    linkRequestPath: runtime.paths.linkRequestPath,
    registryPath: runtime.registryPath,
    connectCommand: `npm --prefix web start -- --link-id ${runtime.linkId}`,
    connectPrompt: ""
  };
  request.connectPrompt = getConnectPrompt(request);
  request.instruction = `Codex 세션에 "${request.connectPrompt}" 전체 문장을 알려주세요.`;
  await writeJsonFile(runtime.paths.linkRequestPath, request);
  await writeJsonFile(runtime.registryPath, request);
  return request;
}

function isFreshState(state) {
  if (!state || !state.updatedAt) {
    return false;
  }
  const updatedAt = new Date(state.updatedAt);
  if (Number.isNaN(updatedAt.getTime())) {
    return false;
  }
  const ageMs = Date.now() - updatedAt.getTime();
  if (ageMs > 6 * 60 * 60 * 1000) {
    return false;
  }
  if (state.expiresAt) {
    const expiresAt = new Date(state.expiresAt);
    if (!Number.isNaN(expiresAt.getTime()) && Date.now() > expiresAt.getTime()) {
      return false;
    }
  }
  return true;
}

export async function getStatus(runtime) {
  const linkRequest = await readJsonFile(runtime.paths.linkRequestPath);
  const state = await readJsonFile(runtime.paths.statePath);
  if (!linkRequest) {
    return {
      Mode: "Guide",
      Title: "안내 모드",
      Message: "아직 Codex 세션과 연결하지 않았습니다.",
      State: null,
      LinkRequest: null
    };
  }
  if (!state) {
    return {
      Mode: "Waiting",
      Title: "연결 대기 중",
      Message: "현재 Codex 세션에서 위젯 연결을 요청하세요.",
      State: null,
      LinkRequest: linkRequest
    };
  }
  const sameLink = String(state.linkId) === String(linkRequest.linkId);
  if (sameLink && isFreshState(state)) {
    return {
      Mode: "Linked",
      Title: "연결됨",
      Message: "Codex 세션과 연결되어 있습니다.",
      State: state,
      LinkRequest: linkRequest
    };
  }
  return {
    Mode: "Stale",
    Title: "재연결 필요",
    Message: "마지막 연결이 오래됐거나 현재 연결 요청과 일치하지 않습니다.",
    State: state,
    LinkRequest: linkRequest
  };
}

export async function disconnectWidget(runtime) {
  await removeFileIfExists(runtime.paths.statePath);
  await removeFileIfExists(runtime.paths.linkRequestPath);
  await removeFileIfExists(runtime.registryPath);
}
```

- [ ] **Step 4: Run runtime tests to verify they pass**

Run:

```powershell
npm --prefix web test -- widget-runtime.test.js
```

Expected:

```text
# pass 6
# fail 0
```

- [ ] **Step 5: Commit**

Run:

```powershell
git add web/src/widget-runtime.js web/tests/widget-runtime.test.js
git commit -m "Add widget-specific runtime state for the web widget"
```

Do not push unless the user explicitly asks.

---

### Task 5: Add Disabled-by-Default Sentry Hooks

**Files:**
- Create: `web/src/sentry.js`
- Create: `web/tests/sentry.test.js`
- Generated or modified by review: `DESIGN.md` or equivalent files from `npx getdesign@latest add sentry`

- [ ] **Step 1: Run getdesign Sentry scaffold and inspect the diff**

Run:

```powershell
npx getdesign@latest add sentry
git diff --stat
```

Expected:

```text
One or more design guidance files are added or modified.
No runtime dependency is installed by this command alone.
```

If the command changes files outside design guidance, stop and inspect before continuing.

- [ ] **Step 2: Write failing Sentry tests**

Create `web/tests/sentry.test.js`:

```js
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
```

- [ ] **Step 3: Run Sentry tests to verify they fail**

Run:

```powershell
npm --prefix web test -- sentry.test.js
```

Expected:

```text
ERR_MODULE_NOT_FOUND
```

- [ ] **Step 4: Create `web/src/sentry.js`**

Create `web/src/sentry.js`:

```js
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
```

- [ ] **Step 5: Run Sentry tests to verify they pass**

Run:

```powershell
npm --prefix web test -- sentry.test.js
```

Expected:

```text
# pass 3
# fail 0
```

- [ ] **Step 6: Commit**

Run:

```powershell
git add DESIGN.md web/src/sentry.js web/tests/sentry.test.js
git commit -m "Add optional Sentry-safe observability hooks"
```

If `npx getdesign@latest add sentry` created a different design file path, add that exact generated file instead of `DESIGN.md`.

Do not push unless the user explicitly asks.

---

### Task 6: Add Local Server API

**Files:**
- Create: `web/server.js`
- Create: `web/tests/server.test.js`

- [ ] **Step 1: Write failing server tests**

Create `web/tests/server.test.js`:

```js
import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { startServer } from "../server.js";
import { writeJsonFile } from "../src/json-store.js";

async function makeRoot() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "sp-server-"));
  await fs.mkdir(path.join(root, ".superpowers-widget"), { recursive: true });
  await writeJsonFile(path.join(root, ".superpowers-widget", "flow-guide.json"), {
    items: [
      {
        flow: "Brainstorming",
        situation: "뭘 해야 할지 모를 때",
        previousPlugin: "없음",
        nowAction: "현재 상황과 목표를 정리합니다.",
        reason: "다음 행동을 고르기 위해서입니다.",
        nextPlugin: "writing-plans"
      }
    ]
  });
  return root;
}

async function withServer(callback) {
  const root = await makeRoot();
  const server = await startServer({ projectRoot: root, port: 0, linkId: "widget-api-test", openBrowser: false });
  try {
    await callback({ root, baseUrl: `http://127.0.0.1:${server.port}`, runtime: server.runtime });
  } finally {
    await server.close();
  }
}

test("GET /api/health returns ok", async () => {
  await withServer(async ({ baseUrl }) => {
    const response = await fetch(`${baseUrl}/api/health`);
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), { ok: true });
  });
});

test("GET /api/guide returns guide data", async () => {
  await withServer(async ({ baseUrl }) => {
    const response = await fetch(`${baseUrl}/api/guide`);
    const body = await response.json();
    assert.equal(body.items[0].flow, "Brainstorming");
  });
});

test("POST /api/link-request creates waiting status", async () => {
  await withServer(async ({ baseUrl }) => {
    const linkResponse = await fetch(`${baseUrl}/api/link-request`, { method: "POST" });
    const linkBody = await linkResponse.json();
    assert.equal(linkBody.linkId, "widget-api-test");
    const statusResponse = await fetch(`${baseUrl}/api/status`);
    const statusBody = await statusResponse.json();
    assert.equal(statusBody.Mode, "Waiting");
  });
});

test("POST /api/disconnect clears this widget", async () => {
  await withServer(async ({ baseUrl }) => {
    await fetch(`${baseUrl}/api/link-request`, { method: "POST" });
    const response = await fetch(`${baseUrl}/api/disconnect`, { method: "POST" });
    assert.equal(response.status, 200);
    const status = await (await fetch(`${baseUrl}/api/status`)).json();
    assert.equal(status.Mode, "Guide");
  });
});
```

- [ ] **Step 2: Run server tests to verify they fail**

Run:

```powershell
npm --prefix web test -- server.test.js
```

Expected:

```text
ERR_MODULE_NOT_FOUND
```

- [ ] **Step 3: Create `web/server.js`**

Create `web/server.js`:

```js
import http from "node:http";
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createWidgetRuntime, createLinkRequest, getStatus, disconnectWidget, newWidgetId } from "./src/widget-runtime.js";
import { readJsonFile } from "./src/json-store.js";
import { getProjectRoot } from "./src/paths.js";
import { createSentryHooks } from "./src/sentry.js";

const publicDir = path.join(path.dirname(fileURLToPath(import.meta.url)), "public");

function jsonResponse(response, status, body) {
  response.writeHead(status, { "content-type": "application/json; charset=utf-8" });
  response.end(JSON.stringify(body));
}

async function staticResponse(response, requestPath) {
  const relativePath = requestPath === "/" ? "index.html" : requestPath.slice(1);
  const filePath = path.join(publicDir, relativePath);
  if (!filePath.startsWith(publicDir)) {
    response.writeHead(403);
    response.end("Forbidden");
    return;
  }
  const data = await fs.readFile(filePath);
  const ext = path.extname(filePath);
  const type = ext === ".css" ? "text/css; charset=utf-8" : ext === ".js" ? "text/javascript; charset=utf-8" : "text/html; charset=utf-8";
  response.writeHead(200, { "content-type": type });
  response.end(data);
}

export async function startServer({ projectRoot = getProjectRoot(), port = 43821, linkId = newWidgetId("widget-web"), openBrowser = false } = {}) {
  const runtime = createWidgetRuntime({ projectRoot, linkId });
  const sentry = createSentryHooks();
  const server = http.createServer(async (request, response) => {
    try {
      const url = new URL(request.url, "http://127.0.0.1");
      if (request.method === "GET" && url.pathname === "/api/health") {
        jsonResponse(response, 200, { ok: true });
        return;
      }
      if (request.method === "GET" && url.pathname === "/api/guide") {
        jsonResponse(response, 200, await readJsonFile(runtime.paths.guidePath, { required: true }));
        return;
      }
      if (request.method === "GET" && url.pathname === "/api/status") {
        jsonResponse(response, 200, await getStatus(runtime));
        return;
      }
      if (request.method === "POST" && url.pathname === "/api/link-request") {
        jsonResponse(response, 200, await createLinkRequest(runtime));
        return;
      }
      if (request.method === "POST" && url.pathname === "/api/disconnect") {
        await disconnectWidget(runtime);
        jsonResponse(response, 200, { ok: true });
        return;
      }
      if (request.method === "GET") {
        await staticResponse(response, url.pathname);
        return;
      }
      jsonResponse(response, 404, { error: "Not found" });
    } catch (error) {
      sentry.captureException(error, { url: request.url, linkId: runtime.linkId });
      jsonResponse(response, 500, { error: "상태 파일을 읽을 수 없습니다" });
    }
  });

  await new Promise((resolve) => server.listen(port, "127.0.0.1", resolve));
  const address = server.address();
  const actualPort = typeof address === "object" && address ? address.port : port;
  if (openBrowser) {
    console.log(`Open http://127.0.0.1:${actualPort}`);
  }
  return {
    port: actualPort,
    runtime,
    close: () => new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()))
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const linkArgIndex = process.argv.indexOf("--link-id");
  const portArgIndex = process.argv.indexOf("--port");
  const linkId = linkArgIndex >= 0 ? process.argv[linkArgIndex + 1] : undefined;
  const port = portArgIndex >= 0 ? Number(process.argv[portArgIndex + 1]) : 43821;
  const server = await startServer({ linkId, port, openBrowser: true });
  console.log(`Superpowers web widget running at http://127.0.0.1:${server.port}`);
}
```

- [ ] **Step 4: Run server tests to verify they pass**

Run:

```powershell
npm --prefix web test -- server.test.js
```

Expected:

```text
# pass 4
# fail 0
```

- [ ] **Step 5: Commit**

Run:

```powershell
git add web/server.js web/tests/server.test.js
git commit -m "Add local API server for the web widget"
```

Do not push unless the user explicitly asks.

---

### Task 7: Build the Browser UI

**Files:**
- Create: `web/public/index.html`
- Create: `web/public/app.js`
- Create: `web/public/styles.css`

- [ ] **Step 1: Create `web/public/index.html`**

Create `web/public/index.html`:

```html
<!doctype html>
<html lang="ko">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Superpowers Web Widget</title>
    <link rel="stylesheet" href="/styles.css">
  </head>
  <body>
    <main class="shell">
      <header class="header">
        <div>
          <h1>Superpowers</h1>
          <p id="status-message">현재 흐름과 다음 플러그인을 빠르게 확인합니다.</p>
        </div>
        <div id="status-pill" class="pill">안내 모드</div>
      </header>

      <section class="connect-panel">
        <div>
          <h2 id="connect-title">연결 상태</h2>
          <p id="connect-detail">Codex 세션 연결 요청을 만들 수 있습니다.</p>
        </div>
        <div class="connect-actions">
          <button id="connect-button" type="button">Codex 세션 연결 요청</button>
          <button id="disconnect-button" type="button">세션 해제</button>
        </div>
        <div id="copy-row" class="copy-row hidden">
          <input id="connect-prompt" readonly>
          <button id="copy-button" type="button">문장 복사</button>
        </div>
      </section>

      <section id="flow-status" class="flow-status hidden">
        <span id="current-flow">Flow: -</span>
        <span id="next-flow">Next: -</span>
      </section>

      <section class="content-grid">
        <section class="flow-list-panel">
          <div class="panel-heading">
            <h2>Flows</h2>
            <span id="flow-count">0 items</span>
          </div>
          <div id="flow-list" class="flow-list"></div>
        </section>

        <section class="detail-panel">
          <div class="panel-heading">
            <h2>상세</h2>
            <span id="detail-flow" class="pill">-</span>
          </div>
          <div id="detail-body"></div>
        </section>
      </section>
    </main>
    <script src="/app.js" type="module"></script>
  </body>
</html>
```

- [ ] **Step 2: Create `web/public/app.js`**

Create `web/public/app.js`:

```js
const state = {
  guide: [],
  selectedIndex: 0,
  status: null,
  previousAction: "",
  previousReason: ""
};

const elements = {
  statusMessage: document.querySelector("#status-message"),
  statusPill: document.querySelector("#status-pill"),
  connectTitle: document.querySelector("#connect-title"),
  connectDetail: document.querySelector("#connect-detail"),
  connectButton: document.querySelector("#connect-button"),
  disconnectButton: document.querySelector("#disconnect-button"),
  copyRow: document.querySelector("#copy-row"),
  connectPrompt: document.querySelector("#connect-prompt"),
  copyButton: document.querySelector("#copy-button"),
  flowStatus: document.querySelector("#flow-status"),
  currentFlow: document.querySelector("#current-flow"),
  nextFlow: document.querySelector("#next-flow"),
  flowCount: document.querySelector("#flow-count"),
  flowList: document.querySelector("#flow-list"),
  detailFlow: document.querySelector("#detail-flow"),
  detailBody: document.querySelector("#detail-body")
};

function flowKey(value) {
  return String(value || "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}

async function fetchJson(url, options) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`Request failed: ${response.status}`);
  }
  return response.json();
}

function setCopyPrompt(request) {
  if (request?.connectPrompt) {
    elements.copyRow.classList.remove("hidden");
    elements.connectPrompt.value = request.connectPrompt;
  } else {
    elements.copyRow.classList.add("hidden");
    elements.connectPrompt.value = "";
  }
}

function renderStatus() {
  const status = state.status;
  elements.statusPill.textContent = status?.Title || "안내 모드";
  elements.statusMessage.textContent = status?.Message || "현재 흐름과 다음 플러그인을 빠르게 확인합니다.";
  elements.connectTitle.textContent = status?.Title || "연결 상태";
  elements.connectDetail.textContent = status?.Message || "Codex 세션 연결 요청을 만들 수 있습니다.";
  setCopyPrompt(status?.LinkRequest);

  if (status?.Mode === "Linked") {
    elements.flowStatus.classList.remove("hidden");
    elements.currentFlow.textContent = `Flow: ${status.State.currentFlow || "-"}`;
    elements.nextFlow.textContent = `Next: ${status.State.nextSkill || "-"}`;
  } else {
    elements.flowStatus.classList.add("hidden");
  }
}

function getActiveFlowKey() {
  return state.status?.Mode === "Linked" ? flowKey(state.status.State?.currentFlow) : "";
}

function renderFlowList() {
  const activeKey = getActiveFlowKey();
  elements.flowCount.textContent = `${state.guide.length} items`;
  elements.flowList.innerHTML = "";
  state.guide.forEach((item, index) => {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "flow-card";
    if (index === state.selectedIndex) button.classList.add("selected");
    if (flowKey(item.flow) === activeKey) button.classList.add("active");
    button.innerHTML = `<span class="tag">FLOW</span><strong>${item.flow}</strong><small>${item.situation}</small>`;
    button.addEventListener("click", () => {
      state.selectedIndex = index;
      render();
    });
    elements.flowList.append(button);
  });
}

function row(label, value, className = "") {
  return `<div class="detail-row ${className}"><span>${label}</span><p>${value || "없음"}</p></div>`;
}

function renderDetail() {
  const item = state.guide[state.selectedIndex];
  if (!item) return;
  const active = state.status?.Mode === "Linked" && flowKey(state.status.State?.currentFlow) === flowKey(item.flow);
  const action = active ? state.status.State?.recommendedAction || item.nowAction : item.nowAction;
  const reason = active ? state.status.State?.recommendedReason || item.reason : item.reason;
  const actionChanged = active && state.previousAction && state.previousAction !== action;
  const reasonChanged = active && state.previousReason && state.previousReason !== reason;
  if (active) {
    state.previousAction = action;
    state.previousReason = reason;
  }
  elements.detailFlow.textContent = item.flow;
  elements.detailBody.innerHTML = [
    row("선행 플러그인", item.previousPlugin),
    row("지금 할 일", action, actionChanged ? "flash" : ""),
    row("다음 플러그인", item.nextPlugin),
    row("이유", reason, reasonChanged ? "flash" : "")
  ].join("");
}

function render() {
  renderStatus();
  renderFlowList();
  renderDetail();
}

async function refresh() {
  state.status = await fetchJson("/api/status");
  render();
}

elements.connectButton.addEventListener("click", async () => {
  const request = await fetchJson("/api/link-request", { method: "POST" });
  setCopyPrompt(request);
  await refresh();
});

elements.disconnectButton.addEventListener("click", async () => {
  await fetchJson("/api/disconnect", { method: "POST" });
  await refresh();
});

elements.copyButton.addEventListener("click", async () => {
  await navigator.clipboard.writeText(elements.connectPrompt.value);
  elements.copyButton.textContent = "완료";
  setTimeout(() => { elements.copyButton.textContent = "문장 복사"; }, 1200);
});

state.guide = (await fetchJson("/api/guide")).items || [];
await refresh();
setInterval(refresh, 2500);
```

- [ ] **Step 3: Create `web/public/styles.css`**

Create `web/public/styles.css` with compact dark styling:

```css
* { box-sizing: border-box; }
body {
  margin: 0;
  background: #05030a;
  color: #eadfff;
  font-family: "Segoe UI", system-ui, sans-serif;
}
.shell {
  width: min(980px, 100vw);
  min-height: 100vh;
  padding: 10px;
}
.header, .connect-panel, .flow-list-panel, .detail-panel, .flow-status {
  border: 1px solid #2d2142;
  background: #08060d;
  border-radius: 8px;
}
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 14px;
  margin-bottom: 10px;
}
h1, h2, p { margin: 0; }
h1 { font-size: 18px; }
h2 { font-size: 15px; }
p, small { color: #cbb8f2; }
.pill, .tag {
  display: inline-flex;
  align-items: center;
  border: 1px solid #5b3f8c;
  border-radius: 6px;
  padding: 4px 8px;
  color: #eadfff;
  background: #120d1d;
  font-size: 12px;
}
.connect-panel { padding: 12px; margin-bottom: 10px; }
.connect-actions { display: flex; gap: 8px; margin-top: 10px; }
button {
  border: 1px solid #4c3474;
  background: #151024;
  color: #eadfff;
  border-radius: 6px;
  padding: 8px 10px;
  cursor: pointer;
}
button:hover { background: #211533; }
.copy-row {
  display: grid;
  grid-template-columns: 1fr 96px;
  gap: 8px;
  margin-top: 10px;
}
input {
  min-width: 0;
  border: 1px solid #35224f;
  background: #0f0b19;
  color: #d9c8ff;
  border-radius: 6px;
  padding: 8px;
}
.flow-status { display: flex; gap: 8px; padding: 8px; margin-bottom: 10px; color: #dbeafe; }
.content-grid { display: grid; grid-template-columns: minmax(260px, 1fr) minmax(320px, 1fr); gap: 10px; }
.flow-list-panel, .detail-panel { padding: 8px; min-height: 420px; }
.panel-heading { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
.flow-list { display: flex; flex-direction: column; gap: 6px; max-height: 70vh; overflow: auto; }
.flow-card {
  width: 100%;
  text-align: left;
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 4px 8px;
  padding: 10px;
}
.flow-card small { grid-column: 2; }
.flow-card.selected { border-color: #65489a; background: #120d1d; }
.flow-card.active { border-color: #60a5fa; background: #123b7a; }
.detail-row {
  border: 1px solid #221936;
  border-radius: 8px;
  background: #0f0b19;
  padding: 10px;
  margin-bottom: 8px;
}
.detail-row span { display: inline-block; font-size: 12px; color: #b8a7dc; margin-bottom: 6px; }
.detail-row.flash { border-color: #60a5fa; background: #123b7a; }
.hidden { display: none; }
@media (max-width: 760px) {
  .content-grid { grid-template-columns: 1fr; }
  .copy-row { grid-template-columns: 1fr; }
}
```

- [ ] **Step 4: Start the server**

Run:

```powershell
npm --prefix web start
```

Expected:

```text
Superpowers web widget running at http://127.0.0.1:43821
```

- [ ] **Step 5: Verify browser rendering**

Open:

```text
http://127.0.0.1:43821
```

Expected:

```text
The browser shows the Superpowers title, connection panel, flow list, and detail panel.
```

- [ ] **Step 6: Commit**

Run:

```powershell
git add web/public/index.html web/public/app.js web/public/styles.css
git commit -m "Add the browser UI for the web widget"
```

Do not push unless the user explicitly asks.

---

### Task 8: Migrate Windows Widget Runtime Files

**Files:**
- Modify: `superpowers-widget.ps1`

- [ ] **Step 1: Add runtime path helpers to PowerShell**

In `superpowers-widget.ps1`, add script-level paths near the existing widget paths:

```powershell
$Script:RuntimeDir = Join-Path $Script:WidgetDir "runtime"
$Script:RuntimeLinksDir = Join-Path $Script:RuntimeDir "links"
$Script:RuntimeStatesDir = Join-Path $Script:RuntimeDir "states"
$Script:ActiveLinkId = $null
```

Add helper functions:

```powershell
function Get-SafeWidgetFileName {
  param([Parameter(Mandatory = $true)][string]$Value)
  return $Value -replace "[^a-zA-Z0-9_.-]", "_"
}

function Get-WidgetRuntimePaths {
  param([Parameter(Mandatory = $true)][string]$RequestedLinkId)
  $safeLinkId = Get-SafeWidgetFileName -Value $RequestedLinkId
  return [pscustomobject]@{
    linkId = $safeLinkId
    linkRequestPath = Join-Path $Script:RuntimeLinksDir "$safeLinkId.json"
    statePath = Join-Path $Script:RuntimeStatesDir "$safeLinkId.json"
  }
}
```

- [ ] **Step 2: Update `Write-LinkRequest` to write runtime files**

Change `Write-LinkRequest` so it:

1. Generates or receives a `linkId`.
2. Sets `$Script:ActiveLinkId`.
3. Uses `Get-WidgetRuntimePaths`.
4. Writes the request to `.superpowers-widget/runtime/links/<linkId>.json`.
5. Writes the same request to `.superpowers-widget/link-request.json` as a legacy mirror.
6. Registers the global registry entry with runtime `statePath` and `linkRequestPath`.

The key request fields must be:

```powershell
$request = [ordered]@{
  linkId = $requestLinkId
  workspacePath = $Script:WorkspacePath
  requestedAt = $now.ToString("o")
  expiresAt = $expiresAt.ToString("o")
  statePath = $runtimePaths.statePath
  linkRequestPath = $runtimePaths.linkRequestPath
  scriptPath = $Script:ScriptPath
  connectCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$Script:ScriptPath`" -ConnectSession -LinkId $requestLinkId"
  connectPrompt = $connectPrompt
  instruction = "Codex 세션에 `"$connectPrompt`" 전체 문장을 알려주세요. 자동 연결이 안 되면 connectCommand를 실행하세요."
}
```

- [ ] **Step 3: Update `Get-LatestLinkRequest`**

Change `Get-LatestLinkRequest` so it prefers:

1. `$Script:ActiveLinkId` runtime link request.
2. Newest file under `.superpowers-widget/runtime/links/`.
3. Legacy `.superpowers-widget/link-request.json`.

Use this selection logic:

```powershell
if ($Script:ActiveLinkId) {
  $paths = Get-WidgetRuntimePaths -RequestedLinkId $Script:ActiveLinkId
  $activeRequest = Read-JsonFile -Path $paths.linkRequestPath
  if ($activeRequest) { return $activeRequest }
}

if (Test-Path -LiteralPath $Script:RuntimeLinksDir) {
  $latest = Get-ChildItem -LiteralPath $Script:RuntimeLinksDir -Filter "*.json" |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if ($latest) { return Read-JsonFile -Path $latest.FullName }
}

return Read-JsonFile -Path $Script:LinkRequestPath
```

- [ ] **Step 4: Update `Get-ConnectionStatus` to read request-specific state**

Change state loading so it reads from the current link request's `statePath` when available:

```powershell
$linkRequest = Get-LatestLinkRequest
$statePath = if ($linkRequest -and $linkRequest.statePath) { [string]$linkRequest.statePath } else { $Script:StatePath }
$state = Read-JsonFile -Path $statePath
```

Keep the connection authority as:

```powershell
$sameLink = [string]$state.linkId -eq [string]$linkRequest.linkId
$fresh = Test-IsFreshState -State $state
```

Do not re-add workspace equality as a connection requirement.

- [ ] **Step 5: Update `Write-SessionState`**

When a registry entry exists, keep using the registry's `statePath` and `linkRequestPath`.

When no registry entry exists, call `Write-LinkRequest -RequestedLinkId $RequestedLinkId`, then write state to the returned runtime `statePath`.

Keep writing a legacy `.superpowers-widget/state.json` mirror only for compatibility:

```powershell
ConvertTo-WidgetJson $state | Set-Content -LiteralPath $targetStatePath -Encoding UTF8
if ($targetStatePath -ne $Script:StatePath) {
  ConvertTo-WidgetJson $state | Set-Content -LiteralPath $Script:StatePath -Encoding UTF8
}
```

- [ ] **Step 6: Update disconnect behavior**

When the user clicks "세션 해제", remove the active runtime state and link request as well as legacy mirrors:

```powershell
if ($Script:ActiveLinkId) {
  $paths = Get-WidgetRuntimePaths -RequestedLinkId $Script:ActiveLinkId
  Remove-Item -LiteralPath $paths.statePath -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $paths.linkRequestPath -ErrorAction SilentlyContinue
}
Remove-Item -LiteralPath $Script:StatePath -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $Script:LinkRequestPath -ErrorAction SilentlyContinue
```

- [ ] **Step 7: Extend `Assert-SelfTest`**

Add a non-UI self-test that:

1. Creates two link IDs.
2. Writes two runtime link requests.
3. Writes two state files.
4. Verifies the two state paths are different.
5. Verifies `Get-ConnectionStatus` can return `Linked` for the active request.

Expected assertion:

```powershell
if ($firstPaths.statePath -eq $secondPaths.statePath) {
  throw "Runtime state paths must be widget-specific."
}
```

- [ ] **Step 8: Run PowerShell verification**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -CreateLinkRequest -LinkId widget-runtime-test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectSession -LinkId widget-runtime-test -CurrentFlow Brainstorming
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -ConnectionStatus
```

Expected:

```text
SelfTest passed
ConnectionStatus returns Mode: Linked
.superpowers-widget/runtime/links/widget-runtime-test.json exists
.superpowers-widget/runtime/states/widget-runtime-test.json exists
```

- [ ] **Step 9: Commit**

Run:

```powershell
git add superpowers-widget.ps1
git commit -m "Move the Windows widget to widget-specific runtime files"
```

Do not push unless the user explicitly asks.

---

### Task 9: Update README and User Launch Instructions

**Files:**
- Modify: `README.md`
- Create: `start-superpowers-web-widget.bat`
- Create: `start-superpowers-web-widget.sh`

- [ ] **Step 1: Create Windows web launcher**

Create `start-superpowers-web-widget.bat`:

```bat
@echo off
setlocal
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is required for the web widget.
  echo Install Node.js 20 or newer, then run this file again.
  pause
  exit /b 1
)
npm --prefix web start
pause
```

- [ ] **Step 2: Create Unix web launcher**

Create `start-superpowers-web-widget.sh`:

```sh
#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 20 or newer is required for the web widget." >&2
  exit 1
fi
npm --prefix web start
```

- [ ] **Step 3: Update README sections**

Update `README.md` so it contains:

```markdown
## 실행 방식 선택

- Windows 전용 위젯: `start-superpowers-widget.bat`
- 크로스플랫폼 웹 위젯: `start-superpowers-web-widget.bat` 또는 `./start-superpowers-web-widget.sh`

웹 위젯은 Node.js 20 이상이 필요합니다. 실행 후 브라우저에서 `http://127.0.0.1:43821`을 엽니다.
```

Also update the runtime file explanation:

```markdown
새 연결 요청은 widget ID별 runtime 파일을 사용합니다.

    .superpowers-widget/runtime/links/<widget-id>.json
    .superpowers-widget/runtime/states/<widget-id>.json

Windows 위젯과 웹 위젯을 동시에 켜도 각자 자기 widget ID 파일만 사용하므로 서로 덮어쓰지 않습니다.
```

- [ ] **Step 4: Run README verification**

Run:

```powershell
rg -n "웹 위젯|runtime|Node.js|start-superpowers-web-widget" README.md
```

Expected:

```text
README contains web launch and runtime split instructions.
```

- [ ] **Step 5: Commit**

Run:

```powershell
git add README.md start-superpowers-web-widget.bat start-superpowers-web-widget.sh
git commit -m "Document how to run the web widget"
```

Do not push unless the user explicitly asks.

---

### Task 10: End-to-End Verification

**Files:**
- No new files unless fixing defects found by verification.

- [ ] **Step 1: Run all Node tests**

Run:

```powershell
npm --prefix web test
```

Expected:

```text
# fail 0
```

- [ ] **Step 2: Run PowerShell self-test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -SelfTest
```

Expected:

```text
SelfTest passed
```

- [ ] **Step 3: Run JSON parse checks**

Run:

```powershell
$ErrorActionPreference = 'Stop'
Get-Content .\.superpowers-widget\flow-guide.json -Raw | ConvertFrom-Json | Out-Null
Get-Content .\.superpowers-widget\state.example.json -Raw | ConvertFrom-Json | Out-Null
```

Expected:

```text
No output and exit code 0.
```

- [ ] **Step 4: Verify simultaneous widget states**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\superpowers-widget.ps1 -CreateLinkRequest -LinkId widget-win-e2e
npm --prefix web start -- --link-id widget-web-e2e --port 43822
```

In another shell, write test states:

```powershell
$now = Get-Date
$winState = @{
  linkId = 'widget-win-e2e'
  currentFlow = 'Brainstorming'
  updatedAt = $now.ToString('o')
  expiresAt = $now.AddHours(1).ToString('o')
} | ConvertTo-Json
$webState = @{
  linkId = 'widget-web-e2e'
  currentFlow = 'Writing Plans'
  updatedAt = $now.ToString('o')
  expiresAt = $now.AddHours(1).ToString('o')
} | ConvertTo-Json
$winState | Set-Content .\.superpowers-widget\runtime\states\widget-win-e2e.json -Encoding UTF8
$webState | Set-Content .\.superpowers-widget\runtime\states\widget-web-e2e.json -Encoding UTF8
```

Expected:

```text
Windows widget status for widget-win-e2e is Linked.
Web /api/status for widget-web-e2e is Linked.
The two state files contain different currentFlow values and do not overwrite each other.
```

- [ ] **Step 5: Verify web UI manually**

Open:

```text
http://127.0.0.1:43822
```

Expected:

```text
The page displays Flow list, details, connection controls, and current linked status.
The connect prompt copy button copies the full prompt.
```

- [ ] **Step 6: Run Git whitespace check**

Run:

```powershell
git diff --check
```

Expected:

```text
No whitespace errors.
```

- [ ] **Step 7: Commit final verification fixes**

If verification required fixes, run:

```powershell
git add .gitignore README.md superpowers-widget.ps1 start-superpowers-web-widget.bat start-superpowers-web-widget.sh web docs/plan/2026-06-15-web-widget-implementation.md
git commit -m "Stabilize the web widget verification flow"
```

If no files changed, do not create an empty commit.

Do not push unless the user explicitly asks.

---

## Execution Notes

- Use `docs/spec/2026-06-15-web-widget-design.md` as the source of truth for scope.
- Keep runtime files out of Git.
- Prefer Node built-ins over new dependencies for the MVP.
- Do not install Sentry SDK packages until the implementation reaches Task 5 and the exact browser/server integration point is verified.
- Keep Sentry disabled unless `SENTRY_DSN` is explicitly configured.
- Do not push commits unless the user explicitly asks.
