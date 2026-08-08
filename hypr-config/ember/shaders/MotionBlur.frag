#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform qt_buf {
    vec2  uVelocity;
    float uStrength;
    int   uSamples;
};

float gaussian(float x, float sigma) {
    return exp(-(x * x) / (2.0 * sigma * sigma));
}

void main() {
    int taps = clamp(uSamples, 1, 31);

    vec2  blurDir = uVelocity * uStrength;
    float halfN   = float(taps - 1) * 0.5;
    float sigma   = halfN * 0.5 + 0.001;

    vec4  colour  = vec4(0.0);
    float totalW  = 0.0;

    for (int i = 0; i < taps; i++) {
        float t  = (float(i) - halfN) / max(halfN, 0.001);
        float w  = gaussian(t, 0.5);
        vec2  uv = qt_TexCoord0 - blurDir * t;
        colour  += texture(source, clamp(uv, 0.0, 1.0)) * w;
        totalW  += w;
    }

    fragColor = colour / totalW;
}
