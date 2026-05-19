# Headless Quit Manager Design Note

## Scope

This repo should stay intentionally tiny. The first version should prove only one narrow thing: whether a running headless AeroBeat/Godot app can be asked to quit **from inside the process** more safely than killing the PID or its sidecars from the outside.

It should **not** claim equivalence to the Godot editor's **Stop Running Project** behavior.

## Recommended minimal design

Use a **headless-only, one-shot sentinel file command** handled by a reusable autoload/singleton.

Update after review: keep v1 development-only and remove both the token/handshake concept and command payload parsing. The external command surface should be as simple as possible: one watched file, `res://.headless/quit.request`, whose mere presence means "quit now".

### Why this is the smallest truthful control surface

- smaller than embedding a general HTTP API or long-lived socket server
- no open network port, even on localhost
- easy to audit: one watched file path, one accepted command, one action
- easy for subagents to drive from the host shell with standard tools
- keeps the manager reusable across consuming projects without implying broader remote-control scope

## Proposed singleton contract

Suggested singleton name: `AeroHeadlessManager`

Suggested responsibilities for v1 only:

- stay disabled unless explicitly configured for a headless run
- resolve and watch exactly one project-local sentinel path: `res://.headless/quit.request`
- clear/remove any pre-existing sentinel on startup before arming the watcher
- when the sentinel appears, delete/consume it, emit a local signal for observability, and call `get_tree().quit()` from inside the app
- ignore everything else

Suggested non-responsibilities for v1:

- no editor integration
- no generic command bus
- no arbitrary shell/process execution
- no restart command
- no multi-command protocol
- no broad file watching of a directory tree

## Suggested runtime configuration

Use a fixed project-local path so launching subagents do not need per-run configuration:

- `res://.headless/quit.request`
- filesystem path resolved at runtime with `ProjectSettings.globalize_path("res://.headless/quit.request")`

Guardrails:

- only arm the manager when running in headless automation mode
- ensure `.headless/` exists inside the project when needed
- treat the sentinel as one-shot; once consumed, the manager should not accept further commands
- consume/remove any pre-existing sentinel at startup so stale dev files do not immediately trigger quit
- add `.headless/` to the consuming dev project's `.gitignore`

## Exact allowed subagent interaction

The allowed external interaction should be a single host-shell creation of the sentinel file at the project-local path, ideally via atomic rename so the manager only ever sees a completed file:

```bash
QUIT_FILE="/path/to/project/.headless/quit.request"
TMP_FILE="$QUIT_FILE.tmp.$$"
mkdir -p "$(dirname "$QUIT_FILE")"
: > "$TMP_FILE"
mv "$TMP_FILE" "$QUIT_FILE"
```

That is the whole control surface. No PID kill, no sidecar kill, no command payload, no directory-wide command inbox.

## Why this is safer than PID/sidecar kills

This design is safer **if it works** because the quit decision is executed from inside the Godot process rather than by abruptly terminating it from outside. That gives the app a chance to:

- run its own quit path on the main thread
- emit final signals/logs
- let nodes/services react to shutdown coherently
- unwind sidecar-related cleanup that the app itself owns
- avoid the harsher failure mode of killing a process tree mid-frame or mid-I/O

This is still a practical safety claim, not a formal one. It only says the path is more graceful than external termination, not that it is perfect.

## What this still does not prove

Even if this exits cleanly, it still does **not** prove any of the following:

- that `get_tree().quit()` is equivalent to the editor's **Stop Running Project** semantics
- that editor-owned launch/stop plumbing is reproduced
- that every sidecar/helper lifecycle bug is solved
- that GUI-session reset or crash-family issues can never recur
- that non-headless interactive runs should use this path instead of normal editor stop controls

So the truthful conclusion, if the later proof passes, would be:

> For headless automation only, this repo provides a tiny in-engine quit request path that appears safer than external termination on the tested workflow. It is **not** evidence of equivalence to editor-native stop behavior.

## What needs to be created next

The repo is still template-derived. The next implementation pass should create only the minimum code and metadata needed to support the contract above, likely:

- rename/replace the template singleton with the real headless-manager singleton
- add a tiny repo-local test surface for command parsing/arming behavior
- update package metadata and README wording away from template defaults
- keep the `.testbed` consumer focused on unit-level validation rather than broad feature scope
