#version 450
layout(location=0) in vec3 position;
layout(location=1) in vec3 color;
layout(location=2) in vec2 uv;
layout(location=3) in vec3 normal;
layout(push_constant) uniform Drawing {
    mat4 mvp;
    vec4 rotation;
    vec4 inverse_scale;
    vec4 light_direction_ambient;
    vec4 light_color_intensity;
} drawing;
layout(location=0) flat out vec3 vertex_color;
layout(location=1) out vec2 texture_uv;
layout(location=2) out vec3 world_normal;
void main() {
    gl_Position = drawing.mvp * vec4(position, 1.0);
    vertex_color = color;
    texture_uv = uv;
    vec3 n = normal * drawing.inverse_scale.xyz;
    vec3 t = 2.0 * cross(drawing.rotation.xyz, n);
    world_normal = n + drawing.rotation.w * t + cross(drawing.rotation.xyz, t);
}
