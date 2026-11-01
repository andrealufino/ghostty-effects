# Ghostty Effects

Quiet cursor shaders for [Ghostty](https://ghostty.org), and `gfx`, a small command to switch them on and off.

| Effect       | What it does |
|--------------|--------------|
| `focus-line` | A barely-there band on the current line, with a thin marker at the window edge. Slides when the cursor changes line. |
| `spotlight`  | The window dims gently away from the cursor; the light drifts after it. |
| `glide`      | A short, tapered trail behind the cursor. Thin behind a bar cursor, wider behind a block. |
| `ripple`     | A single hairline ring when the cursor lands somewhere new. Silent while typing. |
| `sheen`      | A reflection crosses the cursor on every move, with a faint halo. Richest on a block cursor. |

Two more show what Claude Code is doing, driven by its hooks (see [Claude Code status](#claude-code-status)):

| Effect         | What it does |
|----------------|--------------|
| `claude-frame` | A quiet frame around the window: breathes while Claude works, amber while it waits for a permission, one green flash when the answer is ready. |
| `claude-rail`  | The same states on a single hairline along the top edge, with a light travelling along it while Claude works. |

Effects stack. Ghostty runs them in sequence, in a fixed order (ambient first, cursor last), whatever order you type them in.

## Requirements

- Ghostty 1.4 or newer (the shaders use the `iFocus` and `iTimeFocus` uniforms).
- macOS for `gfx` (it uses `pkill`, `launchctl` and `pmset`). The shaders themselves are cross-platform.
- `python3` for `gfx preview`.
- Optional: `brew install glslang`. With it, `gfx` compiles a shader with Ghostty's own prefix before handing it to Ghostty, so a broken edit never leaves the window black.

## Install

```sh
~/developer/scripts/ghostty-effects/bin/gfx install
```

This does three things:

1. Links `gfx` into `~/.local/bin`.
2. Appends one line to the Ghostty config, in place (a symlinked config stays a symlink):
   ```
   config-file = ?~/.local/state/ghostty-effects/ghostty.conf
   ```
   (written with the absolute path). The `?` makes it optional: no file, no effects.
3. Creates the state folder, with no effect selected.

The generated include and the selection live in `~/.local/state/ghostty-effects/`, outside this repo and outside the dotfiles, so switching effects never dirties `git status`.

## Use

```sh
gfx                       # what is on
gfx list                  # the effects
gfx set focus-line glide  # use exactly these
gfx add ripple            # add one
gfx rm ripple             # remove one
gfx off                   # everything off, selection kept
gfx on                    # back on
gfx toggle                # for a hotkey (Raycast, Shortcuts)
gfx auto on               # pause effects on battery, resume on power
gfx preview               # open the interactive preview
gfx check                 # compile every shader with Ghostty's prefix
```

Every change rewrites the include and reloads Ghostty with `SIGUSR2`, the same as Cmd+Shift+,.

`gfx auto on` installs a LaunchAgent (`com.andrealufino.ghostty-effects.power`) that checks the power source once a minute. `gfx off` always wins: the agent never turns on effects you switched off.

## Claude Code status

```sh
gfx claude on           # add the hooks to ~/.claude/settings.json
gfx add claude-frame    # or claude-rail
```

The hooks run `gfx hook <state>` asynchronously, so they never slow Claude down. A hook has no terminal of its own, so `gfx hook` walks up the process tree to the Claude Code session's terminal and writes the signal there: every tab carries its own state. (Claude Code's `terminalSequence` hook field would be tidier, but it only passes title sequences and ignores async hooks; tested with Claude Code 2.1.314.)

| Hook | State | Signal |
|------|-------|--------|
| `SessionStart`, `SessionEnd` | idle | resets palette slot 255 and the cursor colour |
| `UserPromptSubmit`, `PreToolUse`, `PostToolUse` | working | slot 255 = `rgb(238, 237, 237)` |
| `Notification` (`permission_prompt`) | waiting | slot 255 = `rgb(238, 237, 238)` |
| `Stop` | done | slot 255 = `rgb(238, 237, 239)`, cursor tinted for 0.12 s, idle again after 1.6 s unless a new prompt came in |

Palette slot 255 is normally `#eeeeee`; the state moves it by one step, which nothing on screen shows. The shaders decode it from `iPalette[255]`. A shader cannot remember when something happened, so the done hook briefly tints the cursor: Ghostty stamps `iTimeCursorChange`, and the flash runs from that moment.

The hooks sit beside any others in the settings file. `gfx claude off` removes exactly the entries that run `gfx hook`. Limits: after an approved permission the state stays amber until the tool finishes (`PostToolUse` is the first event after approval), and interrupting Claude with Esc fires no `Stop`, so the state stays on working until the next prompt.

## Preview

Open `preview/index.html`, or run `gfx preview`. The page runs the same GLSL files in WebGL with Ghostty's cursor uniforms. It has a bar/block cursor switch, slow motion, cursor colours, and a terminal you can type in.

The page reads two generated files next to it:

- `preview/shaders.js`, the shaders bundled for the browser. It is tracked, so the page works straight from a clone. `gfx preview`, `gfx check`, `set`, `add` and `rm` rebuild it; after editing a shader, run one of them (or `gfx preview`) so the page shows the edit.
- `preview/state.js`, the selection active in Ghostty, so the page starts from it. Untracked.

## Tune

Each shader starts with a `// --- settings` block of constants: duration, opacity, sizes (in cursor heights, so they scale with the font), and an optional `TINT` (`vec3(-1.0)` follows the cursor colour). Edit, then `gfx on` to reload. `gfx preview` shows the change before Ghostty does.

## Add an effect

1. Drop `name.glsl` into `shaders/`. Start it with a header comment, `// Name — what it does.`: `gfx list` and the preview read it.
2. Write a Shadertoy-style `mainImage(out vec4 fragColor, in vec2 fragCoord)`. Read the screen with `texture(iChannel0, fragCoord / iResolution.xy)` and keep `base.a` so background opacity still works.
3. Cursor rectangles are `xy` = top-left corner (y grows upwards), `zw` = width and height. Skip transient animation when `iFocus == 0` or when `iTimeCursorChange` equals `iTimeFocus` (Ghostty swaps to a hollow cursor on focus changes).
4. Add the name to `ORDER` in `bin/gfx` if it should not run after the others.
5. `gfx check name`, then `gfx preview`.

`tools/ghostty-prefix.glsl` is Ghostty's shader prefix, copied from upstream. If a future Ghostty adds uniforms, refresh it from `src/renderer/shaders/shadertoy_prefix.glsl`.

## Uninstall

```sh
gfx uninstall
```

Removes the config line, the LaunchAgent, the link and the state. The repo stays.
