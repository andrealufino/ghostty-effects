// Focus line — a barely-there band on the current line, with a thin marker
// at the window edge. Slides smoothly when the cursor changes line.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add focus-line

// --- settings
const float DURATION = 0.24;  // seconds for the band to slide to a new line
const float OPACITY  = 0.055; // band strength (0-1); keep it low
const float PADDING  = 0.10;  // extra band height above and below the line, in cursor heights
const float SOFTNESS = 0.45;  // edge feather, in cursor heights
const float MARKER   = 0.55;  // opacity of the marker at the left edge (0 hides it)
const float MARKER_W = 0.07;  // marker width, in cursor heights
const vec3  TINT     = vec3(-1.0); // vec3(-1.0) uses the cursor colour

float easeInOutCubic(float x) {
    return x < 0.5 ? 4.0 * x * x * x : 1.0 - pow(-2.0 * x + 2.0, 3.0) * 0.5;
}

float cursorCenterY(vec4 c) {
    return c.y - c.w * 0.5;
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

    float unit = max(iCurrentCursor.w, 1.0);
    float t = clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0);
    if (iFocus == 0) t = 1.0; // settle at once when unfocused, no frozen half-slide
    float y = mix(cursorCenterY(iPreviousCursor), cursorCenterY(iCurrentCursor), easeInOutCubic(t));

    float halfH = unit * (0.5 + PADDING);
    float soft = SOFTNESS * unit;
    float dy = abs(fragCoord.y - y);
    float band = 1.0 - smoothstep(halfH - soft * 0.5, halfH + soft * 0.5, dy);

    float marker = (1.0 - smoothstep(MARKER_W * unit - 0.5, MARKER_W * unit + 0.5, fragCoord.x))
                 * (1.0 - smoothstep(unit * 0.5 - 0.5, unit * 0.5 + 0.5, dy));

    vec3 tint = TINT.x < 0.0 ? iCurrentCursorColor.rgb : TINT;
    vec3 col = glowBlend(base.rgb, tint, OPACITY * band);
    col = mix(col, tint, MARKER * marker);
    fragColor = vec4(col, base.a);
}
