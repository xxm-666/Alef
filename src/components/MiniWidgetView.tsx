import React, { useState } from 'react';
import {
  ArrowLeft,
  ArrowRight,
  Maximize2,
  Pin,
  PinOff,
  Volume2,
  X,
} from 'lucide-react';
import {
  AlphabetOrder,
  ElectronWindowState,
  HebrewLetter,
} from '../types/hebrew';
import { HebrewGlyphSvg } from './HebrewGlyphSvg';
import { speakHebrew } from '../utils/audio';

interface MiniWidgetViewProps {
  letters: HebrewLetter[];
  selectedLetter: HebrewLetter;
  onSelectLetter: (letterId: string) => void;
  order: AlphabetOrder;
  windowState: ElectronWindowState;
  onExitMiniMode: () => void;
  onToggleAlwaysOnTop: () => void;
  onChangeOpacity: (opacity: number) => void;
  onClose: () => void;
  speechRate: number;
}

export const MiniWidgetView: React.FC<MiniWidgetViewProps> = ({
  letters,
  selectedLetter,
  onSelectLetter,
  order,
  windowState,
  onExitMiniMode,
  onToggleAlwaysOnTop,
  onChangeOpacity,
  onClose,
  speechRate,
}) => {
  const [miniTab, setMiniTab] = useState<'grid' | 'card'>('grid');
  const [showCursiveInGrid, setShowCursiveInGrid] = useState(false);

  const idx = letters.findIndex((l) => l.id === selectedLetter.id);
  const prev = idx > 0 ? letters[idx - 1] : letters[letters.length - 1];
  const next = idx < letters.length - 1 ? letters[idx + 1] : letters[0];

  return (
    <div className="mini-widget-shell">
      <header className="mini-header">
        <div className="mini-title-left">
          <span className="brand-badge mini" dir="rtl">
            אב
          </span>
          <span className="mini-title-text">Alef 随身贴</span>
        </div>

        <div className="mini-header-actions">
          <input
            type="range"
            min={0.45}
            max={1}
            step={0.05}
            value={windowState.opacity}
            onChange={(e) => onChangeOpacity(Number(e.target.value))}
            title={`透明度 ${Math.round(windowState.opacity * 100)}%`}
            className="mini-opacity-slider"
          />
          <button
            type="button"
            className={`mini-icon-btn ${windowState.isAlwaysOnTop ? 'pinned' : ''}`}
            onClick={onToggleAlwaysOnTop}
            title={windowState.isAlwaysOnTop ? '取消置顶' : '置顶窗口'}
          >
            {windowState.isAlwaysOnTop ? <Pin size={13} /> : <PinOff size={13} />}
          </button>
          <button
            type="button"
            className="mini-icon-btn"
            onClick={onExitMiniMode}
            title="恢复标准窗口"
          >
            <Maximize2 size={13} />
          </button>
          {windowState.isElectron && (
            <button
              type="button"
              className="mini-icon-btn close"
              onClick={onClose}
              title="关闭"
            >
              <X size={13} />
            </button>
          )}
        </div>
      </header>

      <div className="mini-tabs-bar">
        <div className="segmented-control">
          <button
            type="button"
            className={miniTab === 'grid' ? 'active' : ''}
            onClick={() => setMiniTab('grid')}
          >
            22 字母速查
          </button>
          <button
            type="button"
            className={miniTab === 'card' ? 'active' : ''}
            onClick={() => setMiniTab('card')}
          >
            单字随身卡
          </button>
        </div>

        {miniTab === 'grid' && (
          <button
            type="button"
            className={`btn-ghost btn-xs ${showCursiveInGrid ? 'active-btn' : ''}`}
            onClick={() => setShowCursiveInGrid((v) => !v)}
          >
            {showCursiveInGrid ? '手写体' : '印刷体'}
          </button>
        )}
      </div>

      {miniTab === 'grid' ? (
        <div
          className="mini-grid"
          style={{ direction: order === 'rtl' ? 'rtl' : 'ltr' }}
        >
          {letters.map((item) => (
            <button
              key={item.id}
              type="button"
              className={`mini-cell ${item.id === selectedLetter.id ? 'active' : ''}`}
              style={{ direction: 'ltr' }}
              onClick={() => {
                onSelectLetter(item.id);
                setMiniTab('card');
              }}
              title={`${item.nameEnglish} (${item.nameChinese}) ${item.modernIpa}`}
            >
              {showCursiveInGrid ? (
                <HebrewGlyphSvg
                  strokes={item.strokeGuide.cursiveStrokes}
                  size={30}
                  strokeWidth={6.5}
                />
              ) : (
                <span className="mini-cell-char" dir="rtl">
                  {item.hebrew}
                  {item.sofit ? <small className="mini-sofit">{item.sofit}</small> : null}
                </span>
              )}
              <span className="mini-cell-sound">{item.modernIpa}</span>
            </button>
          ))}
        </div>
      ) : (
        <div className="mini-card-body">
          <div className="mini-card-nav">
            <button
              type="button"
              className="btn-secondary btn-xs"
              onClick={() => onSelectLetter(prev.id)}
            >
              <ArrowLeft size={13} />
              <span>{prev.hebrew}</span>
            </button>
            <span className="muted-caption">
              #{selectedLetter.order} · ={selectedLetter.gematria}
            </span>
            <button
              type="button"
              className="btn-secondary btn-xs"
              onClick={() => onSelectLetter(next.id)}
            >
              <span>{next.hebrew}</span>
              <ArrowRight size={13} />
            </button>
          </div>

          <div className="mini-glyph-pair">
            <div className="mini-glyph-box">
              <span className="mini-label">印刷</span>
              <span className="mini-big-hebrew" dir="rtl">
                {selectedLetter.hebrew}
                {selectedLetter.sofit ? ` / ${selectedLetter.sofit}` : ''}
              </span>
            </div>
            <div className="mini-glyph-box">
              <span className="mini-label">手写</span>
              <HebrewGlyphSvg
                strokes={selectedLetter.strokeGuide.cursiveStrokes}
                size={64}
                strokeWidth={6}
              />
            </div>
          </div>

          <div className="mini-name-row">
            <div>
              <strong dir="rtl">{selectedLetter.nameHebrew}</strong>{' '}
              <span>
                {selectedLetter.nameEnglish} · {selectedLetter.nameChinese}
              </span>
            </div>
            <button
              type="button"
              className="btn-primary btn-xs"
              onClick={() =>
                speakHebrew(
                  selectedLetter.nameHebrew,
                  selectedLetter.nameEnglish,
                  speechRate
                )
              }
            >
              <Volume2 size={13} />
              <span>朗读</span>
            </button>
          </div>

          <div className="mini-info-stack">
            <div className="mini-info-box">
              <strong>现代读音 {selectedLetter.modernIpa}</strong>
              <p>{selectedLetter.modernSound}</p>
            </div>
            <div className="mini-info-box">
              <strong>圣经差异 {selectedLetter.biblicalIpa}</strong>
              <p>{selectedLetter.biblicalDiff}</p>
            </div>
            {selectedLetter.begadkefat && (
              <div className="mini-info-box">
                <strong>Dagesh 音变</strong>
                <p dir="auto">
                  {selectedLetter.begadkefat.withDagesh.glyph}{' '}
                  {selectedLetter.begadkefat.withDagesh.modernIpa} /{' '}
                  {selectedLetter.begadkefat.withoutDagesh.glyph}{' '}
                  {selectedLetter.begadkefat.withoutDagesh.modernIpa}
                </p>
              </div>
            )}
            {selectedLetter.examples[0] && (
              <div className="mini-info-box">
                <strong>例词</strong>
                <p>
                  <span dir="rtl" className="ex-heb">
                    {selectedLetter.examples[0].hebrew}
                  </span>{' '}
                  <code>{selectedLetter.examples[0].transliteration}</code> —{' '}
                  {selectedLetter.examples[0].meaning}
                </p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
