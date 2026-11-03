# Ghostty Effects

Quiet cursor shaders for [Ghostty](https://ghostty.org), and `gfx`, a small command to switch them on and off.

| Effect       | What it does |
|--------------|--------------|
| `focus-line` | A barely-there highlight on the current line, held to its own row and fading out a little past the cursor, with a thin marker at the window edge. Slides when the cursor changes line. |
| `spotlight`  | The window dims gently away from the cursor; the light drifts after it. |
| `glide`      | A short, tapered trail behind the cursor. Thin behind a bar cursor, wider behind a block. |
| `ripple`     | A single hairline ring when the cursor lands somewhere new. Silent while typing. |
| `sheen`      | A reflection crosses the cursor on every move, with a faint halo. Richest on a block cursor. |
| `focus-return` | When the window comes back into focus, the edges dim for a moment and the light closes in on the cursor. |

Two more show what Claude Code is doing, driven by its hooks (see [Claude Code status](#claude-code-status)):

| Effect         | What it does |
|----------------|--------------|
| `claude-frame` | A quiet frame around the window: breathes while Claude works, amber while it waits for a permission, one green flash when the answer is ready. |
| `claude-rail`  | The same states on a single hairline along the top edge, with a light travelling along it while Claude works. |

And one shows how the last long shell command ended, driven by a few zsh hooks (see [Shell status](#shell-status)):

| Effect         | What it does |
|----------------|--------------|
| `shell-status` | A hairline along the bottom edge: green after a long command succeeds, red after it fails. Stays until the next command, and brightens for a moment when the window regains focus. |

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
gfx add spotlight:wide    # add one, in a variant
gfx rm ripple             # remove one
gfx variant spotlight     # an effect's variants, the one in use marked
gfx variant spotlight wide # use that variant
gfx off                   # everything off, selection kept
gfx on                    # back on
gfx toggle                # for a hotkey (Raycast, Shortcuts)
gfx color #9ccfd8         # effect colour for both themes
gfx color #9ccfd8 #008ec4 # one for dark themes, one for light themes
gfx color default         # follow the cursor colour again
gfx color                 # show the current colour
gfx cursor #ff9e64        # cursor colour, for both themes
gfx cursor #ff9e64 #c2410c # one for the dark theme, one for the light theme
gfx cursor default        # back to the theme's cursor colour
gfx auto on               # pause effects on battery, resume on power
gfx preview               # open the interactive preview
gfx check                 # compile every shader and variant with Ghostty's prefix
```

Every change rewrites the include and reloads Ghostty with `SIGUSR2`, the same as Cmd+Shift+,.

By default the effects take the cursor colour of the active theme. `gfx color` overrides it without touching the repo: gfx writes copies of the active shaders to `~/.local/state/ghostty-effects/shaders/` with `GFX_TINT_DARK` and `GFX_TINT_LIGHT` defined at the top, and Ghostty loads those. Each shader picks one of the two from the terminal background, so the colour follows light and dark mode. The Claude effects keep amber for waiting and green for done; the colour applies to their working state. After editing a shader while a colour is set, run `gfx on` to refresh the copies.

`gfx cursor` sets the cursor colour through the same include, and it stays in place when the effects are off. With one colour it is a plain `cursor-color` line. With two, it needs a detour: `cursor-color` has no light/dark form, so gfx reads the `theme = light:…,dark:…` pair from the main Ghostty config, writes copies of those two themes to `~/.local/state/ghostty-effects/themes/` with the cursor colour added, and points `theme` at the copies. The copies are rebuilt on every gfx command, so after changing the theme in the main config, run `gfx on`. While no effect colour is set, the effects follow the cursor colour too.

## Variants

Some effects come in variants, picked by name:

| Effect       | Variants | |
|--------------|----------|-|
| `spotlight`  | `focused`, `normal`, `wide` | from a small pool of light around the cursor to a vignette that only shades the far corners |
| `focus-line` | `subtle`, `normal`, `strong` | from barely there to readable at a glance on a busy screen |
| `glide`      | `short`, `normal`, `long` | from a flick behind the cursor to a visible streak |

`normal` is the plain settings, used when no variant is chosen. Choose one with `gfx variant spotlight wide`, or while adding the effect with `gfx add spotlight:wide` (also in `gfx set`). A variant belongs to the effect, not to the selection: it stays when the effect is removed and added again by its bare name, until another one is chosen. `gfx` shows each effect with its variant, as `spotlight:wide`.

Like the colour, a variant never touches the repo: gfx writes a copy of the shader to `~/.local/state/ghostty-effects/shaders/` with `GFX_VARIANT_WIDE` defined at the top. The choices are kept in `~/.local/state/ghostty-effects/variants`.

## Battery

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

## Shell status

```sh
gfx shell               # shows the line to add to .zshrc
gfx add shell-status
```

`shell/gfx-status.zsh` adds a `preexec` and a `precmd` hook, and does nothing outside Ghostty. After a command that ran for `GFX_STATUS_MIN` seconds or more (default 10, set it before the `source` line), it writes the outcome into palette slot 254, the same trick as the Claude effects:

| Outcome | Signal |
|---------|--------|
| success | slot 254 = `rgb(228, 227, 229)` |
| failure | slot 254 = `rgb(228, 227, 230)` |
| next command starts | slot 254 reset to the theme's `#e4e4e4` |

Ctrl-C (exit 130) and Ctrl-Z (148) count as neither. The `precmd` hook goes first in `precmd_functions` and returns the command's own exit status, so prompts that read `$?` see it unchanged. gfx does not edit `.zshrc` for you: it is often a dotfiles symlink.

The line is static while the window is in the background, so it costs nothing there; the focus pulse only runs while the window is focused.

## Preview

Open `preview/index.html`, or run `gfx preview`. The page runs the same GLSL files in WebGL with Ghostty's cursor uniforms. It has a bar/block cursor switch, slow motion, cursor colours, the variants of each effect, a focus switch (to see `focus-return`, and what the others do in the background), the Claude and shell states, and a terminal you can type in.

The page reads two generated files next to it:

- `preview/shaders.js`, the shaders bundled for the browser. It is tracked, so the page works straight from a clone. `gfx preview`, `gfx check`, `set`, `add` and `rm` rebuild it; after editing a shader, run one of them (or `gfx preview`) so the page shows the edit.
- `preview/state.js`, the selection, variants and colour active in Ghostty, so the page starts from them. Untracked.

## Tune

Each shader starts with a `// --- settings` block of constants: duration, opacity, sizes (in cursor heights, so they scale with the font), and an optional `TINT` (`vec3(-1.0)` follows the cursor colour). Effects with variants keep the settings that vary in a `// --- variants` block below it, one `#if` branch per variant; the `#else // normal` branch carries the comments. Edit, then `gfx on` to reload. `gfx preview` shows the change before Ghostty does.

## Add an effect

1. Drop `name.glsl` into `shaders/`. Start it with a header comment, `// Name — what it does.`: `gfx list` and the preview read it.
2. Write a Shadertoy-style `mainImage(out vec4 fragColor, in vec2 fragCoord)`. Read the screen with `texture(iChannel0, fragCoord / iResolution.xy)` and keep `base.a` so background opacity still works.
3. Cursor rectangles are `xy` = top-left corner (y grows upwards), `zw` = width and height. Skip transient animation when `iFocus == 0` or when `iTimeCursorChange` equals `iTimeFocus` (Ghostty swaps to a hollow cursor on focus changes).
4. Optionally, give it variants. Under the settings, add a line naming them, `normal` included, then one branch each for the settings that change:
   ```glsl
   // --- variants: soft normal bold
   #if defined(GFX_VARIANT_SOFT)
   const float OPACITY = 0.20;
   #elif defined(GFX_VARIANT_BOLD)
   const float OPACITY = 0.60;
   #else // normal
   const float OPACITY = 0.40;  // peak opacity (0-1)
   #endif
   ```
   gfx and the preview read the names from that line and define `GFX_VARIANT_<NAME>` for the one chosen.
5. Add the name to `ORDER` in `bin/gfx` if it should not run after the others.
6. `gfx check name` (it compiles every variant), then `gfx preview`.

`tools/ghostty-prefix.glsl` is Ghostty's shader prefix, copied from upstream. If a future Ghostty adds uniforms, refresh it from `src/renderer/shaders/shadertoy_prefix.glsl`.

## Uninstall

```sh
gfx uninstall
```

Removes the config line, the LaunchAgent, the link and the state. The repo stays.
