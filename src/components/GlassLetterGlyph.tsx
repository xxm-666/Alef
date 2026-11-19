import { useMemo } from 'react';

const LENS_SIZE = 48;

function createDisplacementMap() {
  const canvas = document.createElement('canvas');
  canvas.width = LENS_SIZE;
  canvas.height = LENS_SIZE;
  const context = canvas.getContext('2d');
  if (!context) return '';

  const map = context.createImageData(LENS_SIZE, LENS_SIZE);
  const center = LENS_SIZE / 2;
  for (let y = 0; y < LENS_SIZE; y += 1) {
    for (let x = 0; x < LENS_SIZE; x += 1) {
      const nx = (x + 0.5 - center) / center;
      const ny = (y + 0.5 - center) / center;
      const radius = Math.hypot(nx, ny);
      // Bend the backdrop near the rim and keep the middle of the lens clear.
      const rim = Math.exp(-((radius - 0.78) ** 2) / 0.023);
      const offset = (y * LENS_SIZE + x) * 4;
      map.data[offset] = 128 - 110 * nx * rim;
      map.data[offset + 1] = 128 - 110 * ny * rim;
      map.data[offset + 3] = 255;
    }
  }
  context.putImageData(map, 0, 0);
  return canvas.toDataURL();
}

export function GlassLetterGlyph() {
  const map = useMemo(createDisplacementMap, []);

  return (
    <span className="nav-center-glyph" aria-hidden="true">
      {map && (
        <svg className="nav-center-optics" width="0" height="0" focusable="false">
          <defs>
            <filter
              id="alef-letter-refraction"
              x="0%"
              y="0%"
              width="100%"
              height="100%"
              colorInterpolationFilters="sRGB"
            >
              <feImage href={map} x="0%" y="0%" width="100%" height="100%" result="displacement" />
              <feDisplacementMap in="SourceGraphic" in2="displacement" scale="16" xChannelSelector="R" yChannelSelector="G" />
            </filter>
          </defs>
        </svg>
      )}
      <span>א</span>
    </span>
  );
}
