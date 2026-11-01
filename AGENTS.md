# ghostty-effects

Ghostty cursor shaders (`shaders/`), the `gfx` command (`bin/gfx`) and a WebGL preview (`preview/`). See README.md.

## Working rules

- Commit and push to `main` without asking for confirmation.
- Commits are authored by Andrea Mario Lufino only: no AI author, co-author, trailer or signature.
- Before committing a shader change, run `gfx check` (compiles every shader with Ghostty's prefix) and `gfx on` (reloads Ghostty and rebuilds `preview/shaders.js`).
- Shaders must work on both light and dark themes: use `glowBlend`, `effectTint` and `dither` like the existing ones.
