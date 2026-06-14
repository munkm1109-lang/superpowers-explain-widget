# Superpowers Web Widget Design

## Purpose

Build a cross-platform web version of the Superpowers Explain Widget that can run on Windows, Linux, and macOS while preserving the core behavior of the current Windows PowerShell/WPF widget.

The web widget should help a non-developer see:

- Which Superpowers flow is currently active.
- Whether the widget is linked to a Codex session.
- What to do next in plain language.
- Why that next action matters.
- Which flow or plugin should come next.

The widget must remain lightweight. It should read and write local JSON files through a local server. It should not call AI models, scrape Codex conversations, or consume tokens by itself.

## Documentation Layout

Project planning documents should use tool-neutral paths:

- Specs: `docs/spec/`
- Implementation plans: `docs/plan/`

Do not place new project specs or plans under `docs/superpowers/`. Superpowers is one workflow that can create the documents, but the documents should remain easy for other plugins, agents, and human readers to find.

## Repository Strategy

Develop the web widget in the same repository on the `codex/web-widget` branch.

The existing Windows widget remains in place:

- `start-superpowers-widget.bat`
- `superpowers-widget.ps1`

The web widget lives under a separate `web/` directory:

```text
web/
  package.json
  server.js
  public/
    index.html
    app.js
    styles.css
```

This keeps the Windows implementation and web implementation easy to distinguish in Git while allowing both versions to share guide data and documentation.

## Recommended Approach

Use a Node.js local server with a browser UI.

Runtime flow:

```text
User starts the web widget server
-> server opens or prints a localhost URL
-> browser displays the widget UI
-> server reads .superpowers-widget/flow-guide.json
-> user clicks a connect button in the web UI
-> server creates a widget-specific link request
-> user copies the generated connect prompt into a Codex session
-> Codex writes state to the widget-specific state path
-> browser polls the server for linked status and guide data
```

Why Node.js:

- Works naturally across Windows, Linux, and macOS.
- Provides a simple local HTTP API for browser UI.
- Can read and write local JSON files without browser file permission issues.
- Keeps the UI independent from PowerShell/WPF.
- Can later be packaged or launched with small OS-specific helper scripts.

Rejected alternatives:

- Static HTML only: too limited because the browser cannot reliably read and write local runtime files.
- Python server first: workable, but less natural for a browser-first UI and future frontend packaging.
- Separate repository now: premature. The web widget still shares the same purpose, guide data, and connection model.

## MVP Scope

The MVP should match the current Windows widget's user-facing behavior as closely as practical:

- Display the Superpowers flow list.
- Highlight the current flow in blue.
- Show the detail panel for the selected flow.
- Show live `recommendedAction` as "지금 할 일".
- Show live `recommendedReason` as "이유".
- Flash changed live guidance rows briefly.
- Show linked, waiting, guide, and stale/reconnect states.
- Generate a Codex connect prompt from the UI.
- Copy the full connect prompt, not just the widget ID.
- Poll local state every few seconds.
- Avoid any AI or token-consuming work inside the widget.

Out of scope for MVP:

- Remote hosting.
- Cloud sync.
- User accounts.
- Packaging as a desktop app.
- Tray integration.
- Multiple visual themes.
- Direct Codex API integration.

## Shared Data and Runtime Files

Static guide data remains shared:

```text
.superpowers-widget/
  flow-guide.json
  state.example.json
```

Runtime files must be split by widget ID so the Windows widget and web widget can run at the same time without overwriting each other:

```text
.superpowers-widget/
  runtime/
    links/
      widget-xxx.json
    states/
      widget-xxx.json
```

Each running widget owns one `widget-...` ID. A widget reads only its own state file and writes only its own link request file.

Example:

```text
Windows widget
  link:  .superpowers-widget/runtime/links/widget-win-123.json
  state: .superpowers-widget/runtime/states/widget-win-123.json

Web widget
  link:  .superpowers-widget/runtime/links/widget-web-456.json
  state: .superpowers-widget/runtime/states/widget-web-456.json
```

This means both widgets can be open at the same time, connected to the same Codex session or different Codex sessions, without competing over a single `state.json`.

## Global Registry

The existing same-user registry concept remains, but each registry entry should point to widget-specific runtime paths:

Windows:

```text
%LOCALAPPDATA%\SuperpowersExplainWidget\links\<widget-id>.json
```

Linux:

```text
~/.local/state/superpowers-explain-widget/links/<widget-id>.json
```

macOS:

```text
~/Library/Application Support/SuperpowersExplainWidget/links/<widget-id>.json
```

Each registry file should include:

- `linkId`
- `workspacePath`
- `statePath`
- `linkRequestPath`
- `scriptPath` or web server launch hint when available
- `connectCommand` when available
- `connectPrompt`
- `requestedAt`
- `expiresAt`

The copied prompt should be self-contained enough for another Codex session to find the registry entry and write the correct state path.

## Legacy Compatibility

The existing Windows files should remain readable for compatibility:

```text
.superpowers-widget/link-request.json
.superpowers-widget/state.json
```

New link requests should use the widget-specific runtime structure by default.

Legacy behavior:

- If a legacy `link-request.json` exists and no widget-specific request exists, the Windows widget may read it and migrate the active request into `runtime/links/`.
- If a legacy `state.json` exists and matches the active legacy link ID, the widget may display it.
- New web widget code should not create legacy files except if a deliberate compatibility bridge is added later.

The goal is to avoid breaking current users while moving all new work to the safer runtime structure.

## Server API

The Node server should expose a small local-only API:

- `GET /api/guide`
  - Returns `flow-guide.json`.
- `GET /api/status`
  - Returns guide/waiting/linked/stale status for the web widget's own `linkId`.
- `POST /api/link-request`
  - Creates or refreshes the web widget's own link request.
- `POST /api/disconnect`
  - Clears the web widget's own state and link request.
- `GET /api/health`
  - Returns a simple health response for tests and troubleshooting.

The server should bind to localhost by default. It should not expose the local runtime files over the network.

## UI Design

The web UI should preserve the current widget's information hierarchy:

- Header with title and connection state.
- Connect/request area with copyable prompt.
- Flow list.
- Detail panel.
- Current flow badge.
- Next flow/plugin badge.
- "지금 할 일" and "이유" rows with short highlight animation when content changes.

The UI should be responsive enough for a narrow browser window. It does not need to be a landing page. The first screen should be the usable widget itself.

## Error Handling

The widget should handle:

- Missing `flow-guide.json`.
- Invalid JSON.
- Missing runtime state.
- Expired state.
- Mismatched link ID.
- Registry entry not found.
- Port already in use.

The user-facing language should stay simple:

- "연결 대기 중"
- "연결됨"
- "재연결 필요"
- "상태 파일을 읽을 수 없습니다"

Developer details can be logged to the server console.

## Testing

Minimum verification for implementation:

- JSON parse check for `flow-guide.json` and examples.
- Server health endpoint returns success.
- Link request creates widget-specific runtime files.
- Status returns `Waiting` before state exists.
- Status returns `Linked` when matching fresh state exists.
- Status returns `Stale` for expired state.
- Two different widget IDs can hold separate link/state files at the same time.
- Legacy `state.json` / `link-request.json` behavior remains readable for the Windows widget.
- Browser UI renders flow list and current status.

## Open Decisions Resolved

- Repository: same repository, `codex/web-widget` branch.
- Runtime: Node.js local server.
- Scope: feature parity with current Windows widget for MVP.
- Static guide: shared `.superpowers-widget/flow-guide.json`.
- Runtime state: widget ID-specific files under `.superpowers-widget/runtime/`.
- Compatibility: Windows widget moves to the new runtime structure while retaining legacy read compatibility.
- Documentation: specs live in `docs/spec`, plans live in `docs/plan`.
