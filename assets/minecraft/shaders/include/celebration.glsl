// Screen-space confetti and the glow behind the podium figures.
//
// Both are generated in the fragment shader rather than spawned in the world.
// World particles sit at world coordinates while the portrait is drawn in the
// title layer, so they can never line up with it — turn your head and the
// confetti swings away while the figure stays put. Generated here, they share
// the figure's space and hold still relative to it.
//
// Needs <minecraft:globals.glsl> for GameTime.

// Overall glow brightness. The first pass was a small hard disc with a white
// core; this is dimmer and wider so it reads as a backlight rather than a lamp.
const float GLOW_STRENGTH = 0.42;

// GameTime runs 0..1 across a 20-minute Minecraft day. Seconds are far easier
// to reason about for fall speeds and spin rates.
float celebrationSeconds() {
    return GameTime * 1200.0;
}

float celebrationHash(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 34.56);
    return fract(p.x * p.y);
}

vec3 confettiColour(float h) {
    float i = floor(h * 6.0);
    if (i < 1.0) return vec3(1.00, 0.30, 0.32);   // red
    if (i < 2.0) return vec3(1.00, 0.82, 0.25);   // gold
    if (i < 3.0) return vec3(0.42, 0.85, 0.38);   // green
    if (i < 4.0) return vec3(0.38, 0.72, 1.00);   // blue
    if (i < 5.0) return vec3(1.00, 0.55, 0.85);   // pink
    return vec3(1.00, 1.00, 1.00);                // white
}

// One depth of confetti. The grid is scrolled in y by time, so a piece drifts
// from one cell into the next and reads as falling; only the pixel's own cell is
// tested, which keeps this cheap enough to run over the whole screen.
vec4 confettiLayer(vec2 uv, float t, float layer, float aspect, float density) {
    float speed = 0.09 + layer * 0.045;
    vec2 grid = vec2(16.0, 9.0) * (1.0 + layer * 0.4);

    vec2 gv = vec2(uv.x * grid.x, uv.y * grid.y + t * speed * grid.y);
    vec2 cell = floor(gv);
    vec2 f = fract(gv) - 0.5;

    float h = celebrationHash(cell + layer * 71.3);
    if (h > density) return vec4(0.0);            // most cells stay empty

    vec2 jitter = (vec2(celebrationHash(cell + 3.1), celebrationHash(cell + 7.7)) - 0.5) * 0.55;
    vec2 d = f - jitter;
    d.x *= aspect * grid.y / grid.x;              // keep pieces square on any screen

    // Tumbling, each piece at its own rate.
    float ang = h * 6.2831 + t * (1.2 + h * 3.5);
    float c = cos(ang), s = sin(ang);
    d = mat2(c, -s, s, c) * d;

    if (abs(d.x) > 0.17 || abs(d.y) > 0.11) return vec4(0.0);

    // Edge-on pieces catch less light, which sells the tumble.
    float shade = 0.65 + 0.35 * abs(cos(ang * 1.7));
    return vec4(confettiColour(h) * shade, 1.0);
}

/** Confetti across a quad. density 0..1, higher is busier. */
vec4 confettiRender(vec2 uv, float aspect, float density) {
    float t = celebrationSeconds();
    float keep = 1.0 - clamp(density, 0.0, 1.0) * 0.35;   // hash threshold
    for (float layer = 0.0; layer < 3.0; layer += 1.0) {
        vec4 piece = confettiLayer(uv, t, layer, aspect, keep);
        if (piece.a > 0.0) return piece;                  // nearest layer wins
    }
    return vec4(0.0);
}

/**
 * The glow behind the figures: a warm radial falloff with slowly turning rays,
 * matching the sunburst in the reference footage. Drawn where the portrait's ray
 * misses the model, so it sits behind without a second quad.
 */
vec4 celebrationGlow(vec2 uv, float strength) {
    vec2 p = uv - 0.5;
    float r = length(p);
    float a = atan(p.y, p.x);
    float t = celebrationSeconds();

    // Reaches the quad's corners (0.707) rather than stopping short of the
    // figure, and the falloff starts from the centre so there is no bright core.
    float rays = 0.70 + 0.30 * sin(a * 11.0 + t * 0.35);
    float falloff = smoothstep(0.72, 0.0, r);
    falloff *= falloff;                       // long soft tail instead of a disc
    float intensity = falloff * (0.55 + 0.45 * rays) * strength * GLOW_STRENGTH;

    // Warm gold throughout; the white core was what read as too bright.
    return vec4(vec3(1.00, 0.80, 0.42), clamp(intensity, 0.0, 1.0));
}
