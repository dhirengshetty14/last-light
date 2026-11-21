shader_type spatial;
uniform sampler2D steel_color : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D steel_normal : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D arm : repeat_enable, filter_linear_mipmap;
varying vec2 deck;
void vertex() {
    deck = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
    vec2 uv = deck * 0.52;
    vec3 scan = texture(steel_color, uv).rgb;
    vec3 props = texture(arm, uv).rgb;
    float steel = dot(scan, vec3(0.299, 0.587, 0.114));
    float wear = smoothstep(0.025, 0.32, steel);
    vec2 plate = abs(fract((deck + vec2(0.515, 0.448)) / vec2(1.25, 1.15)) - 0.5);
    float lip = smoothstep(0.484, 0.497, max(plate.x, plate.y));
    ALBEDO = mix(scan * vec3(0.96, 1.04, 1.09), vec3(0.12, 0.14, 0.15) + 0.23 * scan, 0.28);
    ALBEDO = mix(ALBEDO, vec3(0.048, 0.056, 0.061), lip * 0.78);
    METALLIC = 0.22 + 0.36 * props.b;
    ROUGHNESS = clamp(props.g * 0.81 + 0.11 - 0.14 * wear, 0.21, 0.91);
    AO = mix(0.70, 1.0, props.r);
    NORMAL_MAP = texture(steel_normal, uv).rgb;
    NORMAL_MAP_DEPTH = 0.65;
}
