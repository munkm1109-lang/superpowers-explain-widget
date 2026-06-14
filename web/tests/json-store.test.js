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
