// SPDX-License-Identifier: GPL-3.0-or-later
// Recording layout only. No application state, rendering or mathematical fallback.
function size(value) {
  if (!value || !Number.isFinite(value.width) || !Number.isFinite(value.height) || value.width <= 0 || value.height <= 0) {
    throw new RangeError('Each capture source needs a positive finite width and height');
  }
  return value;
}

/** One or two actual canvases, at their relative backing-pixel sizes, placed side by side.
 * The content area excludes the separately disclosed evidence stripe. */
export function captureLayout(sources, maxWidth = 1280, maxHeight = 800) {
  if (!Array.isArray(sources) || sources.length < 1 || sources.length > 2) throw new RangeError('Capture requires one or two app canvases');
  size({width:maxWidth,height:maxHeight});sources.forEach(size);
  const naturalWidth = sources.reduce((sum, source) => sum + source.width, 0);
  const naturalHeight = Math.max(...sources.map(source => source.height));
  const scale = Math.min(1, maxWidth / naturalWidth, maxHeight / naturalHeight);
  const width = Math.min(maxWidth, Math.max(1, Math.ceil(naturalWidth * scale)));
  const height = Math.min(maxHeight, Math.max(1, Math.ceil(naturalHeight * scale)));
  let x = 0;
  const slots = sources.map(source => {
    const slot = {x,y:0,width:source.width * scale,height};x += slot.width;return slot;
  });
  return {width,height,slots};
}

/** Fit each current video frame into its fixed recording slot without stretching,
 * including after a resize that leaves the same visible canvas set. */
export function fitCaptureSource(source, slot) {
  size(source);size(slot);
  const scale = Math.min(slot.width / source.width, slot.height / source.height);
  const width = source.width * scale, height = source.height * scale;
  return {x:slot.x + (slot.width-width)/2,y:slot.y + (slot.height-height)/2,width,height};
}

export function sameCanvasSet(previous, current) {
  return previous.length === current.length && previous.every((canvas, i) => canvas === current[i]);
}
