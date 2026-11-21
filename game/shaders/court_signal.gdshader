shader_type spatial;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(1.,.70,.28,1.);
uniform float direction = 1.;
uniform float progress = 1.;
uniform float strength = 0.;
uniform bool still = false;
varying float along;
void vertex() {
	along = clamp(.5 + direction * (MODEL_MATRIX[3].x / 11.), 0., 1.);
}
void fragment() {
	float wave = 1. - smoothstep(0., .32, abs(along - mix(-.15, 1.15, progress)));
	float glow = (still ? .45 : wave) * strength;
	ALBEDO = mix(vec3(.052,.080,.093), tint.rgb * 1.8, glow);
}
