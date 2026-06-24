shader_type canvas_item;
render_mode blend_mix;

uniform float blend : hint_range(0.0, 2.0) = 0.0;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D day_palette : source_color, filter_linear;
uniform sampler2D sunset_palette : source_color, filter_linear;
uniform sampler2D night_palette : source_color, filter_linear;

void fragment() {
	vec4 source_color = texture(screen_texture, SCREEN_UV);
	float luminance = dot(source_color.rgb, vec3(0.299, 0.587, 0.114));
	vec2 palette_uv = vec2(clamp(luminance, 0.0, 1.0), UV.y);

	vec3 day_color = mix(source_color.rgb, texture(day_palette, palette_uv).rgb, 0.0);
	vec3 sunset_color = mix(source_color.rgb, texture(sunset_palette, palette_uv).rgb, 0.55);
	vec3 night_color = mix(source_color.rgb, texture(night_palette, palette_uv).rgb, 0.75);

	float day_to_sunset = smoothstep(0.0, 1.0, clamp(blend, 0.0, 1.0));
	float sunset_to_night = smoothstep(0.0, 1.0, clamp(blend - 1.0, 0.0, 1.0));
	vec3 graded = mix(day_color, sunset_color, day_to_sunset);
	graded = mix(graded, night_color, sunset_to_night);

	COLOR = vec4(graded, source_color.a);
}
