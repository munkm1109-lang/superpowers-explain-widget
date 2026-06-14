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
