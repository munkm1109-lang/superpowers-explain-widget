import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { connectSession } from "../connect-session.js";
import { readJsonFile, writeJsonFile } from "../src/json-store.js";
import { createLinkRequest, createWidgetRuntime } from "../src/widget-runtime.js";

test("connectSession writes a complete state from registry link data", async () => {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), "sp-connect-"));
  const registryRoot = path.join(root, "registry");
  const runtime = createWidgetRuntime({ projectRoot: root, linkId: "widget-connect-test", registryRoot });
  const request = await createLinkRequest(runtime);
  await writeJsonFile(runtime.registryPath, request);

  const result = await connectSession({
    linkId: "widget-connect-test",
    registryPath: runtime.registryPath,
    sessionId: "session-1",
    currentFlow: "Executing Plans",
    workspacePath: root
  });

  const state = await readJsonFile(runtime.paths.statePath);
  const linkRequest = await readJsonFile(runtime.paths.linkRequestPath);

  assert.equal(result.state.currentFlow, "Executing Plans");
  assert.equal(state.linkId, "widget-connect-test");
  assert.equal(state.sessionId, "session-1");
  assert.equal(typeof state.updatedAt, "string");
  assert.equal(typeof state.connectedAt, "string");
  assert.equal(linkRequest.connectionStatus, "connected");
});
