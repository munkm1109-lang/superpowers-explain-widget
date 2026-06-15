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

  if (status?.Mode === "Linked" || status?.Mode === "LinkedPartial") {
    elements.flowStatus.classList.remove("hidden");
    elements.currentFlow.textContent = `Flow: ${status.State.currentFlow || "Flow 정보 대기 중"}`;
    elements.nextFlow.textContent = `Next: ${status.State.nextSkill || "-"}`;
  } else {
    elements.flowStatus.classList.add("hidden");
  }
}

function getActiveFlowKey() {
  return state.status?.Mode === "Linked" || state.status?.Mode === "LinkedPartial" ? flowKey(state.status.State?.currentFlow) : "";
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
  const active = (state.status?.Mode === "Linked" || state.status?.Mode === "LinkedPartial") && flowKey(state.status.State?.currentFlow) === flowKey(item.flow);
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
