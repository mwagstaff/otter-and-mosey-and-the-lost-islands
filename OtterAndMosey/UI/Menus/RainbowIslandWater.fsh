// Coordinates follow the original painting, measured on a 900 by 600 reference.
vec2 uv(vec2 p) {
    return vec2(p.x / 900.0, 1.0 - p.y / 600.0);
}

float oval(vec2 point, vec2 centre, vec2 radius) {
    vec2 d = (point - centre) / radius;
    return 1.0 - smoothstep(0.48, 1.0, dot(d, d));
}

// Left and right edges inside the main cascade, traced in painting coordinates.
vec2 cascadeBanks(float y) {
    vec2 banks = vec2(178.0, 185.0);
    banks += vec2(4.0, 34.0) * clamp((y - 193.0) / 10.0, 0.0, 1.0);
    banks += vec2(1.0, 4.0) * clamp((y - 203.0) / 23.0, 0.0, 1.0);
    banks += vec2(9.0, 4.0) * clamp((y - 226.0) / 12.0, 0.0, 1.0);
    banks += vec2(0.0, 5.0) * clamp((y - 238.0) / 34.0, 0.0, 1.0);
    banks += vec2(9.0, 1.0) * clamp((y - 272.0) / 6.0, 0.0, 1.0);
    banks += vec2(0.0, 1.0) * clamp((y - 278.0) / 10.0, 0.0, 1.0);
    banks += vec2(12.0, 2.0) * clamp((y - 288.0) / 12.0, 0.0, 1.0);
    banks += vec2(4.0, 4.0) * clamp((y - 300.0) / 30.0, 0.0, 1.0);
    banks += vec2(20.0, 9.0) * clamp((y - 330.0) / 12.0, 0.0, 1.0);
    return banks;
}

// Follow the same relative position across the stream as the sample moves vertically.
vec2 cascadeSample(float across, float y) {
    y = clamp(y, 193.0, 342.0);
    vec2 banks = cascadeBanks(y);
    return uv(vec2(mix(banks.x, banks.y, across), y));
}

void main() {
    vec2 p = vec2(v_tex_coord.x * 900.0, (1.0 - v_tex_coord.y) * 600.0);
    float t = u_time;
    vec4 color = texture2D(u_texture, v_tex_coord);

    if (p.x < 345.0 && p.x > 153.0 && p.y > 177.0 && p.y < 355.0) {
        vec2 banks = cascadeBanks(p.y);
        float falls = smoothstep(0.0, 3.0, min(p.x - banks.x, banks.y - p.x))
                    * smoothstep(193.0, 202.0, p.y) * (1.0 - smoothstep(328.0, 342.0, p.y));
        float small = oval(p, vec2(321.0, 309.0), vec2(8.8, 40.0));
        // Two moving samples crossfade, so each streak resets while invisible.
        float flow = p.x < 275.0 ? t * 0.82 + p.x * 0.016 : t * 0.68;
        vec2 travel = p.x < 275.0 ? vec2(4.4, 25.0) : vec2(0.9, 18.0);
        float a = fract(flow);
        float b = fract(flow + 0.5);
        vec2 sampleA = uv(p - travel * (a - 0.5));
        vec2 sampleB = uv(p - travel * (b - 0.5));
        if (falls > 0.0) {
            float across = (p.x - banks.x) / (banks.y - banks.x);
            sampleA = cascadeSample(across, p.y - travel.y * (a - 0.5));
            sampleB = cascadeSample(across, p.y - travel.y * (b - 0.5));
        }
        vec4 streak = mix(texture2D(u_texture, sampleA), texture2D(u_texture, sampleB), abs(2.0 * a - 1.0));
        // Uneven ribbons of light travel with the painted water.
        float downstream = (p.y - flow * travel.y) * 0.28 + sin(p.x * 0.43);
        streak.rgb *= 1.0 + 0.045 * sin(downstream);
        color = mix(color, streak, max(falls, small));

        float foam = max(oval(p, vec2(255.0, 338.5), vec2(21.0, 8.0)),
                         oval(p, vec2(316.0, 341.0), vec2(17.0, 7.0)));
        // Rolls of foam spread out from each impact, lifting and settling at the edges.
        float impactX = p.x < 290.0 ? 231.0 : 321.0;
        float roll = abs(p.x - impactX) * 0.23 - t * 2.7 + sin(p.y * 0.24);
        vec2 churn = vec2(2.6 * sin(roll) * clamp((p.x - impactX) / 5.0, -1.0, 1.0), 2.1 * cos(roll));
        vec4 froth = texture2D(u_texture, uv(p + churn));
        froth.rgb = mix(froth.rgb, vec3(1.0), 0.13 * (0.5 + 0.5 * cos(roll)));
        color = mix(color, froth, foam);
    }

    if (p.y > 345.0) {
        float lagoon = oval(p, vec2(451.0, 453.0), vec2(282.0, 112.0));
        float shore = oval(p, vec2(461.0, 542.0), vec2(236.0, 31.0));
        float lap = sin(t * 1.07 - p.y * 0.09 + p.x * 0.009);
        color = mix(color, texture2D(u_texture, uv(p + vec2(0.9 * lap, 2.15 * lap + 0.45 * sin(t * 1.52 - p.y * 0.19 - p.x * 0.013)))), max(lagoon, shore));
        // Light catches the approaching crests at slightly different points along each wave.
        float crest = smoothstep(0.50, 1.0, lap) * (0.65 + 0.35 * sin(p.x * 0.07 - t * 0.62));
        color.rgb = mix(color.rgb, vec3(0.88, 0.98, 0.96), lagoon * crest * 0.065);
        float sun = oval(p, vec2(596.0, 420.0), vec2(19.0, 67.0));
        float glint = max(0.0, sin(p.y * 1.1 - t * 1.5 + sin(p.x * 0.2)));
        color.rgb += vec3(0.040, 0.033, 0.019) * sun * glint * glint;
    }

    float fronds = max(oval(p, vec2(195.0, 52.0), vec2(73.0, 58.0)),
                       oval(p, vec2(831.0, 150.0), vec2(42.0, 66.0)));
    // The near palm on the left stays visible in the wide landscape phone crop.
    fronds = max(fronds, oval(p, vec2(49.0, 302.0), vec2(49.0, 72.0)));
    if (fronds > 0.0) {
        float breeze = sin(t * 0.86 + p.x * 0.014) + 0.24 * sin(t * 1.37 + p.y * 0.03);
        color = mix(color, texture2D(u_texture, uv(p + vec2(3.55, 1.65) * breeze)), fronds);
    }

    // Gently advect the existing cloud banks within clear patches of sky.
    if (p.y < 205.0) {
        float clouds = max(oval(p, vec2(411.0, 107.0), vec2(48.0, 43.0)),
                           oval(p, vec2(732.0, 131.0), vec2(65.0, 63.0)));
        if (clouds > 0.0) {
            float drift = fract(t * 0.065);
            vec2 wind = vec2(25.0, -3.5);
            vec4 cloud = mix(texture2D(u_texture, uv(p - wind * (drift - 0.5))),
                             texture2D(u_texture, uv(p - wind * (fract(drift + 0.5) - 0.5))),
                             abs(2.0 * drift - 1.0));
            color = mix(color, cloud, clouds);
        }
    }

    // Project a rotating six-sided crystal in the painting's coordinate system.
    // Rows share the same projected corners from the tip down to the pedestal.
    if (p.x > 553.0 && p.x < 625.0 && p.y >= 55.0 && p.y < 153.0) {
        float y = p.y - 55.0;
        float radius = y < 40.0 ? 26.0 * y / 40.0 :
                       (y < 77.0 ? mix(26.0, 22.0, (y - 40.0) / 37.0) :
                                   mix(22.0, 11.0, (y - 77.0) / 21.0));
        float x = p.x - 589.5;
        // Reconstruct the sliver of backlit sky exposed when the silhouette narrows.
        float oldEdge = 1.0 - smoothstep(radius, radius + 1.2, abs(x));
        vec4 sky = mix(texture2D(u_texture, uv(vec2(589.5 - radius - 3.0, p.y))),
                       texture2D(u_texture, uv(vec2(589.5 + radius + 3.0, p.y))),
                       smoothstep(-radius - 0.1, radius + 0.1, x));
        color = mix(color, sky, oldEdge);
        float turn = mod(t * 0.21, 6.2831853);
        for (int i = 0; i < 6; i++) {
            float angle = turn + float(i) * 1.04719755;
            float face = angle + 0.52359878;
            float left = radius * sin(angle);
            float right = radius * sin(angle + 1.04719755);
            if (cos(face) > 0.0 && x >= left && x < right) {
                float u = (x - left) / max(0.015, right - left);
                float band = y < 40.0 ? y / 40.0 :
                             (y < 77.0 ? (y - 40.0) / 37.0 : (y - 77.0) / 21.0);
                // Each triangular cut bends the view into a different part of the
                // original painted spectrum. Preserve its pigment and surface texture.
                float cut = smoothstep(-0.035, 0.035, u - band);
                float bend = sin(face) * 0.50 + (u - 0.5) * 0.48 + (cut - 0.5) * 0.19;
                float sourceY = clamp(p.y + 4.0 * sin(face) + 2.0 * (cut - 0.5), 57.0, 151.0);
                float sourceWidth = min((sourceY - 55.0) * 0.54, min(20.0, 10.0 + (152.0 - sourceY) * 0.4));
                vec4 glass = texture2D(u_texture, uv(vec2(589.5 + bend * sourceWidth, sourceY)));
                float light = cos(face - 0.85 + (cut - 0.5) * 0.20);
                glass.rgb *= 0.83 + 0.17 * light;
                float shine = pow(max(0.0, light), 44.0);
                glass.rgb = mix(glass.rgb, vec3(1.0, 0.97, 0.84), 0.37 * shine);
                float seam = 1.0 - smoothstep(0.0, 0.65, min(x - left, right - x));
                color = mix(glass, vec4(1.0, 0.96, 0.92, 1.0), seam * 0.23);
                break;
            }
        }
    }

    // Align each flare with its source. The crystal flare peaks as a facet
    // reflects the sun toward the viewer, once per sixth of a revolution.
    if (p.x > 500.0 && p.x < 652.0 && p.y > 69.0 && p.y < 225.0) {
        float turn = t * 0.21;
        float alignment = cos(6.0 * (turn + 0.52359878 - 0.85));
        float gleam = pow(max(0.0, 0.5 + 0.5 * alignment), 5.0);
        vec2 d = p - vec2(604.0 + 2.4 * sin(6.0 * turn), 118.0 + 2.0 * sin(6.0 * turn));
        vec2 ray = vec2(dot(d, vec2(0.88, 0.475)), dot(d, vec2(-0.475, 0.88)));
        float streak = exp(-abs(ray.x) / 11.0 - abs(ray.y) / 1.35);
        float halo = exp(-dot(d, d) / 118.0);
        color.rgb = mix(color.rgb, vec3(1.0, 0.985, 0.89), gleam * (0.63 * streak + 0.21 * halo));
        color.rgb += gleam * vec3(0.033, 0.056, 0.060) * oval(d, vec2(-43.0, 51.0), vec2(7.5));
    }
    if (p.x > 570.0 && p.x < 870.0 && p.y > 169.0 && p.y < 302.0) {
        vec2 d = p - vec2(791.0, 221.0);
        float sunlight = 0.82 + 0.18 * sin(t * 0.34);
        float bloom = exp(-dot(d, d) / 540.0);
        float ray = exp(-abs(d.x + 0.18 * d.y) / 19.0 - abs(d.y - 0.18 * d.x) / 1.6);
        color.rgb = mix(color.rgb, vec3(1.0, 0.91, 0.67), sunlight * (0.14 * bloom + 0.20 * ray));
        float ghosts = oval(d, vec2(-97.0, 22.0), vec2(9.0)) +
                       0.65 * oval(d, vec2(-177.0, 40.0), vec2(14.0));
        color.rgb += sunlight * vec3(0.047, 0.034, 0.019) * ghosts;
    }

    float grey = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    gl_FragColor = vec4(mix(vec3(grey), color.rgb, u_saturation), 1.0);
}
