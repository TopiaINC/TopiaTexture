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

// Largest share of grid cells that may hold a piece, per layer. Density scales
// into this. Without a ceiling the screen fills with static.
const float MAX_OCCUPANCY = 0.16;

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
    if (i < 1.0) return vec3(0.96, 0.42, 0.45);   // red
    if (i < 2.0) return vec3(0.99, 0.82, 0.42);   // gold
    if (i < 3.0) return vec3(0.55, 0.85, 0.52);   // green
    if (i < 4.0) return vec3(0.50, 0.76, 0.98);   // blue
    if (i < 5.0) return vec3(0.97, 0.64, 0.86);   // pink
    return vec3(0.97, 0.97, 0.99);                // white
}

// One depth of confetti. The grid scrolls in y with time so a piece drifts from
// one cell into the next and reads as falling; only the pixel's own cell is
// tested, which is what keeps a full-screen effect affordable.
//
// Layer 0 is nearest: biggest, brightest, fastest. Further layers are smaller,
// dimmer and slower, which is what gives the fall any sense of depth.
vec4 confettiLayer(vec2 uv, float t, float layer, float aspect, float occupancy, float sizeScale) {
    float depth = 1.0 - layer * 0.28;                 // 1.00, 0.72, 0.44
    float speed = 0.055 + layer * 0.02;
    vec2 grid = vec2(30.0 * aspect, 18.0) * (1.0 + layer * 0.45);

    vec2 gv = vec2(uv.x * grid.x, uv.y * grid.y + t * speed * grid.y);
    vec2 cell = floor(gv);
    vec2 f = fract(gv) - 0.5;

    float h = celebrationHash(cell + layer * 71.3);
    if (h > occupancy) return vec4(0.0);              // most cells stay empty

    float h2 = celebrationHash(cell + 3.17);
    float h3 = celebrationHash(cell + 7.71);

    vec2 d = f - (vec2(h2, h3) - 0.5) * 0.7;          // jitter within the cell
    d.x *= grid.x / grid.y;                           // square pieces on any screen

    // Tumbling, each piece at its own rate.
    float ang = h2 * 6.2831 + t * (0.9 + h3 * 2.6);
    float c = cos(ang), sn = sin(ang);
    d = mat2(c, -sn, sn, c) * d;

    // A piece is a small rectangle, its size varying a little piece to piece.
    vec2 half = vec2(0.085, 0.052) * (0.75 + h3 * 0.5) * depth * sizeScale;
    if (abs(d.x) > half.x || abs(d.y) > half.y) return vec4(0.0);

    // Edge-on pieces catch less light, which is what sells the tumble.
    float shade = 0.55 + 0.45 * abs(cos(ang * 1.7));
    vec3 col = confettiColour(h) * shade * depth;
    return vec4(col, depth);
}

/**
 * Confetti across the quad.
 * density  0..1, scaled to a sane share of cells rather than used directly —
 *          the first pass filled four cells in five and looked like static.
 * pieceSize 0..1 around a midpoint of 0.5.
 */
vec4 confettiRender(vec2 uv, float aspect, float density, float pieceSize) {
    float t = celebrationSeconds();
    float occupancy = clamp(density, 0.0, 1.0) * MAX_OCCUPANCY;
    float sizeScale = 0.4 + clamp(pieceSize, 0.0, 1.0) * 1.6;
    for (float layer = 0.0; layer < 3.0; layer += 1.0) {
        vec4 piece = confettiLayer(uv, t, layer, aspect, occupancy, sizeScale);
        if (piece.a > 0.0) return piece;              // nearest layer wins
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
