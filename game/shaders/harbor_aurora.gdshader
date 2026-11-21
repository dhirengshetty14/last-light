shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform float clock = 0.;
uniform float intensity = 0.;
void fragment() {
	float x = UV.x;
	float fold = .55 + .15 * sin(x * 11. + clock * .19) + .09 * sin(x * 21. - clock * .14);
	float y = fold - UV.y;
	float curtain = exp(-max(y, 0.)*5.) * smoothstep(-.027, .027, y);
	float rays = .68 + .18*sin(x*126. + sin(x*29.)*2.) + .12*sin(x*230. - clock*.24);
	float edges = smoothstep(0., .15, x) * smoothstep(0., .15, 1.-x) * smoothstep(0., .20, UV.y);
	ALBEDO = mix(vec3(.25,.85,.72),vec3(.55,.54,1.),clamp(y*2.+.2*sin(x*13.),0.,1.));
	ALPHA = intensity * curtain * rays * edges;
}
