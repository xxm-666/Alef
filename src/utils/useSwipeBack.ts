import { useRef } from 'react';
import type { TouchEvent } from 'react';

const EDGE_WIDTH = 40;
const SWIPE_DISTANCE = 76;
const MAX_VERTICAL_DRIFT = 42;

export function useSwipeBack(onBack?: () => void) {
  const start = useRef<{ id: number; x: number; y: number } | null>(null);

  return {
    onTouchStart(event: TouchEvent<HTMLElement>) {
      start.current = null;
      if (!onBack || event.touches.length !== 1 || !window.matchMedia('(max-width: 768px)').matches) return;
      if (event.target instanceof Element && event.target.closest(
        'input, textarea, select, canvas, [contenteditable], .quick-letter-bar, .stroke-pad-card'
      )) return;
      const touch = event.touches[0];
      if (touch.clientX < window.innerWidth - EDGE_WIDTH) return;
      start.current = { id: touch.identifier, x: touch.clientX, y: touch.clientY };
    },
    onTouchMove(event: TouchEvent<HTMLElement>) {
      if (!start.current) return;
      const touch = event.touches[0];
      if (event.touches.length !== 1 || Math.abs(touch.clientY - start.current.y) > MAX_VERTICAL_DRIFT) {
        start.current = null;
      }
    },
    onTouchEnd(event: TouchEvent<HTMLElement>) {
      const origin = start.current;
      start.current = null;
      if (!origin || event.touches.length !== 0) return;
      const touch = Array.from(event.changedTouches).find((item) => item.identifier === origin.id);
      if (!touch) return;
      const left = origin.x - touch.clientX;
      const vertical = Math.abs(origin.y - touch.clientY);
      if (left >= SWIPE_DISTANCE && vertical <= Math.min(MAX_VERTICAL_DRIFT, left * 0.45)) onBack?.();
    },
    onTouchCancel() {
      start.current = null;
    },
  };
}
