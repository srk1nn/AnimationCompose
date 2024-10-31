//
//  drawing.metal
//  AnimationCompose
//
//  Created by Sorokin Igor on 31.10.2024.
//

#include <metal_stdlib>
using namespace metal;

// Vertex shader
vertex float4 vertex_main(const device float2 *vertices [[buffer(0)]], uint id [[vertex_id]]) {
    return float4(vertices[id], 0.0, 1.0);
}

// Fragment shader
fragment float4 fragment_main() {
    return float4(1.0, 0.0, 0.0, 1.0); // Красный цвет линии
}
