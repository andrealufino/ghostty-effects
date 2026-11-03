// Focus return — when the window comes back into focus, the edges dim for a
// moment and the light closes in on the cursor, so you see where you left off.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add focus-return

// --- settings
const float DURATION = 0.85;  // seconds, from focus until the window is clear again
const float STRENGTH = 0.34;  // peak dimming away from the cursor (0-1)
const float START    = 1.10;  // radius of the light as focus returns, as a fraction of the window height
const float END      = 0.10;  // radius it closes in to, same unit
const float SOFTNESS = 0.30;  // softness of the light's edge, same unit
const float RING     = 0.22;  // a faint ring at the light's edge, in the effect colour (0 = off)
const vec3  TINT     = vec3(-1.0); // vec3(-1.0) uses the cursor colour

float easeOutCubic(float x) {
    float a = 1.0 - x;
    return 1.0 - a * a * a;
}

vec2 cursorCenter(vec4 c) {
    return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5);
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

    // only on the way in: iTimeFocus also moves when the window loses focus
    if (iFocus == 0) return;
    float t = (iTime - iTimeFocus) / DURATION;
    if (t >= 1.0 || t < 0.0) return;

    float radius = mix(START, END, easeOutCubic(clamp(t / 0.75, 0.0, 1.0)));
    float envelope = smoothstep(0.0, 0.10, t) * (1.0 - smoothstep(0.50, 1.0, t));

    float dist = length(fragCoord - cursorCenter(iCurrentCursor)) / iResolution.y;
    float dim = smoothstep(radius, radius + SOFTNESS, dist) * STRENGTH * envelope;
    float q = (dist - radius) / 0.012;
    float ring = exp(-q * q) * RING * envelope;

    vec3 col = glowBlend(base.rgb, effectTint(TINT), ring) * (1.0 - dim);
    if (dim + ring > 0.001) col += dither(fragCoord);
    fragColor = vec4(col, base.a);
}
