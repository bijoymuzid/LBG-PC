shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

// Impact frame (0.0 = off, 1.0 = full anime black/white or black/red impact frame)
uniform float impact_intensity : hint_range(0.0, 1.0) = 0.0;
// 0 = pure B&W inverted flash, 1 = crimson/black KJ 20-Series flash, 2 = cyan/white Weapon God flash
uniform int impact_style = 0;
uniform vec2 impact_center = vec2(0.5, 0.5);

// Radial speed-lines & chromatic aberration (dashes, wall-splats, ultimates)
uniform float speed_lines_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 speed_lines_color : source_color = vec3(0.95, 0.97, 1.0);
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.002;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.28;
uniform float contrast_boost : hint_range(0.8, 2.0) = 1.06;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float radial_burst(vec2 uv, vec2 center, float freq, float time_seed) {
	vec2 delta = uv - center;
	delta.x *= 1.7778; // 16:9 aspect correction
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);
	float ray_idx = floor((angle + PI) / (2.0 * PI) * freq);
	float n1 = hash12(vec2(ray_idx, floor(time_seed * 24.0)));
	float n2 = hash12(vec2(ray_idx * 1.7 + 13.0, floor(time_seed * 24.0)));
	float local_angle = fract((angle + PI) / (2.0 * PI) * freq);
	float spike = smoothstep(0.5, 0.0, abs(local_angle - 0.5));
	float mask = smoothstep(0.18 + n1 * 0.35, 0.65 + n2 * 0.3, dist);
	return spike * mask * step(0.32, n1);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir_from_center = uv - impact_center;
	float dist_center = length(dir_from_center);

	// Dynamic radial chromatic aberration (amplified during dashes, heavy impacts & speed lines)
	float total_ca = chromatic_aberration + impact_intensity * 0.018 + speed_lines_intensity * 0.009;
	vec2 ca_offset = dir_from_center * total_ca;

	float r = texture(screen_texture, clamp(uv + ca_offset, vec2(0.001), vec2(0.999))).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, clamp(uv - ca_offset, vec2(0.001), vec2(0.999))).b;
	vec3 col = vec3(r, g, b);

	// Subtle next-gen contrast grade
	col = clamp((col - 0.5) * contrast_boost + 0.5, 0.0, 2.0);

	// Radial anime speed lines on edges during dashes / ultimates / lock-on sprints
	if (speed_lines_intensity > 0.001) {
		float rays = radial_burst(uv, impact_center, 110.0, TIME);
		float fine_rays = radial_burst(uv, impact_center, 220.0, TIME * 1.5 + 4.1);
		float combined_rays = clamp(rays * 0.75 + fine_rays * 0.55, 0.0, 1.0);
		col = mix(col, speed_lines_color * 1.35, combined_rays * speed_lines_intensity * 0.75);
	}

	// Full Anime Impact Frame (High-contrast silhouette + radial energy streaks + inversion)
	if (impact_intensity > 0.001) {
		float luma = dot(col, vec3(0.299, 0.587, 0.114));
		float shock_rays = radial_burst(uv, impact_center, 96.0, TIME * 2.0);
		float ring = smoothstep(0.06, 0.0, abs(dist_center - (0.18 + (1.0 - impact_intensity) * 0.42)));

		// Threshold with radial jagged ink lines
		float threshold = 0.42 - shock_rays * 0.25 + ring * 0.35;
		float bw = step(threshold, luma);

		// Invert on peak frames for iconic anime frame-flash feel
		float invert_phase = step(0.55, impact_intensity);
		float inked = mix(bw, 1.0 - bw, invert_phase);

		vec3 impact_col = vec3(inked);
		if (impact_style == 1) {
			// Hyun's Dojo / KJ "20 Series" Crimson-Black-White Impact Frame
			impact_col = mix(vec3(0.03, 0.01, 0.02), vec3(1.0, 0.12, 0.18), inked);
			if (luma > 0.72 || ring > 0.5) {
				impact_col = vec3(1.0, 0.96, 0.96);
			}
		} else if (impact_style == 2) {
			// Combat Gods / Jun "Weapon God" Cyan-White Lightning Flash
			impact_col = mix(vec3(0.01, 0.03, 0.07), vec3(0.2, 0.88, 1.0), inked);
			if (luma > 0.68 || ring > 0.5) {
				impact_col = vec3(1.0);
			}
		}

		col = mix(col, impact_col, clamp(impact_intensity * 1.15, 0.0, 1.0));
	}

	// Cinematic edge vignette
	vec2 vig_uv = uv * (1.0 - uv.yx);
	float vig = pow(max(vig_uv.x * vig_uv.y * 15.0, 0.0), vignette_intensity);
	col *= mix(1.0, vig, 0.65);

	COLOR = vec4(col, 1.0);
}
