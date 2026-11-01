// Glide — a short, tapered trail that follows the cursor and dissolves.
// Thin behind a bar cursor, wider behind a block.
//
// Ghostty custom shader (Ghostty 1.4+). Enable with: gfx add glide

// --- settings
const float DURATION   = 0.22;  // seconds the trail takes to catch up with the cursor
const float OPACITY    = 0.40;  // peak trail opacity (0-1)
const float MAX_WIDTH  = 0.40;  // widest half-width at the cursor, in cursor heights
const float MIN_WIDTH  = 0.08;  // narrowest half-width at the cursor (bar cursors), in cursor heights
const float TAIL_RATIO = 0.15;  // tail width as a fraction of the head width
const float MAX_JUMP   = 30.0;  // no trail for jumps longer than this, in cursor heights
const vec3  TINT       = vec3(-1.0); // vec3(-1.0) uses the cursor colour; or e.g. vec3(0.61, 0.81, 0.85)

float easeOutCubic(float x) {
    float a = 1.0 - x;
    return 1.0 - a * a * a;
}

vec2 cursorCenter(vec4 c) {
    // xy is the top-left corner (y grows upwards), zw is width and height
    return vec2(c.x + c.z * 0.5, c.y - c.w * 0.5);
}

float boxSDF(vec2 p, vec2 center, vec2 halfSize) {
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
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

    // nothing while unfocused, and ignore the cursor swap Ghostty makes on focus changes
    if (iFocus == 0 || abs(iTimeCursorChange - iTimeFocus) < 0.05) return;

    float t = (iTime - iTimeCursorChange) / DURATION;
    if (t >= 1.0 || t < 0.0) return;

    float unit = max(iCurrentCursor.w, 1.0);
    vec2 head = cursorCenter(iCurrentCursor);
    vec2 from = cursorCenter(iPreviousCursor);
    float jump = length(head - from);
    if (jump < 0.5 || jump > MAX_JUMP * unit) return;

    float p = easeOutCubic(t);
    vec2 tail = mix(from, head, p);

    // distance to the tail -> head segment, with a tapering width
    vec2 ba = head - tail;
    vec2 pa = fragCoord - tail;
    float k = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
    float d = length(pa - ba * k);
    float headW = clamp(iCurrentCursor.z * 0.5, MIN_WIDTH * unit, MAX_WIDTH * unit);
    float w = mix(TAIL_RATIO, 1.0, k) * headW;
    float shape = 1.0 - smoothstep(w - 1.0, w + 1.0, d);

    // never paint over the cursor itself
    float inside = 1.0 - smoothstep(-0.5, 0.5, boxSDF(fragCoord, head, iCurrentCursor.zw * 0.5));

    float fade = (1.0 - t) * (0.3 + 0.7 * k);
    float a = OPACITY * shape * fade * (1.0 - inside);
    vec3 tint = effectTint(TINT);
    fragColor = vec4(mix(base.rgb, tint, a), base.a);
}
