import LiquidGlass from 'liquid-glass-react';

export default function GlassLetterLens() {
  return (
    <div className="nav-center-lens" aria-hidden="true">
      <LiquidGlass
        displacementScale={24}
        blurAmount={0}
        saturation={135}
        aberrationIntensity={0}
        elasticity={0}
        cornerRadius={24}
        padding="0"
        mode="polar"
        style={{ position: 'absolute', top: '50%', left: '50%' }}
      >
        <span className="nav-center-lens-size" />
      </LiquidGlass>
    </div>
  );
}
