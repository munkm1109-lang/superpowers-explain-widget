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
  return `Superpowers 위젯에 연결해줘: ${request.linkId}. 같은 사용자라면 ${request.registryPath} 를 읽고, 그 안의 statePath/linkRequestPath에 stateTemplate 형식으로 연결 상태를 써줘. 최소한 linkId와 updatedAt 또는 connectedAt은 반드시 포함해줘. 이 파일을 못 찾으면 connectCommand를 실행해줘.`;
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
    connectCommand: `npm --prefix web run connect -- --link-id ${runtime.linkId}`,
    fallbackStartCommand: `npm --prefix web start -- --link-id ${runtime.linkId}`,
    minimumStateFields: ["linkId", "updatedAt 또는 connectedAt"],
    recommendedStateFields: ["currentFlow", "status", "nextSkill", "recommendedAction", "recommendedReason", "expiresAt"],
    stateTemplate: {
      linkId: runtime.linkId,
      sessionId: "<codex-session-id>",
      sessionLabel: "<Codex session label>",
      workspacePath: "<workspace path>",
      currentFlow: "Brainstorming",
      activeSkill: "",
      status: "Codex 세션과 연결됨",
      nextSkill: "writing-plans",
      recommendedAction: "현재 상황과 목표를 정리하고 다음 Superpowers flow를 고릅니다.",
      recommendedReason: "위젯이 현재 Codex 세션의 전체 작업 흐름과 다음 행동을 표시할 수 있어야 하기 때문입니다.",
      updatedAt: "<current ISO timestamp>",
      expiresAt: "<current ISO timestamp + 6 hours>"
    },
    connectPrompt: ""
  };
  request.connectPrompt = getConnectPrompt(request);
  request.instruction = `Codex 세션에 "${request.connectPrompt}" 전체 문장을 알려주세요.`;
  await writeJsonFile(runtime.paths.linkRequestPath, request);
  await writeJsonFile(runtime.registryPath, request);
  return request;
}

function normalizeState(state) {
  if (!state || typeof state !== "object") {
    return state;
  }
  const normalized = { ...state };
  if (!normalized.updatedAt && normalized.connectedAt) {
    normalized.updatedAt = normalized.connectedAt;
  }
  if (normalized.currentFlow == null) {
    normalized.currentFlow = "";
  }
  return normalized;
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
  const state = normalizeState(await readJsonFile(runtime.paths.statePath));
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
    if (!state.currentFlow) {
      return {
        Mode: "LinkedPartial",
        Title: "연결됨",
        Message: "Codex 세션과 연결됐고, Flow 정보 입력을 기다리는 중입니다.",
        State: state,
        LinkRequest: linkRequest
      };
    }
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
