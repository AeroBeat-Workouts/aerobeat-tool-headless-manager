# Headless Quit Manager Design Note

## Scope

This repo should stay intentionally tiny. The first version should prove only one narrow thing: whether a running headless AeroBeat/Godot app can be asked to quit **from inside the process** more safely than killing the PID or its sidecars from the outside.

It should **not** claim equivalence to the Godot editor's **Stop Running Project** behavior.

## Recommended minimal design

Use a **headless-only, one-shot sentinel file command** handled by a reusable autoload/singleton.

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
- watch exactly one configured sentinel file path
- accept exactly one command form: `QUIT <token>`
- on a valid request, delete/consume the sentinel, emit a local signal for observability, and call `get_tree().quit()` from inside the app
- ignore everything else

Suggested non-responsibilities for v1:

- no editor integration
- no generic command bus
- no arbitrary shell/process execution
- no restart command
- no multi-command protocol
- no broad file watching of a directory tree

## Suggested runtime configuration

Keep configuration explicit and per-run, for example via environment variables or launch arguments supplied by the harness:

- `AEROBEAT_HEADLESS_QUIT_FILE=/tmp/aerobeat-headless/<run-id>/quit.request`
- `AEROBEAT_HEADLESS_QUIT_TOKEN=<random-per-run-token>`

Guardrails:

- only arm the manager when running in headless automation mode
- require an absolute path
- require a per-run random token so stale files from older runs are rejected
- treat the sentinel as one-shot; once consumed, the manager should not accept further commands

## Exact allowed subagent interaction

The allowed external interaction should be a single host-shell write of the exact quit command into the configured sentinel file, ideally via atomic rename to avoid partial reads:

```bash
RUN_DIR=/tmp/aerobeat-headless/$RUN_ID
QUIT_FILE="$RUN_DIR/quit.request"
TMP_FILE="$QUIT_FILE.tmp.$$"
printf 'QUIT %s\n' "$AEROBEAT_HEADLESS_QUIT_TOKEN" > "$TMP_FILE"
mv "$TMP_FILE" "$QUIT_FILE"
```

That is the whole control surface. No PID kill, no sidecar kill, no directory-wide command inbox.

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
