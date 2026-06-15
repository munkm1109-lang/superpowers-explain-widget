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
