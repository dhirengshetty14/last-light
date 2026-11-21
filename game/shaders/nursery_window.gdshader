shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;
#include "res://game/shaders/whale_motion.gdshaderinc"
uniform sampler2D plate : source_color, repeat_disable, filter_linear_mipmap;
uniform float seconds = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec2 eye_position=vec2(0.248, 0.102);
uniform float ring_ice=0.0;
void fragment() {
    vec2 uv = whale_uv(UV, eye_position, seconds, strength);
    float sky = 1.0 - smoothstep(0.0, 0.065, uv.y - (0.55 - 0.37 * uv.x));
    float plume = (1.0 - smoothstep(0.03, 0.135, abs(uv.x - 0.71 + 0.14 * uv.y)))
        * smoothstep(0.018, 0.10, uv.y) * sky * ring_ice * strength;
    uv.x += plume * 0.0035 * sin(uv.y * 24.0 + seconds * 0.60);
    uv.y += plume * 0.0040 * sin(uv.y * 36.0 + seconds * 0.71);
    ALBEDO = texture(plate, uv).rgb;
}
