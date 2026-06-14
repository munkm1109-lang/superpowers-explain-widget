# Superpowers Floating Widget Design

## Purpose

Build a lightweight Windows floating widget that helps a non-developer understand and follow the Superpowers workflow while working with Codex.

The widget should act as both:

- A simple guide for each Superpowers flow.
- A request-based status panel that shows which workflow phase the linked Codex session is in.

The widget must stay lightweight. It should not continuously analyze full Codex conversations, call AI models, or consume tokens by itself.

## Target User

The primary user is a non-developer who wants to understand:

- Which Superpowers process is currently active.
- Whether the widget is currently linked to a Codex session.
- What the current process means in plain language.
- What should happen next.
- Which plugin or skill should be used next.
- What actions are blocked by the current workflow rules.

The explanation style should avoid developer jargon where possible.

## Recommended Approach

Use a Windows `.bat` launcher that starts a PowerShell/WPF widget.

Files:

- `start-superpowers-widget.bat`: double-click launcher for the user.
- `superpowers-widget.ps1`: Windows floating widget implementation.
- `.superpowers-widget/state.json`: current linked Codex session workflow status.
- `.superpowers-widget/link-request.json`: optional user-created request to link the widget to the current Codex session.
- `.superpowers-widget/flow-guide.json`: static Superpowers guide content.

Runtime flow:

```text
User double-clicks start-superpowers-widget.bat
-> launcher starts superpowers-widget.ps1
-> widget opens as an always-on-top floating window
-> widget reads flow-guide.json for reference content
-> widget starts in disconnected guide mode
-> user clicks "Connect to Codex session" when they want session linking
-> widget records the link request
-> Codex writes state.json for the active session after the user asks the session to connect
-> widget displays linked workflow status and next recommended action
```

## Why This Approach

This approach is intentionally simple and low-cost.

Benefits:

- No new app framework dependency is required.
- The user can start it by double-clicking a `.bat` file.
- The widget can run without consuming Codex tokens.
- The widget does not need direct access to Codex internals.
- The state file keeps the integration explicit and easy to debug.
- The design can later be packaged as an `.exe` if it proves useful.

Rejected alternatives:

- Full `.exe` app first: more polished, but heavier to build and maintain.
- Browser UI: easy to build, but not the requested Windows widget feel.
- Direct Codex session scraping: fragile, potentially expensive, and not guaranteed to work across app/runtime changes.
- Continuous AI summarization: useful in theory, but it would increase token usage and runtime cost.

## Widget Behavior

The widget should be a small always-on-top window.

Core behavior:

- Opens from `start-superpowers-widget.bat`.
- Stays above normal windows.
- Can be closed by the user.
- Can be moved by dragging the title area.
- Shows guide content in two tabs.
- Starts without an active Codex session link.
- Lets the user request session linking from inside the widget.
- Reads current linked workflow state from `.superpowers-widget/state.json`.
- Refreshes linked state automatically every 1-3 seconds after linking.
- Handles missing or invalid state files gracefully.

Initial version should stay simple. Search, opacity controls, tray integration, start-on-login, and `.exe` packaging are out of scope for the first version.

## Content Structure

The widget has two tabs.

### Flow Tab

The Flow tab explains the normal Superpowers development sequence:

1. `brainstorming`
2. `using-git-worktrees`
3. `writing-plans`
4. `subagent-driven-development` or `executing-plans`
5. `test-driven-development`
6. `requesting-code-review`
7. `finishing-a-development-branch`

Each flow entry should show:

- When to use it.
- What it does.
- What the user should expect.
- What the next step usually is.
- Any hard rule or warning.

Example:

```text
brainstorming
When: Before creating or changing behavior.
Does: Turns a rough idea into an approved design.
Rule: Do not write code before the design is approved.
Next: writing-plans.
```

### Situation Tab

The Situation tab explains which workflow to use for common situations.

Initial situations:

- New feature or UI request.
- Bug investigation.
- Refactor or cleanup.
- Code review.
- Finishing a branch.
- Unsure what to do next.

Each situation should show:

- Recommended first skill.
- Why that skill fits.
- Typical follow-up skills.
- Plain-language explanation.

Example:

```text
New feature
Start with: brainstorming.
Why: The feature needs purpose, constraints, and approval before implementation.
Then: writing-plans -> test-driven-development -> requesting-code-review.
```

## Codex Session Integration

Use `.superpowers-widget/state.json` as the status bridge between Codex and the widget, but do not link automatically.

The widget should start in guide-only mode. In guide-only mode, it shows the Flow and Situation tabs but does not claim to be connected to a Codex session.

The user can click a "Connect to Codex session" action in the widget. That action creates or updates `.superpowers-widget/link-request.json`.

Because the widget cannot directly control the current Codex app session, the first version should make the linking request explicit and user-mediated:

1. The widget records that the user wants to connect.
2. The widget shows a short copyable instruction such as: "Ask the current Codex session to connect to the Superpowers widget."
3. When the user asks Codex to connect, Codex writes `.superpowers-widget/state.json` for the active session.
4. The widget reads that state and shows the linked status.

This keeps the integration user-controlled and avoids background session scraping.

Codex updates `state.json` when the workflow phase changes. The widget only reads the workflow state.

Example state:

```json
{
  "sessionId": "manual-2026-06-14-001",
  "sessionLabel": "Current Codex session",
  "currentFlow": "brainstorming",
  "status": "design approved; writing design spec",
  "nextSkill": "writing-plans",
  "recommendedAction": "Review the saved design spec before implementation planning.",
  "blockedActions": [
    "Do not write implementation code before the design spec is reviewed."
  ],
  "updatedAt": "2026-06-14T00:00:00+09:00"
}
```

This bridge is intentionally one-way:

- Widget can request a link.
- Codex writes workflow state after the user connects the session.
- Widget reads workflow state.

The widget should not attempt to control Codex directly. For plugin usage, it should display copyable guidance such as:

```text
Use Superpowers:writing-plans to create the implementation plan.
```

## Session Change Handling

The widget should treat Codex session linking as explicit and temporary.

If the user switches to a different Codex session, the widget should not silently assume the new session is linked. Instead, it should show the last linked session status with a clear label.

Session state fields:

- `linkId`: the current widget-created connection token.
- `sessionId`: a simple identifier for the linked session.
- `sessionLabel`: human-readable session name.
- `workspacePath`: project folder the linked Codex session is working in.
- `updatedAt`: last time Codex wrote the state.
- `expiresAt`: optional timestamp after which the widget should show the link as stale.

The widget should treat a session as actively linked only when:

- `state.json.linkId` matches the latest widget-created `link-request.json.linkId`.
- `state.json.workspacePath` matches the widget workspace path.
- `state.json.updatedAt` is recent enough for the UI freshness rule.
- `state.json.expiresAt` is missing or still in the future.

Initial behavior:

- If `state.json` is missing: show "Guide mode: no Codex session linked."
- If `state.json` exists and is recent: show "Linked to: <sessionLabel>."
- If `state.json` is old or expired: show "Link may be stale. Reconnect from the current Codex session."
- If the user clicks disconnect: stop showing active linked status and return to guide-only mode.

The first version does not need to detect every Codex session switch automatically. It should instead make stale links obvious and require the user to reconnect intentionally.

## Token and Hardware Cost

The widget itself should not consume Codex tokens.

Low-cost behavior:

- Read small JSON files from disk.
- Refresh the visible state every few seconds.
- Render static guide text locally.

Avoid:

- Reading full conversation logs.
- Sending background prompts to AI.
- Running continuous summarization.
- Watching or parsing large directories.
- Refreshing faster than needed.

Expected cost:

- CPU: very low.
- Memory: low, similar to a small desktop utility.
- Disk: tiny periodic reads.
- Codex tokens: none unless Codex itself updates or explains state in the conversation.

## Error Handling

The widget should handle these cases:

- `state.json` is missing: show "No active Codex workflow state yet."
- Link was requested but Codex has not connected yet: show "Waiting for Codex session connection."
- Linked state is stale or expired: show "This session link may be old. Reconnect when needed."
- `flow-guide.json` is missing: show a clear setup error.
- JSON is invalid: show "State file could not be read" and keep the last valid state if available.
- PowerShell execution is blocked: the `.bat` launcher should show a short plain-language message if possible.

## Testing

Manual verification for the first version:

- Double-clicking `start-superpowers-widget.bat` opens the widget.
- Widget stays on top of other windows.
- Flow tab shows the full Superpowers sequence.
- Situation tab shows common task-based guidance.
- Editing `.superpowers-widget/state.json` updates the visible current state within a few seconds.
- Missing `state.json` does not crash the widget.
- Widget starts in guide-only mode before linking.
- Link request action creates or updates `.superpowers-widget/link-request.json`.
- Old or expired `state.json` is shown as stale, not as a guaranteed current session.
- Invalid `state.json` does not crash the widget.
- The widget can be moved and closed.

## First-Version Scope

Included:

- `.bat` launcher.
- PowerShell/WPF floating window.
- Flow and Situation tabs.
- Static flow guide JSON.
- Lightweight state JSON polling.
- User-requested session linking.
- Stale session warning.
- Plain-language Korean guidance.

Excluded for now:

- System tray integration.
- Start with Windows.
- `.exe` packaging.
- Direct Codex app control.
- Silent automatic connection to any Codex session.
- Automatic detection of every Codex session switch.
- Automatic AI analysis of the current conversation.
- Full plugin execution from widget buttons.
- Cross-machine sync.

## Open Decisions Resolved

- UI form: always-on-top floating Windows widget.
- Launch method: `.bat` launcher.
- Integration method: Codex-written `state.json`, widget-read polling.
- Session link model: user-requested connection, not automatic connection.
- Session switching model: show stale state and require intentional reconnection.
- Content model: both flow-based and situation-based guidance.
- Cost model: local-only reading with no background token usage.

## Next Step

After this design is reviewed and approved, invoke `writing-plans` to create the implementation plan.
