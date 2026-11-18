import React, { useMemo, useState } from 'react';
import {
  ArrowLeftRight,
  CheckCircle2,
  Circle,
  Clock,
  Filter,
  Search,
  SlidersHorizontal,
  Volume2,
} from 'lucide-react';
import {
  AlphabetOrder,
  CustomDisplayConfig,
  GridFilter,
  HebrewLetter,
  MasteryLevel,
} from '../types/hebrew';
import { HebrewGlyphSvg } from './HebrewGlyphSvg';
import { speakHebrew } from '../utils/audio';

interface AlphabetGridViewProps {
  letters: HebrewLetter[];
  displayConfig: CustomDisplayConfig;
  onUpdateDisplayConfig: (next: CustomDisplayConfig) => void;
  order: AlphabetOrder;
  onToggleOrder: () => void;
  masteryMap: Record<string, MasteryLevel>;
  onCycleMastery: (letterId: string) => void;
  onSelectLetter: (letterId: string) => void;
  speechRate: number;
  onChangeSpeechRate: (rate: number) => void;
}

const DISPLAY_PRESETS: {
  id: string;
  label: string;
  config: CustomDisplayConfig;
}[] = [
  {
    id: 'beginner',
    label: '初学者精简',
    config: {
      showBlock: true,
      showCursive: false,
      showSofit: true,
      showBegadkefat: true,
      showHebrewName: true,
      showEnglishName: true,
      showChineseName: true,
      showModernSound: true,
      showBiblicalDiff: false,
      showTransliteration: true,
      showGematria: false,
      showMastery: true,
      showCategoryBadges: false,
    },
  },
  {
    id: 'writing',
    label: '手写与词尾专练',
    config: {
      showBlock: true,
      showCursive: true,
      showSofit: true,
      showBegadkefat: true,
      showHebrewName: false,
      showEnglishName: true,
      showChineseName: false,
      showModernSound: true,
      showBiblicalDiff: false,
      showTransliteration: false,
      showGematria: false,
      showMastery: true,
      showCategoryBadges: true,
    },
  },
  {
    id: 'scholar',
    label: '现代+圣经全属性',
    config: {
      showBlock: true,
      showCursive: true,
      showSofit: true,
      showBegadkefat: true,
      showHebrewName: true,
      showEnglishName: true,
      showChineseName: true,
      showModernSound: true,
      showBiblicalDiff: true,
      showTransliteration: true,
      showGematria: true,
      showMastery: true,
      showCategoryBadges: true,
    },
  },
  {
    id: 'quiz_mask',
    label: '遮罩自测',
    config: {
      showBlock: true,
      showCursive: true,
      showSofit: true,
      showBegadkefat: false,
      showHebrewName: false,
      showEnglishName: false,
      showChineseName: false,
      showModernSound: false,
      showBiblicalDiff: false,
      showTransliteration: false,
      showGematria: false,
      showMastery: true,
      showCategoryBadges: false,
    },
  },
];

const CONFIG_TOGGLES: { key: keyof CustomDisplayConfig; label: string }[] = [
  { key: 'showBlock', label: '印刷体' },
  { key: 'showCursive', label: '手写体' },
  { key: 'showSofit', label: '词尾形 Sofit' },
  { key: 'showBegadkefat', label: 'Dagesh 音变' },
  { key: 'showHebrewName', label: '希伯来名' },
  { key: 'showChineseName', label: '中文名' },
  { key: 'showEnglishName', label: '英文名' },
  { key: 'showModernSound', label: '现代读音 & IPA' },
  { key: 'showBiblicalDiff', label: '圣经古典发音' },
  { key: 'showTransliteration', label: '拉丁转写' },
  { key: 'showGematria', label: 'Gematria 数值' },
  { key: 'showCategoryBadges', label: '属性标签' },
  { key: 'showMastery', label: '熟练度标记' },
];

const FILTER_OPTIONS: { id: GridFilter; label: string }[] = [
  { id: 'all', label: '全部 22 字母' },
  { id: 'sofit', label: '词尾变形 (5)' },
  { id: 'begadkefat', label: 'Dagesh 音变 (6)' },
  { id: 'guttural', label: '喉音字母 (5)' },
  { id: 'confusable', label: '易混淆对比' },
  { id: 'needs_review', label: '待掌握' },
];

const MASTERY_META: Record<MasteryLevel, { label: string; className: string }> = {
  unlearned: { label: '未学', className: 'mastery-unlearned' },
  learning: { label: '学习中', className: 'mastery-learning' },
  mastered: { label: '已掌握', className: 'mastery-mastered' },
};

function renderMasteryIcon(level: MasteryLevel) {
  if (level === 'mastered') return <CheckCircle2 size={14} />;
  if (level === 'learning') return <Clock size={14} />;
  return <Circle size={14} />;
}

export const AlphabetGridView: React.FC<AlphabetGridViewProps> = ({
  letters,
  displayConfig,
  onUpdateDisplayConfig,
  order,
  onToggleOrder,
  masteryMap,
  onCycleMastery,
  onSelectLetter,
  speechRate,
  onChangeSpeechRate,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<GridFilter>('all');
  const [showCustomPanel, setShowCustomPanel] = useState(true);

  const filteredLetters = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    return letters.filter((letter) => {
      const mastery = masteryMap[letter.id] ?? 'unlearned';
      if (activeFilter === 'sofit' && !letter.sofit) return false;
      if (activeFilter === 'begadkefat' && !letter.begadkefat) return false;
      if (activeFilter === 'guttural' && !letter.categories.includes('guttural')) return false;
      if (activeFilter === 'confusable' && letter.confusableWith.length === 0) return false;
      if (activeFilter === 'needs_review' && mastery === 'mastered') return false;

      if (!q) return true;
      return (
        letter.hebrew.includes(q) ||
        (letter.sofit && letter.sofit.includes(q)) ||
        letter.nameEnglish.toLowerCase().includes(q) ||
        letter.nameChinese.includes(q) ||
        letter.transliteration.toLowerCase().includes(q) ||
        letter.modernSound.toLowerCase().includes(q) ||
        String(letter.gematria) === q
      );
    });
  }, [letters, activeFilter, searchQuery, masteryMap]);

  function toggleConfigField(key: keyof CustomDisplayConfig) {
    const next = { ...displayConfig, [key]: !displayConfig[key] };
    // Prevent hiding both block and cursive simultaneously so cards remain identifiable
    if (!next.showBlock && !next.showCursive) {
      next.showBlock = true;
    }
    onUpdateDisplayConfig(next);
  }

  return (
    <div className="view-container">
      <div className="toolbar-card">
        <div className="toolbar-top-row">
          <div className="search-box">
            <Search size={15} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="搜索字母、中文名、音标、转写或数值 (如: Alef / 10 / ך)..."
            />
          </div>

          <div className="toolbar-right-controls">
            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={onToggleOrder}
              title="切换字母表排列方向"
            >
              <ArrowLeftRight size={14} />
              <span>{order === 'rtl' ? '从右向左 (希伯来习惯)' : '从左向右 (LTR)'}</span>
            </button>

            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={() => onChangeSpeechRate(speechRate === 1 ? 0.75 : 1)}
              title="切换朗读语速"
            >
              <Volume2 size={14} />
              <span>语速 {speechRate}x</span>
            </button>

            <button
              type="button"
              className={`btn-secondary btn-sm ${showCustomPanel ? 'active-btn' : ''}`}
              onClick={() => setShowCustomPanel((v) => !v)}
            >
              <SlidersHorizontal size={14} />
              <span>自定义显示属性</span>
            </button>
          </div>
        </div>

        <div className="filter-pills-row">
          <span className="filter-prefix">
            <Filter size={13} />
            <span>筛选：</span>
          </span>
          {FILTER_OPTIONS.map((opt) => (
            <button
              key={opt.id}
              type="button"
              className={`filter-pill ${activeFilter === opt.id ? 'active' : ''}`}
              onClick={() => setActiveFilter(opt.id)}
            >
              {opt.label}
            </button>
          ))}
        </div>

        {showCustomPanel && (
          <div className="custom-display-panel">
            <div className="preset-row">
              <span className="panel-label">视图模板：</span>
              {DISPLAY_PRESETS.map((preset) => (
                <button
                  key={preset.id}
                  type="button"
                  className="preset-chip"
                  onClick={() => onUpdateDisplayConfig(preset.config)}
                >
                  {preset.label}
                </button>
              ))}
            </div>
            <div className="toggles-grid">
              {CONFIG_TOGGLES.map((item) => {
                const enabled = displayConfig[item.key];
                return (
                  <button
                    key={item.key}
                    type="button"
                    className={`attr-toggle-chip ${enabled ? 'enabled' : ''}`}
                    onClick={() => toggleConfigField(item.key)}
                  >
                    <span className="toggle-dot" />
                    <span>{item.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}
      </div>

      {filteredLetters.length === 0 ? (
        <div className="empty-state">
          <p>没有匹配当前条件的希伯来字母。</p>
          <button
            type="button"
            className="btn-secondary btn-sm"
            onClick={() => {
              setSearchQuery('');
              setActiveFilter('all');
            }}
          >
            重置筛选条件
          </button>
        </div>
      ) : (
        <div
          className="alphabet-grid"
          style={{ direction: order === 'rtl' ? 'rtl' : 'ltr' }}
        >
          {filteredLetters.map((letter) => {
            const mastery = masteryMap[letter.id] ?? 'unlearned';
            const masteryInfo = MASTERY_META[mastery];

            return (
              <div
                key={letter.id}
                role="button"
                tabIndex={0}
                className={`letter-card ${masteryInfo.className}`}
                style={{ direction: 'ltr' }}
                onClick={() => onSelectLetter(letter.id)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    onSelectLetter(letter.id);
                  }
                }}
              >
                <div className="card-top-meta">
                  <span className="order-index">#{letter.order}</span>
                  <div className="card-top-actions">
                    {displayConfig.showGematria && (
                      <span className="gematria-pill" title="Gematria 数值">
                        ={letter.gematria}
                        {letter.sofitInfo ? `/${letter.sofitInfo.sofitGematria}` : ''}
                      </span>
                    )}
                    <button
                      type="button"
                      className="card-mini-icon-btn"
                      title="朗读字母"
                      onClick={(e) => {
                        e.stopPropagation();
                        speakHebrew(letter.nameHebrew, letter.nameEnglish, speechRate);
                      }}
                    >
                      <Volume2 size={14} />
                    </button>
                    {displayConfig.showMastery && (
                      <button
                        type="button"
                        className={`mastery-pill ${masteryInfo.className}`}
                        title="点击切换熟练度"
                        onClick={(e) => {
                          e.stopPropagation();
                          onCycleMastery(letter.id);
                        }}
                      >
                        {renderMasteryIcon(mastery)}
                        <span>{masteryInfo.label}</span>
                      </button>
                    )}
                  </div>
                </div>

                <div className="card-glyph-showcase">
                  {displayConfig.showBlock && (
                    <div className="glyph-block-box">
                      <span className="hebrew-glyph-main" dir="rtl">
                        {letter.hebrew}
                      </span>
                      {displayConfig.showSofit && letter.sofit && (
                        <span
                          className="sofit-corner-badge"
                          title={`词尾形 Sofit: ${letter.sofit}`}
                          dir="rtl"
                        >
                          {letter.sofit}
                        </span>
                      )}
                    </div>
                  )}

                  {displayConfig.showCursive && (
                    <div className="glyph-cursive-box" title="手写体 (标准手写体 Ktav)">
                      <HebrewGlyphSvg
                        strokes={letter.strokeGuide.cursiveStrokes}
                        size={displayConfig.showBlock ? 52 : 68}
                        strokeWidth={6.5}
                      />
                      {displayConfig.showSofit &&
                        letter.strokeGuide.sofitCursiveStrokes && (
                          <div className="sofit-cursive-mini" title="手写体词尾形">
                            <HebrewGlyphSvg
                              strokes={letter.strokeGuide.sofitCursiveStrokes}
                              size={32}
                              strokeWidth={6.5}
                            />
                          </div>
                        )}
                    </div>
                  )}
                </div>

                {(displayConfig.showHebrewName ||
                  displayConfig.showChineseName ||
                  displayConfig.showEnglishName) && (
                  <div className="card-names">
                    {displayConfig.showHebrewName && (
                      <span className="name-hebrew" dir="rtl">
                        {letter.nameHebrew}
                      </span>
                    )}
                    <span className="name-roman-zh">
                      {displayConfig.showEnglishName && <strong>{letter.nameEnglish}</strong>}
                      {displayConfig.showEnglishName && displayConfig.showChineseName && ' · '}
                      {displayConfig.showChineseName && <span>{letter.nameChinese}</span>}
                    </span>
                  </div>
                )}

                {displayConfig.showModernSound && (
                  <div className="card-sound-line">
                    <span className="ipa-tag">{letter.modernIpa}</span>
                    <span className="sound-summary">{letter.modernSound}</span>
                  </div>
                )}

                {displayConfig.showTransliteration && (
                  <div className="card-translit">
                    转写：<code>{letter.transliteration}</code>
                  </div>
                )}

                {displayConfig.showBegadkefat && letter.begadkefat && (
                  <div className="card-dagesh-row" title={letter.begadkefat.note}>
                    <span className="dagesh-chip" dir="rtl">
                      {letter.begadkefat.withDagesh.glyph} {letter.begadkefat.withDagesh.modernIpa}
                    </span>
                    <span className="dagesh-sep">/</span>
                    <span className="dagesh-chip soft" dir="rtl">
                      {letter.begadkefat.withoutDagesh.glyph}{' '}
                      {letter.begadkefat.withoutDagesh.modernIpa}
                    </span>
                  </div>
                )}

                {displayConfig.showBiblicalDiff && (
                  <div className="card-biblical-box">
                    <span className="biblical-badge">圣经 {letter.biblicalIpa}</span>
                    <p>{letter.biblicalDiff}</p>
                  </div>
                )}

                {displayConfig.showCategoryBadges && letter.categories.length > 0 && (
                  <div className="card-category-row">
                    {letter.sofit && <span className="cat-badge cat-sofit">词尾 Sofit</span>}
                    {letter.begadkefat && (
                      <span className="cat-badge cat-dagesh">
                        {letter.begadkefat.modernPreserved ? '现代保留音变' : '古典音变'}
                      </span>
                    )}
                    {letter.categories.includes('guttural') && (
                      <span className="cat-badge cat-guttural">喉音/准喉音</span>
                    )}
                    {letter.categories.includes('mater') && (
                      <span className="cat-badge cat-mater">可表元音</span>
                    )}
                  </div>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
};
