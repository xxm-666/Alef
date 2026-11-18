import React, { useEffect, useRef, useState } from 'react';
import { Eraser, Eye, EyeOff, Play, RotateCcw } from 'lucide-react';
import { HebrewLetter, StrokePath } from '../types/hebrew';
import { HebrewGlyphSvg } from './HebrewGlyphSvg';

interface StrokeOrderPadProps {
  letter: HebrewLetter;
}

type ScriptKind = 'cursive' | 'block';
type FormKind = 'medial' | 'sofit';

export const StrokeOrderPad: React.FC<StrokeOrderPadProps> = ({ letter }) => {
  const [scriptKind, setScriptKind] = useState<ScriptKind>('cursive');
  const [formKind, setFormKind] = useState<FormKind>('medial');
  const [activeStep, setActiveStep] = useState<number | null>(null);
  const [isPlaying, setIsPlaying] = useState(false);
  const [showGhost, setShowGhost] = useState(true);
  const [hasDrawn, setHasDrawn] = useState(false);

  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const drawingRef = useRef(false);

  const hasSofit = Boolean(letter.sofit && letter.strokeGuide.sofitCursiveStrokes);
  const effectiveForm: FormKind = hasSofit ? formKind : 'medial';

  let strokes: StrokePath[] = letter.strokeGuide.cursiveStrokes;
  let steps: string[] = letter.strokeGuide.cursiveSteps;

  if (effectiveForm === 'sofit') {
    if (scriptKind === 'block' && letter.strokeGuide.sofitBlockStrokes) {
      strokes = letter.strokeGuide.sofitBlockStrokes;
      steps = letter.strokeGuide.sofitBlockSteps ?? letter.strokeGuide.blockSteps;
    } else if (letter.strokeGuide.sofitCursiveStrokes) {
      strokes = letter.strokeGuide.sofitCursiveStrokes;
      steps = letter.strokeGuide.sofitCursiveSteps ?? letter.strokeGuide.cursiveSteps;
    }
  } else if (scriptKind === 'block') {
    strokes = letter.strokeGuide.blockStrokes;
    steps = letter.strokeGuide.blockSteps;
  }

  useEffect(() => {
    setFormKind('medial');
    setActiveStep(null);
    setIsPlaying(false);
    clearCanvas();
  }, [letter.id]);

  useEffect(() => {
    setActiveStep(null);
    setIsPlaying(false);
  }, [scriptKind, effectiveForm]);

  useEffect(() => {
    if (!isPlaying) return;
    let current = 0;
    setActiveStep(0);

    const timer = window.setInterval(() => {
      current += 1;
      if (current >= strokes.length) {
        setActiveStep(null);
        setIsPlaying(false);
        window.clearInterval(timer);
      } else {
        setActiveStep(current);
      }
    }, 1150);

    return () => window.clearInterval(timer);
  }, [isPlaying, strokes.length]);

  function clearCanvas() {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    setHasDrawn(false);
  }

  function getCanvasCoords(e: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    if (!canvas) return { x: 0, y: 0 };
    const rect = canvas.getBoundingClientRect();
    return {
      x: ((e.clientX - rect.left) / rect.width) * canvas.width,
      y: ((e.clientY - rect.top) / rect.height) * canvas.height,
    };
  }

  function handlePointerDown(e: React.PointerEvent<HTMLCanvasElement>) {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    canvas.setPointerCapture(e.pointerId);
    const { x, y } = getCanvasCoords(e);
    drawingRef.current = true;
    setHasDrawn(true);
    ctx.beginPath();
    ctx.moveTo(x, y);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.lineWidth = 10;
    ctx.strokeStyle = getComputedStyle(document.documentElement)
      .getPropertyValue('--accent')
      .trim() || '#38bdf8';
  }

  function handlePointerMove(e: React.PointerEvent<HTMLCanvasElement>) {
    if (!drawingRef.current) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const { x, y } = getCanvasCoords(e);
    ctx.lineTo(x, y);
    ctx.stroke();
  }

  function handlePointerUp() {
    drawingRef.current = false;
  }

  return (
    <div className="stroke-pad-card">
      <div className="stroke-pad-header">
        <div>
          <h4 className="section-title">笔顺演示与描红练习</h4>
          <p className="muted-caption">
            {scriptKind === 'cursive' ? '现代手写体 (Ktav)' : '印刷体 (Block)'}
            {effectiveForm === 'sofit' ? ' · 词尾形 (Sofit)' : ''}
            {' · 共 '}
            {strokes.length}
            {' 笔'}
          </p>
        </div>

        <div className="stroke-toggles">
          <div className="segmented-control">
            <button
              type="button"
              className={scriptKind === 'cursive' ? 'active' : ''}
              onClick={() => setScriptKind('cursive')}
            >
              手写体
            </button>
            <button
              type="button"
              className={scriptKind === 'block' ? 'active' : ''}
              onClick={() => setScriptKind('block')}
            >
              印刷体
            </button>
          </div>

          {hasSofit && (
            <div className="segmented-control">
              <button
                type="button"
                className={effectiveForm === 'medial' ? 'active' : ''}
                onClick={() => setFormKind('medial')}
              >
                常规 ({letter.hebrew})
              </button>
              <button
                type="button"
                className={effectiveForm === 'sofit' ? 'active' : ''}
                onClick={() => setFormKind('sofit')}
              >
                词尾 ({letter.sofit})
              </button>
            </div>
          )}
        </div>
      </div>

      <div className="stroke-pad-body">
        <div className="stroke-demo-pane">
          <div className="stroke-canvas-box">
            <HebrewGlyphSvg
              strokes={strokes}
              size={180}
              strokeWidth={5.5}
              showGuides
              showStartDots
              activeStrokeIndex={activeStep}
            />
          </div>
          <div className="stroke-controls-row">
            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={() => {
                setIsPlaying(false);
                window.setTimeout(() => setIsPlaying(true), 20);
              }}
            >
              {isPlaying ? <RotateCcw size={14} /> : <Play size={14} />}
              <span>{isPlaying ? '重播笔顺' : '动画演示'}</span>
            </button>
            <div className="step-pills">
              {strokes.map((_, idx) => (
                <button
                  key={idx}
                  type="button"
                  className={`step-pill ${activeStep === idx ? 'active' : ''}`}
                  onClick={() => {
                    setIsPlaying(false);
                    setActiveStep(activeStep === idx ? null : idx);
                  }}
                >
                  第{idx + 1}笔
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className="stroke-practice-pane">
          <div className="stroke-canvas-box practice-box">
            {showGhost ? (
              <HebrewGlyphSvg
                strokes={strokes}
                size={180}
                strokeWidth={5.5}
                showGuides
                ghostOpacity={0.22}
                className="practice-ghost-svg"
              />
            ) : (
              <HebrewGlyphSvg
                strokes={[]}
                size={180}
                showGuides
                className="practice-ghost-svg"
              />
            )}
            <canvas
              ref={canvasRef}
              width={360}
              height={360}
              className="drawing-canvas"
              onPointerDown={handlePointerDown}
              onPointerMove={handlePointerMove}
              onPointerUp={handlePointerUp}
              onPointerCancel={handlePointerUp}
            />
            {!hasDrawn && (
              <span className="practice-placeholder">在此按住鼠标或触控笔描红</span>
            )}
          </div>
          <div className="stroke-controls-row">
            <button
              type="button"
              className="btn-ghost btn-sm"
              onClick={() => setShowGhost((v) => !v)}
            >
              {showGhost ? <EyeOff size={14} /> : <Eye size={14} />}
              <span>{showGhost ? '隐藏底纹' : '显示底纹'}</span>
            </button>
            <button
              type="button"
              className="btn-ghost btn-sm"
              onClick={clearCanvas}
            >
              <Eraser size={14} />
              <span>清空画板</span>
            </button>
          </div>
        </div>
      </div>

      <ol className="stroke-steps-list">
        {steps.map((step, idx) => (
          <li
            key={idx}
            className={activeStep === idx ? 'highlighted-step' : ''}
            onClick={() => {
              setIsPlaying(false);
              setActiveStep(idx);
            }}
          >
            {step}
          </li>
        ))}
      </ol>
    </div>
  );
};
