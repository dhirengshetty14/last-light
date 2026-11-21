shader_type spatial;
render_mode cull_disabled;
varying vec3 skin;
float grain(vec3 p) {
    vec3 i = floor(p), w = fract(p);
    w = w * w * (3.0 - 2.0 * w);
    vec4 n = dot(i, vec3(1.0, 67.0, 139.0)) + vec4(0.0, 67.0, 139.0, 206.0);
    vec4 a = fract(sin(n) * 43758.53), b = fract(sin(n + 1.0) * 43758.53);
    vec4 c = mix(a, b, w.x);
    return mix(mix(c.x, c.y, w.y), mix(c.z, c.w, w.y), w.z);
}
void vertex() { skin = VERTEX; }
void fragment() {
    float pores = grain(skin * 89.0);
    float marbling = grain(skin * 25.0 + pores * 0.32);
    float spots = smoothstep(0.68, 0.84, marbling + 0.16 * pores);
    vec3 dorsal = mix(vec3(0.055, 0.122, 0.155), vec3(0.35, 0.40, 0.40), spots);
    float stomach = 1.0 - smoothstep(-0.064, -0.003, skin.y + 0.014 * marbling);
    float pleat = smoothstep(0.72, 0.99, cos(skin.z * 214.0 + skin.x * 19.0));
    ALBEDO = mix(dorsal, vec3(0.42, 0.43, 0.39) * (1.0 - pleat * 0.15), stomach);
    ROUGHNESS = 0.44 + 0.24 * pores;
    METALLIC = 0.04;
}
