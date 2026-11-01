// Claude rail — a hairline along the top of the window that shows what Claude
// Code is doing: a slow light travels along it while Claude works, it turns
// amber while Claude waits for you, and a single sweep marks the answer.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add claude-rail, then gfx claude on.

// --- settings
const float THICKNESS    = 3.0;  // rail thickness, in pixels
const float GLOW         = 0.30; // soft glow under the rail, in cell heights
const float WORK_BASE    = 0.10; // rail brightness at rest while working (0-1)
const float WORK_LIGHT   = 0.75; // brightness of the travelling light (0-1)
const float WORK_PERIOD  = 2.6;  // seconds for the light to cross the window
const float WAIT_OPACITY = 0.65; // rail brightness while Claude waits for you (0-1)
const float DONE_OPACITY = 0.85; // brightness of the done sweep (0-1)
const float DONE_TIME    = 1.1;  // seconds for the sweep and its fade
const vec3  WORK_COLOR   = vec3(-1.0);             // vec3(-1.0) uses the cursor colour; gfx color overrides
const vec3  WAIT_COLOR   = vec3(0.90, 0.72, 0.44); // amber
const vec3  DONE_COLOR   = vec3(0.62, 0.81, 0.42); // soft green

// --- signal (see claude-frame.glsl)
const int IDLE = 0;
const int WORKING = 1;
const int WAITING = 2;
const int DONE = 3;

int claudeState() {
    vec3 c = floor(iPalette[255] * 255.0 + 0.5);
    if (c.r != 238.0 || c.g != 237.0) return IDLE;
    int s = int(c.b) - 236;
    return (s >= WORKING && s <= DONE) ? s : IDLE;
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

// The effect colour. `gfx color` injects GFX_TINT_DARK and GFX_TINT_LIGHT, one
// per theme; otherwise the constant above, or the cursor colour for vec3(-1.0).
vec3 effectTint(vec3 configured) {
#ifdef GFX_TINT_DARK
    return dot(iBackgroundColor, vec3(0.2126, 0.7152, 0.0722)) > 0.5 ? GFX_TINT_LIGHT : GFX_TINT_DARK;
#else
    return configured.x < 0.0 ? iCurrentCursorColor.rgb : configured;
#endif
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

    int state = claudeState();
    if (state == IDLE) return;

    float unit = iCurrentCursor.w > 1.0 ? iCurrentCursor.w : 18.0;
    float fromTop = iResolution.y - fragCoord.y;
    float rail = 1.0 - smoothstep(THICKNESS - 0.5, THICKNESS + 0.5, fromTop);
    float shape = max(rail, exp(-fromTop / (GLOW * unit)) * 0.55);
    float x = fragCoord.x / iResolution.x;

    vec3 color;
    float a;
    if (state == WORKING) {
        color = effectTint(WORK_COLOR);
        float light = 0.0;
        if (iFocus != 0) {
            float head = fract(iTime / WORK_PERIOD) * 1.6 - 0.3;
            float q = (x - head) / 0.14;
            light = exp(-q * q);
        }
        a = WORK_BASE + WORK_LIGHT * light;
    } else if (state == WAITING) {
        color = WAIT_COLOR;
        a = WAIT_OPACITY;
    } else {
        color = DONE_COLOR;
        float t = (iTime - iTimeCursorChange) / DONE_TIME;
        if (t < 0.0 || t >= 1.0) return;
        float head = smoothstep(0.0, 0.55, t) * 1.2 - 0.1;
        float lit = 1.0 - smoothstep(head - 0.25, head + 0.02, x); // filled behind the head
        float q = (x - head) / 0.06;
        a = DONE_OPACITY * max(exp(-q * q), lit * 0.45) * (1.0 - smoothstep(0.55, 1.0, t));
    }

    vec3 col = glowBlend(base.rgb, color, a * shape);
    if (a * shape > 0.001) col += dither(fragCoord);
    fragColor = vec4(col, base.a);
}
