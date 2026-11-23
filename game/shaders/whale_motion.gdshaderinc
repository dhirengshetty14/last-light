// Two local deformations on the animal. The rail, Saturn and girders stay anchored.
vec2 whale_uv(vec2 uv, vec2 eye, float seconds, float strength) {
    vec2 p = uv - eye;
    float head = (1.0 - smoothstep(0.76, 1.0, length(p / vec2(0.252, 0.238))))
        * smoothstep(0.012, 0.064, uv.y) * (1.0 - smoothstep(0.26, 0.36, uv.y));
    float breath = sin(seconds * 0.47) * 0.76 + sin(seconds * 0.23) * 0.24;
    vec2 offset = vec2(0.0036 * sin(seconds * 0.26), 0.0072 * breath) * head;
    vec2 iris = p + offset;
    float lids = 1.0 - smoothstep(0.22, 1.0, length(iris / vec2(0.048, 0.039)));
    float blink = 1.0 - smoothstep(0.08, 0.63, abs(mod(seconds + 7.0, 19.5) - 9.75));
    offset.y += iris.y * lids * blink * 2.8;
    offset.x += lids * 0.0025 * sin(seconds * 0.34);
    return uv + offset * strength;
}
