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

test("startServer exposes the running server version", async () => {
  const root = await makeRoot();
  const server = await startServer({ projectRoot: root, port: 0, linkId: "widget-version-test", openBrowser: false });
  try {
    assert.equal(server.version, "0.1.1");
  } finally {
    await server.close();
  }
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
