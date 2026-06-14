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
