// Masks are in coordinates of the painting, measured from its top left.
// Offsets are expressed in thousandths of the image size.
float area(vec2 p, vec2 centre, vec2 radii) {
    vec2 d = (p-centre)/radii;
    return 1.0-smoothstep(0.36,1.0,dot(d,d));
}
void main() {
    vec2 p = vec2(v_tex_coord.x, 1.0-v_tex_coord.y);
    float t = u_time;
    float breeze = sin(t*0.78+p.x*11.0) + 0.24*sin(t*1.33+p.y*7.0);
    float wave = sin(t*1.7-p.y*144.0+p.x*18.0);
    vec2 shift = vec2(0.0);
    float light = 0.0;
    if (u_theme < 0.5) { // Moonlit Woods: the stream and overhanging canopy
        float stream = area(p,vec2(0.57,0.67),vec2(0.16,0.13));
        shift = stream*vec2(0.8,2.4)*wave + area(p,vec2(0.37,0.11),vec2(0.31,0.16))*vec2(2.5,1.4)*breeze;
        light = stream*0.041*wave;
    } else if (u_theme < 1.5) { // Bay and swamp: moving shafts above rippled sand
        float water = area(p,vec2(0.50,0.29),vec2(0.46,0.51));
        shift = water*vec2(2.6,0.9)*sin(t*0.81+p.y*14.0);
        light = water*0.053*sin(p.x*37.0+p.y*7.0+t*0.71)
              + area(p,vec2(0.54,0.74),vec2(0.30,0.14))*0.040*wave;
    } else if (u_theme < 2.5) { // Volcano: heat haze and glowing lava channels
        float haze = area(p,vec2(0.68,0.40),vec2(0.31,0.49));
        shift = haze*vec2(2.6*sin(p.y*54.0+t*2.1),0.9*breeze);
        light = haze*0.067*sin(t*1.53+p.y*29.0);
    } else if (u_theme < 4.5) { // Cloud kingdom and candy coast: separate banks of cloud
        float mist = u_theme < 3.5 ? area(p,vec2(0.54,0.74),vec2(0.54,0.18))
                                  : area(p,vec2(0.46,0.28),vec2(0.31,0.24));
        shift = mist*vec2(6.5,1.25)*sin(t*0.24+p.y*3.0);
        light = mist*0.026*sin(t*0.43+p.x*8.0);
    } else if (u_theme < 5.5) { // Star cavern: drifting nebula light across the crystal field
        float nebula = area(p,vec2(0.58,0.17),vec2(0.19,0.14));
        shift = nebula*vec2(1.9,1.1)*breeze;
        light = nebula*0.057*sin(t*0.65+p.x*22.0)
              + area(p,vec2(0.24,0.72),vec2(0.18,0.15))*0.043*sin(t*1.17+p.x*43.0);
    } else if (u_theme < 7.5) { // Hollow river and meadow grasses
        float hollow = 1.0-step(6.5,u_theme);
        float grass = area(p,vec2(0.50,0.73),vec2(0.49,0.11));
        shift = grass*vec2(2.9,1.1)*breeze
              + hollow*area(p,vec2(0.57,0.60),vec2(0.18,0.08))*vec2(0.8,1.9)*wave;
        light = grass*0.031*sin(t*0.84+p.x*22.0);
    } else if (u_theme < 8.5) { // Lost Islands map: open sea
        shift = vec2(1.5,1.9)*wave;
        light = 0.033*wave;
    } else { // Prehistoric map: river bends and mist around the map's rim
        float river = area(p,vec2(0.84,0.49),vec2(0.07,0.18));
        float mist = area(p,vec2(0.12,0.16),vec2(0.13,0.18));
        shift = river*vec2(1.2,1.6)*wave + mist*vec2(3.7,0.9)*breeze;
        light = river*0.04*wave;
    }
    vec2 coord = clamp(p+0.001*shift*u_strength,0.0,1.0);
    vec4 paint = texture2D(u_texture,vec2(coord.x,1.0-coord.y));
    gl_FragColor = vec4(paint.rgb*(1.0+light*u_strength),paint.a) * v_color_mix.a;
}
