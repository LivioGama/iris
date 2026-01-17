//
//  Shaders.metal
//  IRIS
//
//  Metal shaders for high-performance gaze indicator rendering
//

#include <metal_stdlib>
using namespace metal;

// Vertex structure for gaze indicator circles
struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 localPos;       // Position in local circle space (-1 to 1)
    float radius;
    float4 color;
    uint instanceID [[flat]];
};

struct Uniforms {
    float2 gazePoint;      // Gaze position in screen coordinates
    float2 screenSize;     // Screen dimensions
    float pixelScale;      // For retina displays
};

// Vertex shader - transforms circle vertices to screen space
vertex VertexOut vertex_main(
    VertexIn in [[stage_in]],
    constant Uniforms &uniforms [[buffer(1)]],
    uint instanceID [[instance_id]]
) {
    VertexOut out;

    // Circle parameters based on instance ID
    float radius;
    float4 color;

    switch (instanceID) {
        case 0: // Outer ring (50px radius)
            radius = 50.0;
            color = float4(0.0, 1.0, 1.0, 0.5);
            break;
        case 1: // Middle ring (30px radius)
            radius = 30.0;
            color = float4(0.0, 1.0, 1.0, 1.0);
            break;
        case 2: // Middle fill (30px radius)
            radius = 30.0;
            color = float4(0.0, 1.0, 1.0, 0.2);
            break;
        case 3: // Center dot (5px radius)
        default:
            radius = 5.0;
            color = float4(0.0, 1.0, 1.0, 1.0);
            break;
    }

    // Store local position for fragment shader (-1 to 1 range)
    out.localPos = in.position;

    // Convert to pixel space
    float2 pixelPos = in.position * radius;

    // Add gaze point offset
    float2 screenPos = pixelPos + uniforms.gazePoint;

    // Convert to normalized device coordinates
    float2 ndc = (screenPos / uniforms.screenSize) * 2.0 - 1.0;
    ndc.y = -ndc.y; // Flip Y for Metal

    out.position = float4(ndc, 0.0, 1.0);
    out.radius = radius;
    out.color = color;
    out.instanceID = instanceID;

    return out;
}

// Fragment shader - renders anti-aliased circles
fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    // Distance from center in local coordinates
    float dist = length(in.localPos);

    // Determine rendering mode
    bool isFilled = (in.instanceID == 2 || in.instanceID == 3);

    if (isFilled) {
        // Filled circle with anti-aliasing
        float edge = fwidth(dist);
        float alpha = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, dist);
        return float4(in.color.rgb, in.color.a * alpha);
    } else {
        // Ring (stroke)
        float strokeWidth = (in.instanceID == 0) ? 0.04 : 0.10; // Proportional to radius
        float edge = fwidth(dist);

        // Outer edge
        float outerAlpha = 1.0 - smoothstep(1.0 - edge, 1.0 + edge, dist);

        // Inner edge
        float innerRadius = 1.0 - strokeWidth;
        float innerAlpha = smoothstep(innerRadius - edge, innerRadius + edge, dist);

        float alpha = outerAlpha * innerAlpha;
        return float4(in.color.rgb, in.color.a * alpha);
    }
}
