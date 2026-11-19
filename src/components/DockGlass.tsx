import LiquidGlass from 'liquid-glass-react';

export default function DockGlass() {
  return (
    <div className="dock-glass-layer" aria-hidden="true">
      <LiquidGlass
        displacementScale={28}
        blurAmount={0.08}
        saturation={145}
        aberrationIntensity={1.2}
        elasticity={0}
        cornerRadius={999}
        padding="0"
        mode="shader"
        style={{ position: 'absolute', top: '50%', left: '50%', width: '100%', height: '100%' }}
      >
        <span />
      </LiquidGlass>
    </div>
  );
}
