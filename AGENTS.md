# ghostty-effects

Ghostty shaders (`shaders/`), the `gfx` command that manages them (`bin/gfx`, zsh, macOS), the zsh hooks for `shell-status` (`shell/`), a WebGL preview (`preview/`) and the home page of the published site (`site/`). `.github/workflows/site.yml` compiles every shader on each push and pull request, then publishes `site/`, `preview/` and `media/` to GitHub Pages. README.md explains how each part works and how to add an effect; read it before changing anything.

## Working rules

- Commits carry their human author only: no AI author, co-author, trailer or signature.
- Before committing a shader change, run `gfx check`. It compiles every shader and variant with Ghostty's prefix (it needs `glslang`) and rebuilds `preview/shaders.js`. That file is tracked and served by GitHub Pages, so commit it together with the shader. `gfx on` reloads Ghostty to try the change.
- When behaviour or a command changes, update README.md in the same commit.

## Shaders

- Start with a `// Name — what it does.` header comment: `gfx list` and the preview read it.
- Constants go in a `// --- settings` block, with sizes in cursor heights so they scale with the font.
- Variants are `#if defined(GFX_VARIANT_<NAME>)` branches under a `// --- variants: a normal b` line, holding only the settings that vary. The `#else // normal` branch is the default and carries the comments.
- Effects must read on both light and dark themes: use `glowBlend`, `effectTint` and `dither` as the existing shaders do, and keep `base.a`.
- Skip transient animation while `iFocus == 0`, and when `iTimeCursorChange` equals `iTimeFocus` (the cursor swap Ghostty makes on focus changes).

## gfx

- gfx never writes into the repo or the user's dotfiles at run time: generated files go to `~/.local/state/ghostty-effects/`.
- Rewrite a user's file (Ghostty config, Claude Code settings) only after `backup`, and in place, so symlinks survive.
- What Ghostty loads is built by `shader_source`, for both `apply` and `compile_check`: keep it that way, so what gets checked is exactly what gets loaded.
