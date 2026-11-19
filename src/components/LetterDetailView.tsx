import React, { useEffect, useRef, useState } from 'react';
import {
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  BookOpen,
  CheckCircle2,
  Circle,
  Clock,
  Sparkles,
  Volume2,
} from 'lucide-react';
import {
  AlphabetOrder,
  HebrewLetter,
  MasteryLevel,
} from '../types/hebrew';
import { HebrewGlyphSvg } from './HebrewGlyphSvg';
import { StrokeOrderPad } from './StrokeOrderPad';
import { getSpeechStatus, speakHebrew } from '../utils/audio';

interface LetterDetailViewProps {
  letters: HebrewLetter[];
  selectedLetter: HebrewLetter;
  onSelectLetter: (letterId: string) => void;
  order: AlphabetOrder;
  masteryMap: Record<string, MasteryLevel>;
  onSetMastery: (letterId: string, level: MasteryLevel) => void;
  speechRate: number;
}

const MASTERY_OPTIONS: { level: MasteryLevel; label: string; icon: React.ReactNode }[] = [
  { level: 'unlearned', label: '未学', icon: <Circle size={14} /> },
  { level: 'learning', label: '学习中', icon: <Clock size={14} /> },
  { level: 'mastered', label: '已掌握', icon: <CheckCircle2 size={14} /> },
];

export const LetterDetailView: React.FC<LetterDetailViewProps> = ({
  letters,
  selectedLetter,
  onSelectLetter,
  order,
  masteryMap,
  onSetMastery,
  speechRate,
}) => {
  const examplesRef = useRef<HTMLDivElement>(null);
  const writingRef = useRef<HTMLDivElement>(null);

  const [dageshActive, setDageshActive] = useState(true);
  const [speechNotice, setSpeechNotice] = useState<string | null>(null);

  function jumpToSection(ref: React.RefObject<HTMLDivElement>) {
    ref.current?.focus({ preventScroll: true });
    ref.current?.scrollIntoView({ block: 'start' });
  }

  const currentIndex = letters.findIndex((l) => l.id === selectedLetter.id);
  const prevLetter = currentIndex > 0 ? letters[currentIndex - 1] : letters[letters.length - 1];
  const nextLetter = currentIndex < letters.length - 1 ? letters[currentIndex + 1] : letters[0];
  const currentMastery = masteryMap[selectedLetter.id] ?? 'unlearned';

  useEffect(() => {
    setDageshActive(true);
    setSpeechNotice(null);
  }, [selectedLetter.id]);

  useEffect(() => {
    function handleKeyDown(e: KeyboardEvent) {
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      ) {
        return;
      }
      if (e.key === 'ArrowLeft') {
        if (order === 'rtl') {
          onSelectLetter(nextLetter.id);
        } else {
          onSelectLetter(prevLetter.id);
        }
      } else if (e.key === 'ArrowRight') {
        if (order === 'rtl') {
          onSelectLetter(prevLetter.id);
        } else {
          onSelectLetter(nextLetter.id);
        }
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [order, prevLetter.id, nextLetter.id, onSelectLetter]);

  function handleSpeak(hebrewText: string, fallbackText: string) {
    const res = speakHebrew(hebrewText, fallbackText, speechRate);
    if (res.mode === 'phonetic-tts') {
      const status = getSpeechStatus();
      if (!status.hasHebrewVoice) {
        setSpeechNotice('系统未检测到希伯来语 (he-IL) TTS 语音包，已自动改用音译参考朗读。');
      }
    } else if (res.mode === 'unavailable') {
      setSpeechNotice('当前环境暂不支持语音合成，请结合 IPA 音标与中文口型要领练习。');
    } else {
      setSpeechNotice(null);
    }
  }

  const confusableLetters = selectedLetter.confusableWith
    .map((id) => letters.find((l) => l.id === id))
    .filter((item): item is HebrewLetter => Boolean(item));

  return (
    <div className="view-container detail-view">
      {/* 22-letter quick navigation strip */}
      <div className="detail-nav-strip">
        <button
          type="button"
          className="btn-secondary btn-sm"
          onClick={() => onSelectLetter(prevLetter.id)}
          title={`上一个：${prevLetter.nameEnglish}`}
        >
          <ArrowLeft size={14} />
          <span>
            {prevLetter.hebrew} {prevLetter.nameEnglish}
          </span>
        </button>

        <div
          className="quick-letter-bar"
          style={{ direction: order === 'rtl' ? 'rtl' : 'ltr' }}
        >
          {letters.map((item) => {
            const isActive = item.id === selectedLetter.id;
            const m = masteryMap[item.id] ?? 'unlearned';
            return (
              <button
                key={item.id}
                type="button"
                className={`quick-letter-chip ${isActive ? 'active' : ''} m-${m}`}
                onClick={() => onSelectLetter(item.id)}
                title={`${item.order}. ${item.nameEnglish} (${item.nameChinese})`}
              >
                {item.hebrew}
              </button>
            );
          })}
        </div>

        <button
          type="button"
          className="btn-secondary btn-sm"
          onClick={() => onSelectLetter(nextLetter.id)}
          title={`下一个：${nextLetter.nameEnglish}`}
        >
          <span>
            {nextLetter.hebrew} {nextLetter.nameEnglish}
          </span>
          <ArrowRight size={14} />
        </button>
      </div>

      <div className="detail-section-links" role="group" aria-label="单字卡片快捷跳转">
        <button
          type="button"
          className="btn-secondary btn-sm"
          onClick={() => jumpToSection(examplesRef)}
        >
          例词
        </button>
        <button
          type="button"
          className="btn-secondary btn-sm"
          onClick={() => jumpToSection(writingRef)}
        >
          书写练习
        </button>
      </div>

      <div className="detail-hero-card">
        <div className="hero-glyph-column">
          <div className="hero-glyph-pair">
            <div className="glyph-stage-box">
              <span className="stage-label">印刷体 (Block)</span>
              <span className="hero-hebrew-char" dir="rtl">
                {selectedLetter.begadkefat
                  ? dageshActive
                    ? selectedLetter.begadkefat.withDagesh.glyph
                    : selectedLetter.begadkefat.withoutDagesh.glyph
                  : selectedLetter.hebrew}
              </span>
              {selectedLetter.sofit && (
                <span className="stage-sub-badge" dir="rtl">
                  词尾：{selectedLetter.sofit}
                </span>
              )}
            </div>

            <div className="glyph-stage-box">
              <span className="stage-label">手写体 (Cursive)</span>
              <HebrewGlyphSvg
                strokes={selectedLetter.strokeGuide.cursiveStrokes}
                size={96}
                strokeWidth={5.5}
                showGuides
                className="hero-cursive-svg"
              />
              {selectedLetter.strokeGuide.sofitCursiveStrokes && (
                <div className="stage-sub-cursive" title="手写体词尾形">
                  <span>词尾：</span>
                  <HebrewGlyphSvg
                    strokes={selectedLetter.strokeGuide.sofitCursiveStrokes}
                    size={30}
                    strokeWidth={6}
                  />
                </div>
              )}
            </div>
          </div>

          <div className="hero-audio-row">
            <button
              type="button"
              className="btn-primary"
              onClick={() =>
                handleSpeak(selectedLetter.nameHebrew, selectedLetter.nameEnglish)
              }
            >
              <Volume2 size={16} />
              <span>朗读字母 ({selectedLetter.nameHebrew})</span>
            </button>
            <div className="mastery-segmented">
              {MASTERY_OPTIONS.map((opt) => (
                <button
                  key={opt.level}
                  type="button"
                  className={currentMastery === opt.level ? `active m-${opt.level}` : ''}
                  onClick={() => onSetMastery(selectedLetter.id, opt.level)}
                >
                  {opt.icon}
                  <span>{opt.label}</span>
                </button>
              ))}
            </div>
          </div>

          {speechNotice && <p className="speech-notice">{speechNotice}</p>}
        </div>

        <div className="hero-info-column">
          <div className="detail-title-row">
            <div>
              <div className="detail-meta-pills">
                <span className="meta-badge">第 {selectedLetter.order} 个字母</span>
                <span className="meta-badge gematria">
                  Gematria 数值：{selectedLetter.gematria}
                  {selectedLetter.sofitInfo
                    ? ` / 词尾 ${selectedLetter.sofitInfo.sofitGematria}`
                    : ''}
                </span>
                <span className="meta-badge">
                  转写：<code>{selectedLetter.transliteration}</code>
                </span>
              </div>
              <h2 className="detail-heading">
                <span className="detail-hebrew-title" dir="rtl">
                  {selectedLetter.nameHebrew}
                </span>
                <span>{selectedLetter.nameEnglish}</span>
                <span className="detail-zh-name">· {selectedLetter.nameChinese}</span>
              </h2>
            </div>
          </div>

          <div className="detail-meaning-box">
            <div className="meaning-row">
              <Sparkles size={15} />
              <strong>象形本义：</strong>
              <span>{selectedLetter.meaning}</span>
            </div>
            <p className="etymology-text">{selectedLetter.etymology}</p>
            <p className="cursive-tip-text">
              <strong>手写识记：</strong>
              {selectedLetter.cursiveDesc}
            </p>
          </div>

          <div className="pronunciation-split">
            <div className="pron-card modern">
              <div className="pron-header">
                <span className="pron-badge modern">现代希伯来语 (主)</span>
                <code className="pron-ipa">{selectedLetter.modernIpa}</code>
              </div>
              <p className="pron-main-value">{selectedLetter.modernSound}</p>
              <p className="pron-desc">{selectedLetter.pronunciationDesc}</p>
            </div>

            <div className="pron-card biblical">
              <div className="pron-header">
                <span className="pron-badge biblical">圣经 / 古典音变对比</span>
                <code className="pron-ipa">{selectedLetter.biblicalIpa}</code>
              </div>
              <p className="pron-desc">{selectedLetter.biblicalDiff}</p>
            </div>
          </div>
        </div>
      </div>

      {/* Special rule cards: Begadkefat + Sofit */}
      {(selectedLetter.begadkefat || selectedLetter.sofitInfo) && (
        <div className="special-cards-row">
          {selectedLetter.begadkefat && (
            <div className="detail-section-card begadkefat-card">
              <div className="section-header-row">
                <div>
                  <h3 className="section-title">
                    Dagesh 点音变详解 (Begadkefat בגדכפ״ת)
                  </h3>
                  <p className="muted-caption">
                    {selectedLetter.begadkefat.modernPreserved
                      ? '现代希伯来语仍严格保留以下硬音/软音对立'
                      : '现代希伯来语已合并读音，仅古典/圣经传统保留擦音化'}
                  </p>
                </div>
                <button
                  type="button"
                  className="btn-secondary btn-sm"
                  onClick={() => setDageshActive((v) => !v)}
                >
                  切换预览：{dageshActive ? '含中心点 (Dagesh)' : '无点 (Rafe)'}
                </button>
              </div>

              <div className="dagesh-compare-grid">
                <div
                  className={`dagesh-variant-box ${dageshActive ? 'selected' : ''}`}
                  onClick={() => setDageshActive(true)}
                >
                  <div className="variant-glyph" dir="rtl">
                    {selectedLetter.begadkefat.withDagesh.glyph}
                  </div>
                  <div className="variant-info">
                    <strong>{selectedLetter.begadkefat.withDagesh.name}</strong>
                    <span>
                      现代：{selectedLetter.begadkefat.withDagesh.modernIpa} ·{' '}
                      {selectedLetter.begadkefat.withDagesh.modernSound}
                    </span>
                    <span className="muted-caption">
                      圣经：{selectedLetter.begadkefat.withDagesh.biblicalIpa}
                    </span>
                  </div>
                </div>

                <div
                  className={`dagesh-variant-box ${!dageshActive ? 'selected' : ''}`}
                  onClick={() => setDageshActive(false)}
                >
                  <div className="variant-glyph" dir="rtl">
                    {selectedLetter.begadkefat.withoutDagesh.glyph}
                  </div>
                  <div className="variant-info">
                    <strong>{selectedLetter.begadkefat.withoutDagesh.name}</strong>
                    <span>
                      现代：{selectedLetter.begadkefat.withoutDagesh.modernIpa} ·{' '}
                      {selectedLetter.begadkefat.withoutDagesh.modernSound}
                    </span>
                    <span className="muted-caption">
                      圣经：{selectedLetter.begadkefat.withoutDagesh.biblicalIpa}
                    </span>
                  </div>
                </div>
              </div>
              <p className="rule-note-text">{selectedLetter.begadkefat.note}</p>
            </div>
          )}

          {selectedLetter.sofitInfo && (
            <div className="detail-section-card sofit-card">
              <h3 className="section-title">词尾变形详解 (Sofit סוֹפִית)</h3>
              <div className="sofit-compare-row">
                <div className="sofit-side-box">
                  <span className="stage-label">词首 / 词中常规形</span>
                  <div className="sofit-glyph-pair">
                    <span className="sofit-big-glyph" dir="rtl">
                      {selectedLetter.sofitInfo.medialGlyph}
                    </span>
                    <HebrewGlyphSvg
                      strokes={selectedLetter.strokeGuide.cursiveStrokes}
                      size={48}
                      strokeWidth={6}
                    />
                  </div>
                </div>

                <div className="sofit-arrow">→ 位于词尾 →</div>

                <div className="sofit-side-box final">
                  <span className="stage-label">词尾专属形 (Sofit)</span>
                  <div className="sofit-glyph-pair">
                    <span className="sofit-big-glyph" dir="rtl">
                      {selectedLetter.sofitInfo.finalGlyph}
                    </span>
                    {selectedLetter.strokeGuide.sofitCursiveStrokes && (
                      <HebrewGlyphSvg
                        strokes={selectedLetter.strokeGuide.sofitCursiveStrokes}
                        size={48}
                        strokeWidth={6}
                      />
                    )}
                  </div>
                </div>
              </div>
              <p className="rule-note-text">{selectedLetter.sofitInfo.rule}</p>
              <div
                className="sofit-example-chip"
                onClick={() =>
                  handleSpeak(
                    selectedLetter.sofitInfo!.exampleWord.hebrew,
                    selectedLetter.sofitInfo!.exampleWord.transliteration
                  )
                }
              >
                <Volume2 size={14} />
                <span className="ex-heb" dir="rtl">
                  {selectedLetter.sofitInfo.exampleWord.hebrew}
                </span>
                <code>{selectedLetter.sofitInfo.exampleWord.transliteration}</code>
                <span>— {selectedLetter.sofitInfo.exampleWord.meaning}</span>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Examples + Stroke Order Pad */}
      <div className="detail-bottom-grid">
        <div className="detail-left-stack">
          <div className="detail-section-card" ref={examplesRef} tabIndex={-1}>
            <h3 className="section-title">
              <BookOpen size={16} />
              <span>代表词汇与 Niqqud 元音拼读示例</span>
            </h3>
            <div className="examples-list">
              {selectedLetter.examples.map((ex, idx) => (
                <div
                  key={idx}
                  role="button"
                  tabIndex={0}
                  className="example-word-card"
                  onClick={() => handleSpeak(ex.hebrew, ex.transliteration)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      handleSpeak(ex.hebrew, ex.transliteration);
                    }
                  }}
                >
                  <div className="ex-left">
                    <span className="ex-hebrew-word" dir="rtl">
                      {ex.hebrew}
                    </span>
                    <button
                      type="button"
                      className="card-mini-icon-btn"
                      aria-label={`朗读 ${ex.transliteration}`}
                    >
                      <Volume2 size={14} />
                    </button>
                  </div>
                  <div className="ex-right">
                    <div className="ex-translit-row">
                      <code>{ex.transliteration}</code>
                      <strong>{ex.meaning}</strong>
                    </div>
                    {ex.note && <span className="ex-note">{ex.note}</span>}
                  </div>
                </div>
              ))}
            </div>
          </div>

          {confusableLetters.length > 0 && (
            <div className="detail-section-card">
              <h3 className="section-title">
                <AlertTriangle size={16} />
                <span>易混淆字母快速跳转对比</span>
              </h3>
              <div className="confusable-chips-row">
                {confusableLetters.map((other) => (
                  <button
                    key={other.id}
                    type="button"
                    className="confusable-jump-chip"
                    onClick={() => onSelectLetter(other.id)}
                  >
                    <span className="jump-glyph" dir="rtl">
                      {other.hebrew}
                    </span>
                    <div className="jump-meta">
                      <strong>{other.nameEnglish}</strong>
                      <span>
                        {other.nameChinese} · {other.modernIpa}
                      </span>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}
        </div>

        <div ref={writingRef} tabIndex={-1}>
          <StrokeOrderPad letter={selectedLetter} />
        </div>
      </div>
    </div>
  );
};
