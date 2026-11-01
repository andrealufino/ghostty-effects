// Claude frame — a quiet frame around the window that shows what Claude Code
// is doing: it breathes while Claude works, turns amber while it waits for
// you, and flashes once when the answer is ready.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add claude-frame, then gfx claude on.

// --- settings
const float REACH        = 0.55; // glow reach from the edge, in cell heights
const float WORK_OPACITY = 0.38; // peak glow while Claude works (0-1)
const float WAIT_OPACITY = 0.50; // glow while Claude waits for you (0-1)
const float DONE_OPACITY = 0.70; // peak of the flash when Claude is done (0-1)
const float BREATH       = 3.2;  // seconds per breath while working
const float DONE_TIME    = 1.2;  // seconds the done flash takes to fade
const vec3  WORK_COLOR   = vec3(-1.0);             // vec3(-1.0) uses the cursor colour
const vec3  WAIT_COLOR   = vec3(0.90, 0.72, 0.44); // amber
const vec3  DONE_COLOR   = vec3(0.62, 0.81, 0.42); // soft green

// --- signal
// The hooks write the state into palette slot 255 as rgb(238, 237, 236 + state),
// one step away from its usual #eeeeee, so nothing on screen changes.
// Any other value reads as idle.
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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);
    fragColor = base;

    int state = claudeState();
    if (state == IDLE) return;

    float unit = iCurrentCursor.w > 1.0 ? iCurrentCursor.w : 18.0;
    vec2 p = fragCoord;
    float d = min(min(p.x, iResolution.x - p.x), min(p.y, iResolution.y - p.y));
    float glow = exp(-d / (REACH * unit));
    float hairline = 1.0 - smoothstep(1.0, 2.5, d);
    float edge = max(glow * 0.7, hairline);

    vec3 color;
    float a;
    if (state == WORKING) {
        color = WORK_COLOR.x < 0.0 ? iCurrentCursorColor.rgb : WORK_COLOR;
        float breath = 0.5 + 0.5 * sin(6.2831853 * iTime / BREATH);
        a = WORK_OPACITY * (iFocus == 0 ? 0.6 : mix(0.35, 1.0, breath));
    } else if (state == WAITING) {
        color = WAIT_COLOR;
        a = WAIT_OPACITY;
    } else {
        color = DONE_COLOR;
        float t = (iTime - iTimeCursorChange) / DONE_TIME;
        if (t < 0.0 || t >= 1.0) return;
        a = DONE_OPACITY * smoothstep(0.0, 0.08, t) * (1.0 - t) * (1.0 - t);
    }

    fragColor = vec4(glowBlend(base.rgb, color, a * edge), base.a);
}
