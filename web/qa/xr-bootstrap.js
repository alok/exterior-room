// SPDX-License-Identifier: GPL-3.0-or-later
import { installTestXR } from './xr-runtime.js';

// The ordinary application never imports this module. Its optional bootstrap checks this explicit flag too.
if (new URLSearchParams(location.search).get('qaXR') !== '1') throw new Error('XR test runtime requires ?qaXR=1');
installTestXR();
const banner = document.createElement('div');
banner.id = 'xr-emulation-banner';
banner.textContent = 'EMULATED WEBXR · synthetic device input · no headset evidence';
banner.setAttribute('role', 'note');
Object.assign(banner.style, { position: 'fixed', top: '0', left: '0', right: '0', zIndex: '2147483647',
  background: '#4a2c00', color: '#fff3cd', textAlign: 'center', font: 'bold 12px/22px system-ui', pointerEvents: 'none' });
document.body.append(banner);
// Dynamic app bootstrap may finish after the iframe's load event. Notify both standalone
// listeners and our same-origin QA parent only after installation and the visible label exist.
window.dispatchEvent(new CustomEvent('xr-test-runtime-ready'));
if (parent !== window) parent.postMessage({ type: 'exterior-room-qa-xr-ready' }, location.origin);
