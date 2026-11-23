#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Coordinates are normalized to the painted panel. Each range has a solid center
// so the actor or prop moves together, and a feathered edge around its silhouette.
static float panelRegion(float2 uv, float2 lower, float2 upper, float2 feather) {
    float2 enters = smoothstep(lower - feather, lower, uv);
    float2 leaves = 1.0f - smoothstep(upper, upper + feather, uv);
    return enters.x * enters.y * leaves.x * leaves.y;
}

static float2 turnOffset(float2 uv, float2 pivot, float radians) {
    const float2 aspect = float2(3.0f, 1.0f);
    float2 point = (uv - pivot) * aspect;
    float c = cos(radians);
    float s = sin(radians);
    float2 rotated = float2(c * point.x + s * point.y, -s * point.x + c * point.y);
    return (point - rotated) / aspect;
}

[[ stitchable ]] half4 cafeBranchMotion(float2 position, SwiftUI::Layer layer,
                                       float4 bounds, float variant, float time) {
    float2 uv = (position - bounds.xy) / bounds.zw;
    float reach = 1.0f - smoothstep(0.08f, 0.82f, time);
    float turn = 1.0f - smoothstep(0.00f, 0.44f, time);
    float respond = smoothstep(0.29f, 0.63f, time) * (1.0f - smoothstep(0.63f, 1.0f, time));

    float clerk = panelRegion(uv, float2(0.68f, 0.0f), float2(0.82f, 0.31f), float2(0.065f, 0.19f));
    float guest = panelRegion(uv, float2(0.21f, 0.07f), float2(0.33f, 0.44f), float2(0.068f, 0.19f));
    float2 shift = (float2(0.014f, -0.020f) + turnOffset(uv, float2(0.75f, 0.35f), 0.09f)) * clerk * turn;

    // Hold the prop and the nearby fingers together while the reach straightens.
    if (variant < 0.5f) {
        float handoff = panelRegion(uv, float2(0.37f, 0.58f), float2(0.55f, 0.93f), float2(0.14f, 0.14f));
        shift += float2(0.044f, -0.065f) * handoff * reach;
        shift += float2(0.016f, 0.046f) * guest * respond;
    } else if (variant < 1.5f) {
        float lift = panelRegion(uv, float2(0.44f, 0.61f), float2(0.57f, 0.77f), float2(0.105f, 0.23f));
        shift += float2(0.025f, -0.105f) * lift * reach;
        shift += float2(-0.019f, -0.048f) * guest * respond;
    } else {
        float receipt = panelRegion(uv, float2(0.36f, 0.57f), float2(0.53f, 0.77f), float2(0.14f, 0.15f));
        shift += float2(0.055f, 0.025f) * receipt * reach;
        shift += float2(-0.013f, 0.035f) * guest * respond;
    }

    float2 edge = min(float2(0.5f), 0.5f / bounds.zw);
    return layer.sample(bounds.xy + clamp(uv - shift, edge, 1.0f - edge) * bounds.zw);
}
