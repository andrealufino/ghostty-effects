// Shell status — a hairline along the bottom of the window that shows how the
// last long command ended: green when it succeeded, red when it failed. It
// stays until the next command starts, and brightens for a moment when the
// window comes back into focus, so a build left in another tab is easy to read.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add shell-status, then
// source shell/gfx-status.zsh from .zshrc (gfx shell shows the line).

// --- settings
const float THICKNESS    = 2.0;  // line thickness, in pixels
const float GLOW         = 0.35; // soft glow above the line, in cell heights
const float OK_OPACITY   = 0.45; // line strength after a success (0-1)
const float FAIL_OPACITY = 0.70; // line strength after a failure (0-1)
const float PULSE        = 0.80; // extra strength when focus returns (0 = off)
const float PULSE_TIME   = 1.40; // seconds the focus pulse takes to fade
const vec3  OK_COLOR     = vec3(0.62, 0.81, 0.42); // soft green
const vec3  FAIL_COLOR   = vec3(0.97, 0.46, 0.56); // soft red

// --- signal
// shell/gfx-status.zsh writes palette slot 254 as rgb(228, 227, 228 + state),
// one step away from its usual #e4e4e4, so nothing on screen changes.
// Any other value reads as idle.
const int IDLE = 0;
const int OK = 1;
const int FAILED = 2;

int shellState() {
    vec3 c = floor(iPalette[254] * 255.0 + 0.5);
    if (c.r != 228.0 || c.g != 227.0) return IDLE;
    int s = int(c.b) - 228;
    return (s == OK || s == FAILED) ? s : IDLE;
}

vec3 screenBlend(vec3 base, vec3 light) {
    return 1.0 - (1.0 - base) * (1.0 - light);
}

// Adds `tint` at strength `a` in a way that shows on any theme: as light on a
// dark background, as a tint (multiply) on a light one, where light would vanish.
vec3 glowBlend(vec3 base, vec3 tint, float a) {
    bool lightTheme = dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722)) > 0.5;
    return lightTheme ? base * (1.0 - a * (1.0 - tint)) : screenBlend(base, tint * a);
}

// Breaks up 8-bit banding in soft gradients with a fixed, triangular noise of
// about one colour step: invisible on its own, it hides the rings a smooth
// falloff otherwise shows on a flat background.
vec3 dither(vec2 p) {
    float a = fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
    float b = fract(52.9829189 * fract(dot(p.yx + 31.0, vec2(0.06711056, 0.00583715))));
    return vec3((a + b - 1.0) / 255.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    int state = shellState();
    if (state == IDLE) return;

    float unit = iCurrentCursor.w > 1.0 ? iCurrentCursor.w : 18.0;
    float y = fragCoord.y;
    float line = 1.0 - smoothstep(THICKNESS - 0.5, THICKNESS + 0.5, y);
    float shape = max(line, exp(-y / (GLOW * unit)) * 0.5);
    if (shape < 0.002) return;

    // static while unfocused; a single pulse when focus comes back
    float pulse = 0.0;
    float since = iTime - iTimeFocus;
    if (iFocus != 0 && since >= 0.0 && since < PULSE_TIME) {
        float k = since / PULSE_TIME;
        pulse = PULSE * smoothstep(0.0, 0.08, k) * (1.0 - k) * (1.0 - k);
    }

    vec3 color = state == OK ? OK_COLOR : FAIL_COLOR;
    float a = min((state == OK ? OK_OPACITY : FAIL_OPACITY) * (1.0 + pulse), 1.0) * shape;
    vec3 col = glowBlend(base.rgb, color, a);
    if (a > 0.001) col += dither(fragCoord);
    fragColor = vec4(col, base.a);
}
