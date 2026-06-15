import { fileURLToPath } from "node:url";
import { createLinkRequest, createWidgetRuntime } from "./src/widget-runtime.js";
import { getRegistryPath } from "./src/paths.js";
import { readJsonFile, writeJsonFile } from "./src/json-store.js";

function readArg(name, fallback = "") {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] || fallback : fallback;
}

function readRequiredArg(name) {
  const value = readArg(name);
  if (!value) {
    throw new Error(`${name} is required.`);
  }
  return value;
}

export async function connectSession({
  linkId,
  registryPath = getRegistryPath(linkId),
  sessionId = `codex-session-${new Date().toISOString().replace(/[-:]/g, "").replace(/\..+/, "")}`,
  sessionLabel = "Current Codex session",
  currentFlow = "Brainstorming",
  activeSkill = "",
  status = "Codex 세션과 연결됨",
  nextSkill = "writing-plans",
  recommendedAction = "현재 상황과 목표를 정리하고 다음 Superpowers flow를 고릅니다.",
  recommendedReason = "위젯이 현재 Codex 세션의 전체 작업 흐름과 다음 행동을 표시할 수 있어야 하기 때문입니다.",
  workspacePath = process.cwd()
} = {}) {
  if (!linkId) {
    throw new Error("linkId is required.");
  }

  let request = await readJsonFile(registryPath);
  if (!request) {
    const runtime = createWidgetRuntime({ linkId });
    request = await createLinkRequest(runtime);
  }

  const now = new Date();
  const state = {
    linkId,
    sessionId,
    sessionLabel,
    workspacePath,
    currentFlow,
    activeSkill,
    status,
    nextSkill,
    recommendedAction,
    recommendedReason,
    blockedActions: ["runtime state/link 파일은 Git에 커밋하지 않습니다."],
    connected: true,
    connectedAt: now.toISOString(),
    updatedAt: now.toISOString(),
    expiresAt: new Date(now.getTime() + 6 * 60 * 60 * 1000).toISOString()
  };

  const linkRequest = {
    ...request,
    connected: true,
    connectedAt: now.toISOString(),
    connectedSessionId: sessionId,
    connectedWorkspacePath: workspacePath,
    connectionStatus: "connected"
  };

  await writeJsonFile(request.statePath, state);
  await writeJsonFile(request.linkRequestPath, linkRequest);
  await writeJsonFile(registryPath, linkRequest);

  return { request: linkRequest, state };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const linkId = readRequiredArg("--link-id");
  const result = await connectSession({
    linkId,
    sessionId: readArg("--session-id") || undefined,
    sessionLabel: readArg("--session-label") || undefined,
    currentFlow: readArg("--current-flow") || undefined,
    activeSkill: readArg("--active-skill") || undefined,
    status: readArg("--status") || undefined,
    nextSkill: readArg("--next-skill") || undefined,
    recommendedAction: readArg("--action") || undefined,
    recommendedReason: readArg("--reason") || undefined,
    workspacePath: readArg("--workspace") || undefined
  });
  console.log(JSON.stringify(result.state, null, 2));
}
