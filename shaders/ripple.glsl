// Ripple — a single hairline ring when the cursor lands somewhere new.
// Silent while you type: only jumps of about two cells or more trigger it.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add ripple

// --- settings
const float DURATION  = 0.45;  // seconds
const float SPREAD    = 0.85;  // how far the ring travels, in cursor heights
const float THICKNESS = 0.07;  // ring line width, in cursor heights
const float OPACITY   = 0.60;  // peak ring opacity (0-1)
const float ROUNDING  = 0.16;  // corner radius, in cursor heights
const float MIN_JUMP  = 1.0;   // minimum move that triggers it, in cursor heights (about two cells)
const vec3  TINT      = vec3(-1.0); // vec3(-1.0) uses the cursor colour

float easeOutQuart(float x) {
    float a = 1.0 - x;
    return 1.0 - a * a * a * a;
}

vec2 cursorCenter(vec4 c) {
    return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5);
}

float roundBoxSDF(vec2 p, vec2 center, vec2 halfSize, float r) {
    vec2 d = abs(p - center) - halfSize + r;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
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
    fragColor = base;

    if (iFocus == 0 || abs(iTimeCursorChange - iTimeFocus) < 0.05) return;

    float t = (iTime - iTimeCursorChange) / DURATION;
    if (t >= 1.0 || t < 0.0) return;

    float unit = max(iCurrentCursor.w, 1.0);
    vec2 c = cursorCenter(iCurrentCursor);
    if (length(c - cursorCenter(iPreviousCursor)) < MIN_JUMP * unit) return;

    float p = easeOutQuart(t);
    float grow = SPREAD * unit * p;
    vec2 halfSize = iCurrentCursor.zw * 0.5 + grow;
    float r = min(ROUNDING * unit + grow * 0.6, min(halfSize.x, halfSize.y));
    float sdf = roundBoxSDF(fragCoord, c, halfSize, r);

    float hw = 0.5 * THICKNESS * unit * (1.0 - 0.45 * p) + 0.35;
    float ring = 1.0 - smoothstep(hw - 0.75, hw + 0.75, abs(sdf));

    float fade = (1.0 - t) * (1.0 - t);
    float a = OPACITY * ring * fade;
    vec3 tint = effectTint(TINT);
    fragColor = vec4(mix(base.rgb, tint, a), base.a);
}
