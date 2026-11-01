// Sheen — a light reflection crosses the cursor on every move, and a faint
// halo keeps it softly lit. Richest on a block cursor; a glint on a bar.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add sheen

// --- settings
const float DURATION  = 0.34;  // seconds for the reflection to cross the cursor
const float SHEEN     = 0.55;  // reflection brightness (0-1)
const float WIDTH     = 0.18;  // reflection band width, as a fraction of the cursor
const float SLANT     = 0.55;  // diagonal slant of the reflection
const float HALO      = 0.12;  // halo strength around the cursor (0 = off)
const float HALO_SIZE = 0.30;  // halo reach, in cursor heights
const vec3  TINT      = vec3(-1.0); // halo colour; vec3(-1.0) uses the cursor colour

float easeInOutSine(float x) {
    return 0.5 - 0.5 * cos(3.14159265 * x);
}

float boxSDF(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
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
    vec4 c = iCurrentCursor;
    float unit = max(c.w, 1.0);
    vec2 center = vec2(c.x + c.z * 0.5, c.y - c.w * 0.5);
    float sdf = boxSDF(fragCoord, center, c.zw * 0.5);
    vec3 tint = effectTint(TINT);
    vec3 col = base.rgb;

    // halo, outside the cursor only, and only while focused
    if (iFocus != 0) {
        float outside = smoothstep(0.0, 1.0, sdf);
        col = glowBlend(col, tint, HALO * exp(-max(sdf, 0.0) / (HALO_SIZE * unit)) * outside);
    }

    // reflection, inside the cursor only
    float t = (iTime - iTimeCursorChange) / DURATION;
    bool focusSwap = abs(iTimeCursorChange - iTimeFocus) < 0.05;
    if (iFocus != 0 && !focusSwap && t >= 0.0 && t < 1.0) {
        vec2 uv = vec2((fragCoord.x - c.x) / max(c.z, 1.0), (c.y - fragCoord.y) / unit);
        float s = uv.x + uv.y * SLANT;
        float pos = mix(-WIDTH * 2.0, 1.0 + SLANT + WIDTH * 2.0, easeInOutSine(t));
        float q = (s - pos) / WIDTH;
        float band = exp(-q * q);
        float inside = 1.0 - smoothstep(-0.5, 0.5, sdf);
        col = screenBlend(col, vec3(SHEEN * band * inside));
    }

    fragColor = vec4(col, base.a);
}
