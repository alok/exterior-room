// SPDX-License-Identifier: GPL-3.0-or-later
// Adapted from FareyVision ca809d2 by Alok Singh with OpenAI Codex, 2026-10-23:
// use accepted Lean classification/discriminant/divisor; palette and size remain renderer math.
import { recordFor } from './lean-client.js';
import { viridis } from './viridis.js';

// Upper-interior color uses Stange's fixed range: t = log(|Δ|/3) / log(240/3), clamped, so a given Δ has one
// color at every crop radius. 'viridis' maps t onto canonical Viridis over [0.2, 1] (the darkest fifth is too
// dark for single-pixel dots on black); 'reference' is her six anchors interpolated in OKLab.
export const anchors = ['#F06A6A','#E99456','#D6BD69','#7AB89B','#70A6D8','#AD92D0'];
export const paletteRange = [3, 240];
// 'viridis' categories are our choice: each lies at least 0.1 in OKLab from the ramp under normal, protan and
// deutan vision (see appearance.test.js). 'reference' keeps the v0.9 approximations of her categories (her
// viewer derives them from OKLCH lightness and chroma; exact hues unverified), whose null gold is an anchor.
export const viridisStart = 0.2;
export const categoryPalettes = {
  viridis: { null: '#f4f2ff', exterior: '#7a5230', lower: '#4d3a46' },
  reference: { null: '#d6bd69', exterior: '#448abb', lower: '#64717d' },
};

const clamp = (x,lo,hi) => Math.max(lo,Math.min(hi,x));
export const decode = hex => [1,3,5].map(i=>parseInt(hex.slice(i,i+2),16)/255);
const linear = x => x<=0.04045?x/12.92:((x+0.055)/1.055)**2.4;
const gamma = x => x<=0.0031308?12.92*x:1.055*x**(1/2.4)-0.055;
export function oklab(rgb) {
  const [r,g,b]=rgb.map(linear);
  const l=Math.cbrt(0.4122214708*r+0.5363325363*g+0.0514459929*b);
  const m=Math.cbrt(0.2119034982*r+0.6806995451*g+0.1073969566*b);
  const s=Math.cbrt(0.0883024619*r+0.2817188376*g+0.6299787005*b);
  return [0.2104542553*l+0.7936177850*m-0.0040720468*s, 1.9779984951*l-2.4285922050*m+0.4505937099*s, 0.0259040371*l+0.7827717662*m-0.8086757660*s];
}
function fromOklab([L,A,B]) {
  const l=(L+0.3963377774*A+0.2158037573*B)**3, m=(L-0.1055613458*A-0.0638541728*B)**3, s=(L-0.0894841775*A-1.2914855480*B)**3;
  return [4.0767416621*l-3.3077115913*m+0.2309699292*s, -1.2684380046*l+2.6097574011*m-0.3413193965*s, -0.0041960863*l-0.7034186147*m+1.7076147010*s]
    .map(x=>clamp(gamma(clamp(x,0,1)),0,1));
}
const anchorLab = anchors.map(hex=>oklab(decode(hex)));

export const palettePosition = magnitude => clamp(Math.log(magnitude/paletteRange[0])/Math.log(paletteRange[1]/paletteRange[0]),0,1);
export function paletteSample(t, palette='viridis') {
  if(palette==='viridis'){
    const x=(viridisStart+(1-viridisStart)*clamp(t,0,1))*(viridis.length-1), i=Math.min(viridis.length-2,Math.floor(x)), f=x-i;
    return viridis[i].map((a,j)=>a*(1-f)+viridis[i+1][j]*f);
  }
  const x=clamp(t,0,1)*(anchorLab.length-1), i=Math.min(anchorLab.length-2,Math.floor(x)), f=x-i;
  return fromOklab(anchorLab[i].map((a,j)=>a*(1-f)+anchorLab[i+1][j]*f));
}
// Colors use the actual Δ of the triple; a nonprimitive multiple k·p has Δ scaled by k².
export function coefficientColor(point, symmetric=false, palette='viridis') {
  const {kind:type,delta}=recordFor(point);
  if(type!=='upper'&&!(type==='lower'&&symmetric))return decode(categoryPalettes[palette][type]);
  return paletteSample(palettePosition(-delta),palette);
}
export function gradientCSS(palette='viridis') {
  const stops=Array.from({length:17},(_,i)=>`rgb(${paletteSample(i/16,palette).map(x=>Math.round(x*255)).join(' ')}) ${i*100/16}%`);
  return `linear-gradient(to right,${stops.join(',')})`;
}

// Dot sizes reproduce the causes in Stange's viewer (constants from its public bundle, read 2026-10-22):
// a world-space star radius, perspective (radius · focal / depth), and a minimum footprint below which
// the dot keeps that size and dims by (px/min)². In her whole-lattice mode the world radius is 0.15 for
// every primitive point, 0.72 of that for a nonprimitive upper star, ×1.35 for upper stars on a selected
// plane, and with the eye at the origin 0.06·|Δ|^¼/√(a+c) for upper stars (off-cone points fade out there). Seen from the origin along the axis,
// depth is a+c, so apparent radius ∝ |Δ|^¼/(a+c)^{3/2} = |Δ|^{-½}·(1−|u|²)^{¾} at Klein position u:
// 1/√|Δ| times a model-position factor, and exactly 1/√|Δ| along one ray of multiples.
// Our departures: the base radius is relative to our smaller crop; above `knee` pixels the radius
// grows only as the cube root, capped at `capPixels`, so near dots stay point-like; and the minimum
// footprint is 1 CSS pixel instead of her 0.6 so colors stay readable; at the origin we keep off-cone
// points visible at the standard radius and size the lower interior by the same rule through |a+c|.
export const glyphRadius = 0.013;
export const sizePixels = { min: 1, knee: 2.5, cap: 9 };
export const outlinePixels = 1.25;
// Scalar compatibility helper; one accepted-record lookup. Dense code should use
// the packed helpers below rather than repeatedly binary-searching point triples.
export function orbitFactor(a, b, c, symmetric=false, onPlane=false) {
  const r=recordFor([a,b,c]);
  return orbitFactorFromData(r.kind,r.divisor,symmetric,onPlane);
}
export function orbitFactorFromData(type,divisor,symmetric=false,onPlane=false){
  if(type!=='upper'&&type!==2&&!(symmetric&&(type==='lower'||type===3)))return 1;
  return (divisor===1?1:0.72)*(onPlane?1.35:1);
}
export function sourceRadiusFactorFromData(delta,type,divisor,displayY,{origin=false,onPlane=false,symmetric=false}={}){
  const interior=type==='upper'||type==='lower'||type===2||type===3;
  if(!interior)return 1;
  if(origin)return 0.4*Math.abs(delta)**0.25/Math.sqrt(Math.abs(displayY));
  return orbitFactorFromData(type,divisor,symmetric,onPlane);
}
export function sourceRadiusFactor(point, { origin=false, onPlane=false, symmetric=false } = {}) {
  const r=recordFor(point);
  return sourceRadiusFactorFromData(r.delta,r.kind,r.divisor,r.xyz[1],{origin,onPlane,symmetric});
}
// Maps a perspective radius to the drawn radius and the color factor that stands in for her alpha
// (the background is black, so alpha over it is a scale of the color).
export function drawnPixels(pixels) {
  if(!(pixels>0))return { px: sizePixels.min, dim: 0 };
  if(pixels<sizePixels.min)return { px: sizePixels.min, dim: (pixels/sizePixels.min)**2 };
  const { knee, cap } = sizePixels;
  return { px: Math.min(cap, pixels<=knee?pixels:knee*Math.cbrt(pixels/knee)), dim: 1 };
}
export const pixelsPerWorld = (depth, viewportHeight, fovDegrees, zoom=1) =>
  viewportHeight*zoom/(2*depth*Math.tan(fovDegrees*Math.PI/360));
// Scale applied to a glyph of radius glyphRadius so it draws at drawnPixels(...) plus extraPixels.
export function glyphScale(depth, viewportHeight, fovDegrees, zoom=1, extraPixels=0, factor=1) {
  if(!(depth>0)||!(viewportHeight>0))return 1;
  const base=glyphRadius*pixelsPerWorld(depth,viewportHeight,fovDegrees,zoom);
  return (drawnPixels(base*factor).px+extraPixels)/base;
}
