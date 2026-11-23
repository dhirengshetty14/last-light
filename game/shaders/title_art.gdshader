shader_type canvas_item;
#include "res://game/shaders/whale_motion.gdshaderinc"
uniform float seconds = 0.0;
uniform float strength = 1.0;
void fragment() {
    COLOR = texture(TEXTURE, whale_uv(UV, vec2(0.238, 0.110), seconds, strength));
}
