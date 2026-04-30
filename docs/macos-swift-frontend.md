# Vibe Swift macOS frontend

`VibeMac` is a native Swift/AppKit + SwiftUI frontend for Vibe. It does not embed the Textual TUI. Instead, it launches `vibe-acp` as a backend process and renders the session as native macOS views: sidebar, chat timeline, tool cards, permission prompts, run summary, project files, todo list, execution logs, and a composer.

## Run from this checkout

```bash
swift run --package-path macos/VibeMac VibeMac
```

Frontend flags:

```bash
swift run --package-path macos/VibeMac VibeMac --workdir ~/code/project
swift run --package-path macos/VibeMac VibeMac --vibe-home ~/.vibe
swift run --package-path macos/VibeMac VibeMac --no-blur
swift run --package-path macos/VibeMac VibeMac --repo-root /path/to/mistral-vibe
```

By default the frontend launches the ACP backend with `VIBE_HOME=$HOME/.vibe` and `VIBE_CONFIG_SOURCE=user`. That makes config resolution use `~/.vibe/config.toml` instead of a project-local `.vibe/config.toml`.

## Build a macOS app bundle

```bash
macos/VibeMac/scripts/build_app.sh
open macos/VibeMac/.build/app/Vibe.app
```

The bundle contains the release Swift binary, `Info.plist`, and a bundled backend at `Contents/Resources/VibeBackend` with `vibe/`, `pyproject.toml`, `uv.lock`, and basic project metadata. At runtime the app prefers this bundled backend when it is launched outside a source checkout.

For a larger bundle that also carries the current virtual environment:

```bash
macos/VibeMac/scripts/build_app.sh --embed-venv
```

When `.venv` is embedded, `VibeMac` runs `Contents/Resources/VibeBackend/.venv/bin/python -m vibe.acp.entrypoint`. Otherwise it uses `uv run python -m vibe.acp.entrypoint` from the bundled backend.

## Backend bridge

The frontend talks to Vibe through ACP JSON-RPC over stdio:

- `initialize`
- `session/new`
- `session/prompt`
- `session/update`
- `session/request_permission`
- `fs/read_text_file`
- `fs/write_text_file`
- `terminal/create`
- `terminal/output`
- `terminal/wait_for_exit`
- `terminal/kill`
- `terminal/release`

## Design and behavior

The app uses the CLI palette, including Mistral orange `#FF8205`, cyan running states, dark translucent surfaces, native blur/vibrancy via `NSVisualEffectView`, and compact card surfaces matching the reference screenshot.

The left rail and composer send native prompts to ACP. Tool calls, permission requests, file edits, usage updates, and assistant chunks are mapped into SwiftUI state rather than rendered as terminal output.
