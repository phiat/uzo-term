#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform float time;
uniform vec2 resolution;

out vec4 finalColor;

void main() {
    // ── Scan bar geometry (computed first so we can distort UVs) ──
    float scanBar = fract(time * 0.14);          // rolls down every ~7s
    float barDist = abs(fragTexCoord.y - scanBar);
    barDist = min(barDist, 1.0 - barDist);       // wrap-around
    float bar = smoothstep(0.055, 0.0, barDist); // wider influence zone

    // Pre-sample brightness at the undistorted position to gauge text density
    float preBright = dot(texture(texture0, fragTexCoord).rgb, vec3(0.299, 0.587, 0.114));

    // ── Refraction: bend UVs near the bar, stronger on text ──
    vec2 uv = fragTexCoord;
    float refractStrength = bar * (0.002 + preBright * 0.006);
    uv.y += refractStrength * sin(fragTexCoord.x * 45.0 + time * 3.5);
    uv.x += refractStrength * 0.4 * cos(fragTexCoord.y * 30.0 + time * 2.2);

    // ── Chromatic aberration at bar edges, scaled by text brightness ──
    vec4 color;
    if (bar > 0.01) {
        float aberr = bar * (0.0008 + preBright * 0.0025);
        color.r = texture(texture0, uv + vec2( aberr, 0.0)).r;
        color.g = texture(texture0, uv).g;
        color.b = texture(texture0, uv + vec2(-aberr, 0.0)).b;
        color.a = 1.0;
    } else {
        color = texture(texture0, uv);
    }

    float brightness = dot(color.rgb, vec3(0.299, 0.587, 0.114));

    // ── Reflection ghost trailing behind the bar ──
    // Mirror a strip of content across the bar — text appears to bounce off it
    // Bar always moves downward (fract monotonically increases), so trail is above
    float reflDist = fragTexCoord.y - scanBar;
    if (reflDist < 0.0 && reflDist > -0.07) {
        // Sample from the mirrored side below the bar
        vec2 mirrorUV = vec2(fragTexCoord.x, scanBar - reflDist);
        mirrorUV.y = clamp(mirrorUV.y, 0.0, 1.0);
        vec3 mirrorCol = texture(texture0, mirrorUV).rgb;
        float mirrorBright = dot(mirrorCol, vec3(0.299, 0.587, 0.114));
        float fade = 1.0 + reflDist / 0.07;  // 1 at bar → 0 at edge
        color.rgb += mirrorCol * mirrorBright * fade * fade * 0.18;
    }

    // ── Bar glow: glints off text ──
    float barGlow = bar * (0.025 + brightness * 0.12);
    color.rgb += barGlow;

    // ── Static CRT scanlines ──
    float pixelY = fragTexCoord.y * resolution.y;
    float scanline = sin(pixelY * 3.14159) * 0.5 + 0.5;
    scanline = pow(scanline, 1.4);

    float lineReflect = brightness * scanline * 0.16;
    float lineAbsorb  = (1.0 - brightness) * (1.0 - scanline) * 0.05;
    color.rgb += lineReflect;
    color.rgb -= lineAbsorb;

    // ── Gentle travelling shimmer ──
    float wave = sin(fragTexCoord.y * 50.0 + fragTexCoord.x * 10.0 + time * 1.8) * 0.5 + 0.5;
    wave = smoothstep(0.3, 0.7, wave);
    color.rgb += wave * 0.022;

    // ── Faint vignette ──
    vec2 vigUV = fragTexCoord - 0.5;
    float vignette = 1.0 - dot(vigUV, vigUV) * 0.5;
    color.rgb *= vignette;

    finalColor = color;
}
