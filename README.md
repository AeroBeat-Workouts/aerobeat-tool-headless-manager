# AeroBeat Headless Manager

This repo provides a tiny reusable **AeroBeat headless-manager** singleton/autoload for Godot projects.

Its v1 contract is intentionally narrow and development-only:

- it only arms during **debug headless** runtime sessions
- it watches exactly one project-local sentinel path: `res://.headless/quit.request`
- it resolves that path with `ProjectSettings.globalize_path("res://.headless/quit.request")`
- on headless startup it ensures `.headless/` exists, clears any stale `quit.request`, and then starts polling for the sentinel
- when the sentinel appears, it consumes/deletes the file and calls `get_tree().quit()` from inside the app

The mere presence of the file means **quit now**. No token. No command payload. No PID kills. No sidecar kills.

## What this is for

This package exists to give AeroBeat-style headless development runs a tiny in-engine quit request path that is easier to audit than external process termination. It keeps the control surface local, file-based, and deliberately boring.

## What this is not

This is **not** a general remote-control API.

It does **not**:

- expose HTTP or socket control
- parse commands or payload files
- claim equivalence to the Godot editor's Stop Running Project behavior
- prove that every sidecar/helper shutdown bug is solved
- replace the normal editor stop workflow for interactive development

The truthful claim is narrower: for approved headless development runs, this package provides a small app-side quit path that may be safer than external termination because the quit happens from inside the Godot process.

## Package layout

- `src/AeroHeadlessManager.gd` — the singleton/autoload implementation
- `plugin.cfg` — package metadata
- `.testbed/` — hidden workbench used for repo-local import/tests
- `docs/headless-quit-design.md` — design note and caveats

## Consumer setup via GodotEnv

Install this repo into the consuming project through GodotEnv just like any other package. The exact checkout/pin belongs in the consumer's `addons.jsonc`, but the mounted addon key should stay truthful so the autoload path is stable, for example:

```jsonc
{
  "addons": {
    "aerobeat-tool-headless-manager": {
      "url": "git@github.com:AeroBeat-Workouts/aerobeat-tool-headless-manager.git",
      "checkout": "main",
      "subfolder": "/"
    }
  }
}
```

Then add the autoload to the consuming project's `project.godot`:

```ini
[autoload]
AeroHeadlessManager="*res://addons/aerobeat-tool-headless-manager/src/AeroHeadlessManager.gd"
```

Also add the project-local sentinel folder to the consumer repo's `.gitignore`:

```gitignore
.headless/
```

## Sending a quit request

From the host shell, create the sentinel file at the consuming project's project-local path. Atomic rename is preferred so the manager only sees a completed file:

```bash
QUIT_FILE="/path/to/project/.headless/quit.request"
TMP_FILE="$QUIT_FILE.tmp.$$"
mkdir -p "$(dirname "$QUIT_FILE")"
: > "$TMP_FILE"
mv "$TMP_FILE" "$QUIT_FILE"
```

That is the whole control surface.

## Repo-local development flow

This repo uses the AeroBeat GodotEnv package convention.

- Canonical dev/test manifest: `.testbed/addons.jsonc`
- Installed dev/test addons: `.testbed/addons/`
- GodotEnv cache: `.testbed/.addons/`
- Hidden workbench project: `.testbed/project.godot`
- Repo-local unit tests: `.testbed/tests/`

### Restore dev/test dependencies

From the repo root:

```bash
cd .testbed
godotenv addons install
```

The hidden workbench installs this repo into `.testbed/addons/aerobeat-tool-headless-manager/` via a local symlink so the testbed exercises the same mounted-addon path a consumer would use.

### Import smoke check

From the repo root:

```bash
godot --headless --path .testbed --import
```

### Run unit tests

From the repo root:

```bash
godot --headless --path .testbed --script addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -ginclude_subdirs \
  -gexit
```
