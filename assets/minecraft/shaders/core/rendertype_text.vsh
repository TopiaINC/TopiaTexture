#version 330

// Vanilla 1.21.11 rendertype_text.vsh, plus the celebration paths.
//
// A text component's colour is read as parameters rather than as a colour. The
// red channel picks which path to draw; nothing else on screen uses these
// values, so ordinary text is untouched.
//
//   R = 1   player portrait
//   R = 2   player portrait with the glow behind it
//   R = 3   full-screen confetti
//
//   G       portraits: quad size in GUI units, 1-255
//           confetti: piece size
//   B       portraits: framing, 100 head and torso, 200 down to the feet
//           confetti: density

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:projection.glsl>

in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;

uniform sampler2D Sampler2;

out float sphericalVertexDistance;
out float cylindricalVertexDistance;
out vec4 vertexColor;
out vec2 texCoord0;
out float drawMode;
out float paramG;
out float paramB;

// A glyph is four vertices. corners remaps its UVs to a clean 0..1 square so the
// fragment shader can treat it as a viewport; corners2 is the same four corners
// as -1..1, which is also exactly the clip-space bounds of the screen.
vec2[4] corners  = vec2[](vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0));
vec2[4] corners2 = vec2[](vec2(-1, -1), vec2(-1, 1), vec2(1, 1), vec2(1, -1));

// Colour channels arrive as bytes over 255; round-trip them so the server's
// values survive exactly.
// The arrival curve, as multiples of the portrait's normal size.
//
// One motion: grow smoothly, overshoot once, settle. An earlier version built,
// dipped, then peaked — three changes of direction on the way in, and because
// the shader runs the curve in reverse on the way out, six in total. It read as
// wobbling rather than as a pop.
//
// The curve also finishes before the fade does (POP_SPAN). Past that point the
// size is simply 1.0, so on the way out the figure holds its size while it dims
// and only shrinks once it is nearly invisible — which keeps the reverse from
// being read as a second animation.
const float POP_START = 0.45;   // size on the first visible frame
const float POP_BACK  = 2.6;    // overshoot strength; 0 removes it entirely
const float POP_SPAN  = 0.85;   // fraction of the fade the curve occupies

float portraitPop(float fade) {
    float t = clamp(fade / POP_SPAN, 0.0, 1.0);
    // Back-ease: a cubic that rises, passes 1.0, and returns to it.
    float u = t - 1.0;
    float eased = 1.0 + (POP_BACK + 1.0) * u * u * u + POP_BACK * u * u;
    return mix(POP_START, 1.0, eased);
}

float channel(float c) {
    return floor(c * 255.0 + 0.5);
}

void main() {
    vec3 pos = Position;
    drawMode = 0.0;
    paramG = 0.0;
    paramB = 0.0;
    texCoord0 = UV0;
    vertexColor = Color * texelFetch(Sampler2, UV2 / 16, 0);

    float mode = channel(Color.r);

    if (mode >= 1.0 && mode <= 3.0) {
        vertexColor.rgb = vec3(1.0);
        texCoord0 = corners[gl_VertexID % 4];
        drawMode = mode;
        paramG = channel(Color.g);
        paramB = channel(Color.b);

        float expand;
        if (mode == 3.0) {
            // Confetti has to cover the screen. A fixed number of GUI units
            // cannot: how many span a screen depends on the window size and the
            // GUI scale, so a constant is always either short of the edges or
            // wastefully large.
            //
            // The GUI transform is orthographic, so its diagonal gives the
            // conversion directly — 2.0 clip units is the full screen, and
            // mvp[0][0] is how much clip one GUI unit buys. Expanding by the
            // whole span in both axes covers the screen from wherever the glyph
            // happens to sit, without leaving the normal transform behind.
            mat4 mvp = ProjMat * ModelViewMat;
            float unitsX = 2.0 / max(1.0e-6, abs(mvp[0][0]));
            float unitsY = 2.0 / max(1.0e-6, abs(mvp[1][1]));
            expand = max(unitsX, unitsY);
        } else {
            expand = max(1.0, channel(Color.g));

            // The arrival pop. Color's alpha carries the title's fade, which
            // is the only clock the shader has, so the curve is driven from it.
            //
            // This has to live here. Animating it from the server means
            // re-sending the title every tick, and Gui.setTitle resets the
            // animation timer, so the fade restarts each time and it flickers.
            //
            // The fade only tells us how visible the figure is, not which
            // direction it is heading, so the same curve runs in reverse on the
            // way out — the figure swings up and shrinks away rather than just
            // dimming.
            float fade = clamp(Color.a, 0.0, 1.0);
            expand *= portraitPop(fade);
        }
        pos.xy += corners2[gl_VertexID % 4] * expand;
    }

    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);
}
