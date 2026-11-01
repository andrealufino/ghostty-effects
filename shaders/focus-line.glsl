// Focus line — a barely-there highlight on the current line, held to its own
// row, fading out a little past the cursor. Slides when the cursor changes line.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add focus-line

// --- settings
const float DURATION = 0.24;  // seconds for the highlight to slide to a new line
const float OPACITY  = 0.07;  // highlight strength (0-1); keep it low
const float EDGE     = 1.0;   // top and bottom edge softness, in pixels (keeps it to one row)
const float TRAIL    = 14.0;  // how far it runs past the cursor before it has faded out, in cursor heights
const float MARKER   = 0.55;  // opacity of the marker at the left edge (0 hides it)
const float MARKER_W = 0.07;  // marker width, in cursor heights
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

    float unit = max(iCurrentCursor.w, 1.0);
    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (iFocus == 0) t = 1.0; // settle at once when unfocused, no frozen half-slide
    vec2 at = mix(cursorCenter(iPreviousCursor), cursorCenter(iCurrentCursor), easeInOutCubic(t));

    // vertically: exactly the cursor's row, with a hairline-soft edge
    float dy = abs(fragCoord.y - at.y);
    float row = 1.0 - smoothstep(unit * 0.5 - EDGE, unit * 0.5 + EDGE, dy);

    // horizontally: full up to the cursor, then a long, gentle fade
    float run = (fragCoord.x - at.x) / (TRAIL * unit);
    float fade = 1.0 - smoothstep(0.0, 1.0, run);
    fade *= fade;

    float marker = (1.0 - smoothstep(MARKER_W * unit - 0.5, MARKER_W * unit + 0.5, fragCoord.x)) * row;

    vec3 tint = effectTint(TINT);
    float amount = OPACITY * row * fade;
    vec3 col = glowBlend(base.rgb, tint, amount);
    col = mix(col, tint, MARKER * marker);
    if (amount > 0.001) col += dither(fragCoord);
    fragColor = vec4(col, base.a);
}
