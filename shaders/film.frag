// Carrete film shader: one pass for exposure, colour matrix, split toning,
// tone curve (LUT), halation, light leak, vignette and grain.
//
// The same program renders the live viewfinder (as an ImageFilter on the
// camera preview) and the full-resolution still (as a Paint shader), so the
// uniform layout below is a contract shared with lib/render/film_uniforms.dart.
// Also mirrored in packages/film_recipes/lib/src/uniforms.dart; change all three together.
//
// Coordinates that shape the look (grain, vignette, leak, halation radius)
// are expressed relative to the frame, never in pixels, so the preview and
// the saved photo look the same at any resolution.

#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// --- Uniform contract (float slots in declaration order) -------------------
uniform vec2 uSize;               // 0-1  set by the engine in filter mode
uniform float uMode;              // 2    1 = filter over a camera texture (flips on GLES), 0 = anything else
uniform float uSeed;              // 3    grain seed (animated in preview)
uniform float uExposure;          // 4    stops
uniform float uSaturation;        // 5    1 = unchanged
uniform vec3 uMatR;               // 6-8  colour matrix rows (linear-ish RGB)
uniform vec3 uMatG;               // 9-11
uniform vec3 uMatB;               // 12-14
uniform vec3 uShadowTint;         // 15-17 additive tint in the shadows
uniform vec3 uHighlightTint;      // 18-20 additive tint in the highlights
uniform float uGrainAmount;       // 21   0..1
uniform float uGrainSize;         // 22   grain cells across the short side / 1000
uniform float uVignette;          // 23   0..1
uniform float uVignetteSoft;      // 24   0..1
uniform float uHalation;          // 25   0..1
uniform float uHalationThreshold; // 26   0..1 luma
uniform float uHalationRadius;    // 27   fraction of the short side
uniform vec3 uHalationColor;      // 28-30
uniform vec4 uLeak;               // 31-34 x, y (frame uv), radius, amount
uniform vec3 uLeakColor;          // 35-37
uniform float uIntensity;         // 38   0..1 mix with the untreated image

// Zero frame size means the engine-provided uSize (live filter / whole still).
uniform vec2 uFrameSize;          // 39-40 whole photo, before the white border
uniform vec2 uTileOrigin;         // 41-42 tile origin in whole-photo pixels
uniform vec4 uInputRect;          // 43-46 normalized crop in the input texture

uniform sampler2D uInput;         // sampler 0: set by the engine in filter mode
uniform sampler2D uCurve;         // sampler 1: 256x1 RGB tone curve

out vec4 fragColor;

float hash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float luma(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec2 inputUv(vec2 uv) {
  // Clamp to the cropped photo's edge texel centres, not its neighbours
  // outside the crop. The full input remains available across tile edges.
  vec2 edge = uFrameSize.x > 0.0 ? vec2(0.5) / uFrameSize : vec2(0.0);
  return uInputRect.xy + clamp(uv, edge, vec2(1.0) - edge) * uInputRect.zw;
}

vec3 sampleInput(vec2 uv) {
  return texture(uInput, inputUv(uv)).rgb;
}

vec3 applyCurve(vec3 c) {
  // Sample texel centres of the 256-wide LUT.
  vec3 x = clamp(c, 0.0, 1.0) * (255.0 / 256.0) + (0.5 / 256.0);
  return vec3(
    texture(uCurve, vec2(x.r, 0.5)).r,
    texture(uCurve, vec2(x.g, 0.5)).g,
    texture(uCurve, vec2(x.b, 0.5)).b
  );
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 frameSize = uFrameSize.x > 0.0 ? uFrameSize : uSize;
  vec2 uv = (frag + uTileOrigin) / frameSize;
  vec2 sampleUv = uv;
#ifdef IMPELLER_TARGET_OPENGLES
  if (uMode > 0.5) {
    sampleUv.y = 1.0 - sampleUv.y;
  }
#endif

  vec4 src = texture(uInput, inputUv(sampleUv));
  vec3 original = src.rgb;

  float shortSide = min(frameSize.x, frameSize.y);
  // Frame coordinates with the short side = 1, centred.
  vec2 aspect = frameSize / shortSide;
  vec2 fc = (uv - 0.5) * aspect;

  // Exposure in approximately linear light.
  vec3 lin = pow(max(original, 0.0), vec3(2.2));
  lin *= exp2(uExposure);

  // Colour matrix.
  lin = vec3(dot(uMatR, lin), dot(uMatG, lin), dot(uMatB, lin));
  vec3 c = pow(max(lin, 0.0), vec3(1.0 / 2.2));

  // Saturation around luma.
  float l = luma(c);
  c = mix(vec3(l), c, uSaturation);

  // Split toning.
  float shadowW = 1.0 - smoothstep(0.0, 0.5, l);
  float highW = smoothstep(0.5, 1.0, l);
  c += uShadowTint * shadowW + uHighlightTint * highW;

  // Tone curve.
  c = applyCurve(c);

  // Halation: glow of the highlights bleeding into the red layer.
  if (uHalation > 0.001) {
    float r = uHalationRadius * shortSide;
    vec2 texel = vec2(r) / frameSize;
    float glow = 0.0;
    for (int i = 0; i < 8; i++) {
      float a = float(i) * 0.785398;
      vec2 dir = vec2(cos(a), sin(a));
      vec3 s1 = sampleInput(sampleUv + dir * texel);
      vec3 s2 = sampleInput(sampleUv + dir * texel * 0.5);
      glow += max(luma(s1) - uHalationThreshold, 0.0);
      glow += max(luma(s2) - uHalationThreshold, 0.0);
    }
    glow /= 16.0 * max(1.0 - uHalationThreshold, 0.001);
    c = 1.0 - (1.0 - c) * (1.0 - uHalationColor * glow * uHalation);
  }

  // Light leak: soft additive blob.
  if (uLeak.w > 0.001) {
    vec2 leakPos = (uLeak.xy - 0.5) * aspect;
    float d = length(fc - leakPos) / max(uLeak.z, 0.001);
    float leak = exp(-d * d * 2.0) * uLeak.w;
    c = 1.0 - (1.0 - c) * (1.0 - uLeakColor * leak);
  }

  // Vignette.
  if (uVignette > 0.001) {
    float d = length(fc) / length(aspect * 0.5);
    float v = smoothstep(1.0 - uVignetteSoft, 1.0 + uVignetteSoft * 0.2, d);
    c *= 1.0 - v * uVignette;
  }

  // Grain: two octaves of value noise, strongest in the midtones.
  if (uGrainAmount > 0.001) {
    float cells = 1000.0 / max(uGrainSize, 0.05);
    vec2 gp = (uv * aspect) * cells + vec2(uSeed * 17.0, uSeed * 31.0);
    float g = valueNoise(gp) + 0.5 * valueNoise(gp * 2.1 + 7.3);
    g = g / 1.5 - 0.5;
    float lc = luma(c);
    float mid = 1.0 - pow(abs(2.0 * lc - 1.0), 2.0);
    c += g * uGrainAmount * (0.35 + 0.65 * mid) * 0.35;
  }

  c = clamp(c, 0.0, 1.0);
  c = mix(original, c, uIntensity);
  fragColor = vec4(c, 1.0) * src.a;
}
