// Spotlight — the window dims gently away from the cursor, and the light
// drifts after it when it moves.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add spotlight

// --- settings
const float DURATION = 0.60;  // seconds the light takes to follow the cursor
const float STRENGTH = 0.30;  // darkening at the far edges (0-1)
const float INNER    = 0.20;  // fully lit radius, as a fraction of the window height
const float OUTER    = 1.10;  // radius where the dimming peaks, same unit
const float WARMTH   = 0.035; // faint lift of the lit area in the cursor colour (0 = off)
const vec3  TINT     = vec3(-1.0); // vec3(-1.0) uses the cursor colour

float easeInOutCubic(float x) {
    return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5;
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

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec4 base = texture(iChannel0, fragCoord / iResolution.xy);

    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (iFocus == 0) t = 1.0; // settle at once when unfocused
    vec2 light = mix(cursorCenter(iPreviousCursor), cursorCenter(iCurrentCursor), easeInOutCubic(t));

    float dist = length(fragCoord - light) / iResolution.y;
    float dim = smoothstep(INNER, OUTER, dist) * STRENGTH;
    float glow = (1.0 - smoothstep(0.0, INNER, dist)) * WARMTH;

    vec3 tint = effectTint(TINT);
    vec3 col = glowBlend(base.rgb, tint, glow) * (1.0 - dim);
    fragColor = vec4(col, base.a);
}
