shader_type spatial;
render_mode specular_disabled;

uniform int steps : hint_range(1, 8) = 3;
uniform vec3 base_color : source_color = vec3(1.0);

// Textura de albedo (sin hint en Godot 3)
uniform sampler2D albedo_texture;

void fragment() {
    // UV viene del mesh automáticamente
    vec3 tex_color = texture(albedo_texture, UV).rgb;

    // Mezclamos textura con color base
    vec3 final_color = tex_color * base_color;

    ALBEDO = final_color;
}

void light() {
    float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
    float stepped = floor(NdotL * float(steps)) / float(steps);

    DIFFUSE_LIGHT += stepped * ATTENUATION * LIGHT_COLOR * ALBEDO;
}
