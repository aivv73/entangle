#version 450
layout(location=0) in vec3 position;
layout(location=1) in vec3 color;
layout(location=2) in vec2 uv;
layout(location=3) in vec3 normal;
layout(push_constant) uniform Drawing {
    mat4 mvp;
    vec4 normal_x_light_x;
    vec4 normal_y_light_y;
    vec4 normal_z_light_z;
    vec4 light_color_ambient;
} drawing;
layout(location=0) flat out vec3 vertex_color;
layout(location=1) out vec2 texture_uv;
layout(location=2) out vec3 world_normal;
void main() {
    gl_Position = drawing.mvp * vec4(position, 1.0);
    vertex_color = color;
    texture_uv = uv;
    world_normal = mat3(drawing.normal_x_light_x.xyz, drawing.normal_y_light_y.xyz, drawing.normal_z_light_z.xyz) * normal;
}
