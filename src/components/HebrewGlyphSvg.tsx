import React from 'react';
import { StrokePath } from '../types/hebrew';

interface HebrewGlyphSvgProps {
  strokes: StrokePath[];
  size?: number;
  className?: string;
  strokeWidth?: number;
  showGuides?: boolean;
  showStartDots?: boolean;
  activeStrokeIndex?: number | null;
  ghostOpacity?: number;
}

export const HebrewGlyphSvg: React.FC<HebrewGlyphSvgProps> = ({
  strokes,
  size = 64,
  className = '',
  strokeWidth = 6,
  showGuides = false,
  showStartDots = false,
  activeStrokeIndex = null,
  ghostOpacity = 1,
}) => {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 100 100"
      className={className}
      aria-hidden="true"
    >
      {showGuides && (
        <g className="stroke-guide-lines">
          <line x1="8" y1="24" x2="92" y2="24" strokeDasharray="3 3" strokeWidth="1" />
          <line x1="8" y1="78" x2="92" y2="78" strokeWidth="1.2" />
          <line x1="8" y1="94" x2="92" y2="94" strokeDasharray="2 3" strokeWidth="0.9" />
        </g>
      )}

      {strokes.map((stroke, idx) => {
        const isAnimating = activeStrokeIndex !== null;
        const isCurrent = activeStrokeIndex === idx;
        const isCompleted = activeStrokeIndex !== null && idx < activeStrokeIndex;
        const sharedStart = showStartDots && !isAnimating
          ? strokes.flatMap((item, index) => item.startX === stroke.startX && item.startY === stroke.startY ? [index] : [])
          : [idx];

        let strokeOpacity = ghostOpacity;
        let strokeClass = 'glyph-stroke-path';
        if (isAnimating) {
          if (isCurrent) {
            strokeOpacity = 1;
            strokeClass = 'glyph-stroke-path glyph-stroke-active';
          } else if (isCompleted) {
            strokeOpacity = 0.92;
          } else {
            strokeOpacity = 0.16;
          }
        }

        return (
          <g key={`${idx}-${stroke.d}`}>
            <path
              d={stroke.d}
              fill="none"
              stroke={isCurrent ? 'var(--accent)' : 'currentColor'}
              strokeWidth={strokeWidth}
              strokeLinecap="round"
              strokeLinejoin="round"
              opacity={strokeOpacity}
              className={strokeClass}
              pathLength={100}
            />
            {showStartDots && (!isAnimating || isCurrent) && sharedStart[0] === idx && (
              <g>
                <ellipse
                  cx={stroke.startX}
                  cy={stroke.startY}
                  rx={sharedStart.length > 1 ? 9 : 5.5}
                  ry={5.5}
                  fill={isCurrent ? 'var(--accent)' : 'var(--accent-soft-solid)'}
                />
                <text
                  x={stroke.startX}
                  y={stroke.startY + 2.5}
                  textAnchor="middle"
                  fontSize="7"
                  fontWeight="700"
                  fill="#ffffff"
                >
                  {sharedStart.map((index) => index + 1).join('·')}
                </text>
              </g>
            )}
          </g>
        );
      })}
    </svg>
  );
};
