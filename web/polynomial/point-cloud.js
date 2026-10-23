// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision ca809d2 by Alok Singh with OpenAI Codex, 2026-10-23.
// One GL_POINTS draw for the whole lattice. Positions are exact integers in display units (the object is
// scaled to world size). The shader consumes Lean's accepted discriminant and applies the same size model as
// appearance.js: perspective radius × source factor, her origin-eye rule, minimum footprint with
// (px/min)² alpha, cube-root growth above the knee, cap and overview fog.
import * as THREE from '../vendor/three.module.js';
import { glyphRadius, sizePixels, decode, categoryPalettes, paletteSample, palettePosition, orbitFactorFromData } from './appearance.js';
import {catalogueUniform,catalogueFadeGLSL} from './catalogue-display.js';

const vertexShader = `
attribute float aFactor;
attribute float aDelta;
attribute float aKind;
attribute vec3 color;
uniform float uGlyph, uHalfH, uDpr, uOrigin;
uniform vec3 uFog, uSize, uKeep, uCatalogue;
uniform vec4 uFocus;
uniform vec2 uFocusFade;
varying vec3 vColor;
varying float vPx, vSize, vFaint, vAlpha;
${catalogueFadeGLSL}
void main() {
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  gl_Position = projectionMatrix * mv;
  float depth = -mv.z;
  float f = aFactor;
  float delta = aDelta;
  if (uOrigin > 0.5) f = delta < 0.0 ? 0.4 * pow(-delta, 0.25) / sqrt(abs(position.y)) : 1.0;
  float px = depth > 0.0 ? uGlyph * f * projectionMatrix[1][1] * uHalfH / depth : 0.0;
  float dim = 1.0;
  vFaint = 0.0;
  if (px < uSize.x) { float r = px / uSize.x; dim = r * r; px = uSize.x; vFaint = 1.0; }
  else if (px > uSize.y) px = uSize.y * pow(px / uSize.y, 1.0 / 3.0);
  px = min(px, uSize.z);
  dim *= 1.0 - uFog.z * smoothstep(uFog.x, uFog.y, depth);
  float catalogueAlpha=catalogueOpacity(position,aKind,uCatalogue);
  dim*=catalogueAlpha;
  if(catalogueAlpha<.999)vFaint=1.0;
  // Optional plane focus (a viewing aid): uFocus.xyz is the unit display normal, w enables it. Opacity falls
  // with Euclidean display distance to the plane over uFocusFade.x, to the floor uFocusFade.y; members stay 1.
  if (uFocus.w > 0.5 && position != uKeep) {
    float fade = mix(1.0, uFocusFade.y, smoothstep(0.0, uFocusFade.x, abs(dot(uFocus.xyz, position))));
    dim *= fade;
    if (fade < 0.999) vFaint = 1.0;
  }
  vColor = color;
  vAlpha = dim;
  vPx = px * uDpr;
  vSize = 2.0 * vPx + 2.0;
  gl_PointSize = vSize;
}`;
// Dimmed sub-minimum dots and focus-faded context write far-plane depth: they still hide behind nearer
// full-size dots but never occlude them, and accumulate like her depth-test-free transparent sprites.
const fragmentShader = `
varying vec3 vColor;
varying float vPx, vSize, vFaint, vAlpha;
void main() {
  float r = length(gl_PointCoord - vec2(0.5)) * vSize;
  float coverage = clamp(vPx - r + 0.5, 0.0, 1.0);
  if (coverage <= 0.0 || vAlpha <= 0.0) discard;
  gl_FragColor = vec4(vColor, vAlpha * coverage);
  gl_FragDepth = vFaint > 0.5 ? 1.0 : gl_FragCoord.z;
}`;

export function pointCloudMaterial() {
  return new THREE.ShaderMaterial({
    uniforms: {
      uGlyph: { value: glyphRadius }, uHalfH: { value: 300 }, uDpr: { value: 1 }, uOrigin: { value: 0 }, uKeep: { value: new THREE.Vector3(1e9, 0, 0) },
      uFocus: { value: new THREE.Vector4(0, 1, 0, 0) }, uFocusFade: { value: new THREE.Vector2(1, 0.12) },
      uFog: { value: new THREE.Vector3(0, 1, 0) }, uSize: { value: new THREE.Vector3(sizePixels.min, sizePixels.knee, sizePixels.cap) },
      uCatalogue: { value: new THREE.Vector3(1,1,0) },
    },
    vertexShader, fragmentShader, transparent: true,
  });
}

// Colors are sRGB bytes written straight to the sRGB framebuffer; interior colors depend only on |Δ|.
export function fillColors(lattice, symmetric, categories, out = new Uint8Array(3 * lattice.count)) {
  const cache = new Map();
  for (let i = 0; i < lattice.count; i++) {
    const type=lattice.kind[i],delta=lattice.delta[i];
    const key = type===2||(type===3&&symmetric) ? delta : type===0 ? 'null' : type===1 ? 'exterior' : 'lower';
    let rgb = cache.get(key);
    if (!rgb) { rgb = (typeof key==='number'?paletteSample(palettePosition(-delta),categories):decode(categoryPalettes[categories][key])).map(x=>Math.round(x*255)); cache.set(key,rgb); }
    out[3 * i] = rgb[0]; out[3 * i + 1] = rgb[1]; out[3 * i + 2] = rgb[2];
  }
  return out;
}
export function fillFactors(lattice, symmetric, onPlane=()=>false, out = new Float32Array(lattice.count)) {
  for (let i = 0; i < lattice.count; i++)
    out[i] = orbitFactorFromData(lattice.kind[i],lattice.divisor[i],symmetric,lattice.kind[i]===2&&onPlane(i));
  return out;
}

export function pointCloud(lattice, material, symmetric, categories) {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(lattice.xyz, 3));
  // Float32 is exact for this protocol's bounded integer discriminants. Integer
  // WebGL attributes cannot be bound to a float shader attribute without conversion.
  geometry.setAttribute('aDelta', new THREE.BufferAttribute(new Float32Array(lattice.delta), 1));
  geometry.setAttribute('aKind', new THREE.BufferAttribute(new Float32Array(lattice.kind), 1));
  geometry.setAttribute('color', new THREE.BufferAttribute(fillColors(lattice, symmetric, categories), 3, true));
  geometry.setAttribute('aFactor', new THREE.BufferAttribute(fillFactors(lattice, symmetric, () => false), 1));
  material.uniforms.uCatalogue.value.set(...catalogueUniform(lattice));
  const points = new THREE.Points(geometry, material);
  points.frustumCulled = false;
  return points;
}
