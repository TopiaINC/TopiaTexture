#version 330

// Vanilla 1.21.11 rendertype_text.fsh, plus the player-portrait path.
// Text not carrying the portrait marker takes the vanilla branch untouched.

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:globals.glsl>

uniform sampler2D Sampler0;

// portrait.glsl samples Sampler0, so it must come after that declaration.
#moj_import <minecraft:portrait.glsl>

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in float portraitMask;
in float portraitZoom;

out vec4 fragColor;

void main() {
    if (portraitMask > 0.0) {
        vec2 uv = (texCoord0 - 0.5) * portraitZoom + 0.5;
        fragColor = portraitRender(uv, 68.0 / 70.0, GameTime);
        if (fragColor.a < 0.1) discard;
        fragColor.a = vertexColor.a;   // keep the fade as the title fades out
        return;
    }

    vec4 color = texture(Sampler0, texCoord0) * vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }
    fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
}
