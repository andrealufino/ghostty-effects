# Ghostty Effects

Quiet cursor shaders for [Ghostty](https://ghostty.org), and `gfx`, a small command to switch them on and off.

| Effect       | What it does |
|--------------|--------------|
| `focus-line` | A barely-there band on the current line, with a thin marker at the window edge. Slides when the cursor changes line. |
| `spotlight`  | The window dims gently away from the cursor; the light drifts after it. |
| `glide`      | A short, tapered trail behind the cursor. Thin behind a bar cursor, wider behind a block. |
| `ripple`     | A single hairline ring when the cursor lands somewhere new. Silent while typing. |
| `sheen`      | A reflection crosses the cursor on every move, with a faint halo. Richest on a block cursor. |

Effects stack. Ghostty runs them in sequence, in the order above (ambient first, cursor last), whatever order you type them in.

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
