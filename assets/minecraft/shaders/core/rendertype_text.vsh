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
#moj_import <minecraft:globals.glsl>

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
out float screenAspect;

// A glyph is four vertices. corners remaps its UVs to a clean 0..1 square so the
// fragment shader can treat it as a viewport; corners2 is the same four corners
// as -1..1, which is also exactly the clip-space bounds of the screen.
vec2[4] corners  = vec2[](vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0));
vec2[4] corners2 = vec2[](vec2(-1, -1), vec2(-1, 1), vec2(1, 1), vec2(1, -1));

// Colour channels arrive as bytes over 255; round-trip them so the server's
// values survive exactly.
float channel(float c) {
    return floor(c * 255.0 + 0.5);
}

void main() {
    vec3 pos = Position;
    drawMode = 0.0;
    paramG = 0.0;
    paramB = 0.0;
    screenAspect = max(0.1, ScreenSize.x / max(1.0, ScreenSize.y));
    texCoord0 = UV0;
    vertexColor = Color * texelFetch(Sampler2, UV2 / 16, 0);

    float mode = channel(Color.r);

    if (mode == 3.0) {
        // Confetti covers the screen, so it ignores where the glyph happens to
        // sit and is written straight to clip space. Expanding a quad by a fixed
        // number of GUI units cannot do this: the right number depends on the
        // window size and the GUI scale, so it was always either short of the
        // edges or wastefully large.
        drawMode = mode;
        paramG = channel(Color.g);
        paramB = channel(Color.b);
        vertexColor.rgb = vec3(1.0);
        texCoord0 = corners[gl_VertexID % 4];
        sphericalVertexDistance = 0.0;
        cylindricalVertexDistance = 0.0;
        gl_Position = vec4(corners2[gl_VertexID % 4], 0.0, 1.0);
        return;
    }

    if (mode == 1.0 || mode == 2.0) {
        vertexColor.rgb = vec3(1.0);
        texCoord0 = corners[gl_VertexID % 4];
        drawMode = mode;
        paramB = channel(Color.b);
        pos.xy += corners2[gl_VertexID % 4] * max(1.0, channel(Color.g));
    }

    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);
}
