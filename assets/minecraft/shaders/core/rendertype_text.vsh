#version 330

// Vanilla 1.21.11 rendertype_text.vsh, plus the player-portrait path.
//
// A text component sent with colour #01GGBB is treated as a portrait rather
// than text. The channels carry parameters, so the server can resize and reframe
// the portrait per title without anyone touching this file:
//
//   R = 1    the marker. Nothing else on screen uses red == 1/255.
//   G        quad size in GUI units, 1-255.
//   B        framing, 100 = head and torso, 200 = full body with legs.

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
out float portraitMask;
out float portraitZoom;

// A glyph is four vertices. corners remaps its UVs to a clean 0..1 square so the
// fragment shader can treat it as a viewport; corners2 pushes the quad outward
// from its centre to make room for the figure.
vec2[4] corners  = vec2[](vec2(0, 0), vec2(0, 1), vec2(1, 1), vec2(1, 0));
vec2[4] corners2 = vec2[](vec2(-1, -1), vec2(-1, 1), vec2(1, 1), vec2(1, -1));

// Colour channels arrive as bytes divided by 255; round-trip them back to whole
// numbers so the server's values survive exactly.
float channel(float c) {
    return floor(c * 255.0 + 0.5);
}

void main() {
    vec3 pos = Position;
    portraitMask = 0.0;
    portraitZoom = 1.0;
    texCoord0 = UV0;
    vertexColor = Color * texelFetch(Sampler2, UV2 / 16, 0);

    if (channel(Color.r) == 1.0) {
        vertexColor.rgb = vec3(1.0);
        texCoord0 = corners[gl_VertexID % 4];
        portraitMask = 1.0;
        portraitZoom = max(0.05, channel(Color.b) / 100.0);
        pos.xy += corners2[gl_VertexID % 4] * max(1.0, channel(Color.g));
    }

    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);

    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);
}
