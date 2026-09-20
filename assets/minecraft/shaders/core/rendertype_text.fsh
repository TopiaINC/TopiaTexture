#version 330

// Vanilla 1.21.11 rendertype_text.fsh, plus the celebration paths.
// Text without a marker colour takes the vanilla branch untouched.

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:globals.glsl>

uniform sampler2D Sampler0;

// Both of these read Sampler0 or GameTime, so they come after those exist.
#moj_import <minecraft:portrait.glsl>
#moj_import <minecraft:celebration.glsl>

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in float drawMode;
in float paramB;

out vec4 fragColor;

const float MODE_PORTRAIT      = 1.0;
const float MODE_PORTRAIT_GLOW = 2.0;
const float MODE_CONFETTI      = 3.0;

void main() {
    if (drawMode >= MODE_CONFETTI) {
        vec4 piece = confettiRender(texCoord0, 1.0, paramB / 255.0);
        if (piece.a < 0.01) discard;
        fragColor = vec4(piece.rgb, piece.a * vertexColor.a);
        return;
    }

    if (drawMode >= MODE_PORTRAIT) {
        float zoom = max(0.05, paramB / 100.0);
        vec2 uv = (texCoord0 - 0.5) * zoom + 0.5;
        vec4 model = portraitRender(uv, 68.0 / 70.0, GameTime);

        // Where the ray misses the model, show the glow instead — that puts it
        // behind the figure without needing a second quad to sort against.
        vec4 shown = model;
        if (model.a < 0.1) {
            if (drawMode < MODE_PORTRAIT_GLOW) discard;
            shown = celebrationGlow(texCoord0, 1.0);
            if (shown.a < 0.01) discard;
        }

        fragColor = vec4(shown.rgb, shown.a * vertexColor.a);  // fades with the title
        return;
    }

    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
}
