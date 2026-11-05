#version 450
layout(set=0,binding=0) uniform sampler2D albedo;
layout(push_constant) uniform Drawing {
    mat4 mvp;
    vec4 rotation;
    vec4 inverse_scale;
    vec4 light_direction_ambient;
    vec4 light_color_intensity;
} drawing;
layout(location=0) flat in vec3 vertex_color;
layout(location=1) in vec2 texture_uv;
layout(location=2) in vec3 world_normal;
layout(location=0) out vec4 output_color;
void main() {
    float normal_squared = dot(world_normal, world_normal);
    vec3 normal = world_normal * inversesqrt(normal_squared > 0.0 ? normal_squared : 1.0);
    float diffuse = max(dot(normal, normalize(drawing.light_direction_ambient.xyz)), 0.0);
    vec3 light = vec3(drawing.light_direction_ambient.w) + drawing.light_color_intensity.rgb * (drawing.light_color_intensity.w * diffuse);
    output_color = vec4(texture(albedo, texture_uv).rgb * vertex_color * light, 1.0);
}
