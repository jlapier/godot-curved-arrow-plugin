shader_type canvas_item;

uniform vec3 line_color: source_color = vec3(1.0);
uniform float alpha: hint_range(0, 1) = 1.0;
uniform int line_thickness: hint_range(0, 10) = 1;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

void fragment() {
    vec2 size = SCREEN_PIXEL_SIZE * float(line_thickness);
    float line_alpha = 0.0;
    for (float i = -size.x; i <= size.x; i += SCREEN_PIXEL_SIZE.x) {
        for (float j = -size.y; j <= size.y; j += SCREEN_PIXEL_SIZE.y) {
            line_alpha += texture(screen_texture, SCREEN_UV + vec2(i, j)).a;
        }
    }
    vec4 color = texture(screen_texture, SCREEN_UV);
    vec4 outline = vec4(line_color, min(line_alpha, 1.0) * alpha);
    COLOR = mix(outline, color, color.a);
    COLOR.a *= alpha;
}