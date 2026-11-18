import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  ArrowDown,
  ArrowUp,
  ArrowUpDown,
  BookOpen,
  CheckCircle2,
  ChevronLeft,
  ChevronRight,
  Circle,
  Clock,
  Eye,
  EyeOff,
  HelpCircle,
  LayoutGrid,
  Layers,
  Search,
  Sparkles,
  Volume2,
} from 'lucide-react';
import {
  HebrewLetter,
  HebrewWord,
  MasteryLevel,
  WordCategory,
} from '../types/hebrew';
import { WORD_CATEGORY_META } from '../data/hebrewWords';
import { playFeedbackTone, speakHebrew } from '../utils/audio';

interface WordsStudyViewProps {
  words: HebrewWord[];
  letters: HebrewLetter[];
  wordMasteryMap: Record<string, MasteryLevel>;
  onSetWordMastery: (wordId: string, level: MasteryLevel) => void;
  onOpenLetterDetail: (letterId: string) => void;
  speechRate: number;
}

type WordFilter = 'all' | 'needs_review' | WordCategory;
type WordsMode = 'browse' | 'cards' | 'quiz';
type WordQuizKind = 'meaning' | 'listening';
type WordSortOrder = 'default' | 'alpha';

const ROW_HEIGHT = 72;
const ROW_GAP = 6;
const ROW_STRIDE = ROW_HEIGHT + ROW_GAP;
const OVERSCAN = 6;
const CARDS_PAGE_SIZE = 24;

const MASTERY_OPTIONS: { level: MasteryLevel; label: string; icon: React.ReactNode }[] = [
  { level: 'unlearned', label: '未学', icon: <Circle size={14} /> },
  { level: 'learning', label: '学习中', icon: <Clock size={14} /> },
  { level: 'mastered', label: '已掌握', icon: <CheckCircle2 size={14} /> },
];

const SOFIT_TO_MEDIAL: Record<string, string> = {
  'ך': 'כ',
  'ם': 'מ',
  'ן': 'נ',
  'ף': 'פ',
  'ץ': 'צ',
};

function getInitialHebrewChar(word: HebrewWord): string {
  for (const ch of Array.from(word.hebrewUnpointed)) {
    if (/[\u05D0-\u05EA]/.test(ch)) {
      return SOFIT_TO_MEDIAL[ch] ?? ch;
    }
  }
  return '';
}

interface BreakdownChar {
  char: string;
  isSofit: boolean;
  letter?: HebrewLetter;
}

function buildLetterBreakdown(hebrewText: string, letters: HebrewLetter[]): BreakdownChar[] {
  const result: BreakdownChar[] = [];
  for (const ch of Array.from(hebrewText)) {
    if (!/[\u05D0-\u05EA]/.test(ch)) continue;
    const matched = letters.find((l) => l.hebrew === ch || l.sofit === ch);
    result.push({
      char: ch,
      isSofit: Boolean(matched && matched.sofit === ch),
      letter: matched,
    });
  }
  return result;
}

function pickQuizOptions(target: HebrewWord, pool: HebrewWord[]): HebrewWord[] {
  const distractors = pool
    .filter((w) => w.id !== target.id)
    .sort(() => Math.random() - 0.5)
    .slice(0, 3);
  return [target, ...distractors].sort(() => Math.random() - 0.5);
}

export const WordsStudyView: React.FC<WordsStudyViewProps> = ({
  words,
  letters,
  wordMasteryMap,
  onSetWordMastery,
  onOpenLetterDetail,
  speechRate,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilter, setActiveFilter] = useState<WordFilter>('all');
  const [initialLetter, setInitialLetter] = useState<string>('all');
  const [sortOrder, setSortOrder] = useState<WordSortOrder>('default');
  const [showNiqqud, setShowNiqqud] = useState(true);
  const [showCursive, setShowCursive] = useState(true);
  const [mode, setMode] = useState<WordsMode>('browse');
  const [selectedWordId, setSelectedWordId] = useState<string>(words[0]?.id ?? '');
  const [cardsPage, setCardsPage] = useState(1);

  // Virtual list state
  const listScrollRef = useRef<HTMLDivElement | null>(null);
  const [scrollTop, setScrollTop] = useState(0);
  const [viewportHeight, setViewportHeight] = useState(520);

  // Quiz state
  const [quizKind, setQuizKind] = useState<WordQuizKind>('meaning');
  const [quizTargetId, setQuizTargetId] = useState<string>(words[0]?.id ?? '');
  const [quizOptions, setQuizOptions] = useState<HebrewWord[]>(() =>
    words.length >= 4 ? pickQuizOptions(words[0], words) : words
  );
  const [selectedOptionId, setSelectedOptionId] = useState<string | null>(null);
  const [quizScore, setQuizScore] = useState({ correct: 0, total: 0 });

  const categoryCounts = useMemo(() => {
    const counts: Record<string, number> = {};
    for (const w of words) {
      counts[w.category] = (counts[w.category] ?? 0) + 1;
    }
    return counts;
  }, [words]);

  const filteredWords = useMemo(() => {
    const q = searchQuery.trim().toLowerCase();
    const list = words.filter((word) => {
      const mastery = wordMasteryMap[word.id] ?? 'unlearned';
      if (activeFilter === 'needs_review' && mastery === 'mastered') return false;
      if (
        activeFilter !== 'all' &&
        activeFilter !== 'needs_review' &&
        word.category !== activeFilter
      ) {
        return false;
      }
      if (initialLetter !== 'all' && getInitialHebrewChar(word) !== initialLetter) {
        return false;
      }

      if (!q) return true;
      return (
        word.hebrew.includes(q) ||
        word.hebrewUnpointed.includes(q) ||
        word.transliteration.toLowerCase().includes(q) ||
        word.meaningZh.toLowerCase().includes(q) ||
        (word.root && word.root.includes(q))
      );
    });

    if (sortOrder === 'alpha') {
      return [...list].sort((a, b) =>
        a.hebrewUnpointed.localeCompare(b.hebrewUnpointed, 'he')
      );
    }
    return list;
  }, [words, activeFilter, initialLetter, searchQuery, wordMasteryMap, sortOrder]);

  useEffect(() => {
    setCardsPage(1);
    setScrollTop(0);
    if (listScrollRef.current) {
      listScrollRef.current.scrollTop = 0;
    }
  }, [activeFilter, initialLetter, searchQuery, sortOrder]);

  useEffect(() => {
    const el = listScrollRef.current;
    if (!el) return;
    const updateSize = () => setViewportHeight(el.clientHeight || 520);
    updateSize();
    const observer = new ResizeObserver(updateSize);
    observer.observe(el);
    return () => observer.disconnect();
  }, [mode, filteredWords.length]);

  const selectedWord = useMemo(() => {
    const inFiltered = filteredWords.find((w) => w.id === selectedWordId);
    if (inFiltered) return inFiltered;
    return filteredWords[0] ?? words.find((w) => w.id === selectedWordId) ?? words[0];
  }, [filteredWords, selectedWordId, words]);

  const masteredWordsCount = useMemo(
    () => words.filter((w) => wordMasteryMap[w.id] === 'mastered').length,
    [words, wordMasteryMap]
  );

  const selectedIndex = filteredWords.findIndex((w) => w.id === selectedWord?.id);

  function selectAndScrollToIndex(idx: number) {
    if (filteredWords.length === 0) return;
    const safeIdx = Math.max(0, Math.min(filteredWords.length - 1, idx));
    setSelectedWordId(filteredWords[safeIdx].id);
    const el = listScrollRef.current;
    if (!el) return;
    const itemTop = safeIdx * ROW_STRIDE;
    const itemBottom = itemTop + ROW_HEIGHT;
    if (itemTop < el.scrollTop) {
      el.scrollTop = itemTop;
    } else if (itemBottom > el.scrollTop + el.clientHeight) {
      el.scrollTop = itemBottom - el.clientHeight;
    }
  }

  useEffect(() => {
    if (mode !== 'browse' || filteredWords.length === 0) return;
    function handleKeyDown(e: KeyboardEvent) {
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      ) {
        return;
      }
      if (e.key === 'ArrowDown') {
        e.preventDefault();
        const nextIdx = selectedIndex < filteredWords.length - 1 ? selectedIndex + 1 : 0;
        selectAndScrollToIndex(nextIdx);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        const prevIdx = selectedIndex > 0 ? selectedIndex - 1 : filteredWords.length - 1;
        selectAndScrollToIndex(prevIdx);
      }
    }
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  });

  const breakdown = useMemo(
    () => (selectedWord ? buildLetterBreakdown(selectedWord.hebrewUnpointed, letters) : []),
    [selectedWord, letters]
  );

  // Virtual window calculation
  const totalHeight = filteredWords.length * ROW_STRIDE;
  const startIndex = Math.max(0, Math.floor(scrollTop / ROW_STRIDE) - OVERSCAN);
  const endIndex = Math.min(
    filteredWords.length,
    Math.ceil((scrollTop + viewportHeight) / ROW_STRIDE) + OVERSCAN
  );
  const visibleSlice = filteredWords.slice(startIndex, endIndex);

  // Pagination for Cards Wall
  const totalPages = Math.max(1, Math.ceil(filteredWords.length / CARDS_PAGE_SIZE));
  const safePage = Math.min(cardsPage, totalPages);
  const pagedCards = filteredWords.slice(
    (safePage - 1) * CARDS_PAGE_SIZE,
    safePage * CARDS_PAGE_SIZE
  );

  const quizTarget = useMemo(
    () => words.find((w) => w.id === quizTargetId) ?? words[0],
    [words, quizTargetId]
  );

  function loadNextQuiz(pool: HebrewWord[] = filteredWords.length >= 4 ? filteredWords : words) {
    const next = pool[Math.floor(Math.random() * pool.length)];
    setQuizTargetId(next.id);
    setQuizOptions(pickQuizOptions(next, words));
    setSelectedOptionId(null);
    if (quizKind === 'listening') {
      speakHebrew(next.hebrew, next.transliteration, speechRate);
    }
  }

  function handleAnswerQuiz(optionId: string) {
    if (selectedOptionId) return;
    setSelectedOptionId(optionId);
    const isCorrect = optionId === quizTarget.id;
    playFeedbackTone(isCorrect ? 'correct' : 'wrong');
    setQuizScore((prev) => ({
      correct: prev.correct + (isCorrect ? 1 : 0),
      total: prev.total + 1,
    }));
  }

  function handleCycleMastery(wordId: string) {
    const curr = wordMasteryMap[wordId] ?? 'unlearned';
    const next: MasteryLevel =
      curr === 'unlearned' ? 'learning' : curr === 'learning' ? 'mastered' : 'unlearned';
    onSetWordMastery(wordId, next);
  }

  return (
    <div className="view-container words-view">
      {/* Top Toolbar */}
      <div className="toolbar-card">
        <div className="toolbar-top-row">
          <div className="search-box">
            <Search size={15} />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder={`搜索 ${words.length} 个词库（希伯来语 / 中文释义 / 转写 / 词根）...`}
            />
          </div>

          <div className="toolbar-right-controls">
            <button
              type="button"
              className={`btn-secondary btn-sm ${sortOrder === 'alpha' ? 'active-btn' : ''}`}
              onClick={() => setSortOrder((s) => (s === 'default' ? 'alpha' : 'default'))}
              title="切换排序方式"
            >
              <ArrowUpDown size={14} />
              <span>{sortOrder === 'alpha' ? '按 א-ת 排序' : '按主题排序'}</span>
            </button>

            <button
              type="button"
              className={`btn-secondary btn-sm ${showNiqqud ? 'active-btn' : ''}`}
              onClick={() => setShowNiqqud((v) => !v)}
              title="切换是否显示元音符号 (Niqqud)"
            >
              {showNiqqud ? <Eye size={14} /> : <EyeOff size={14} />}
              <span>{showNiqqud ? '元音点' : '无点拼写'}</span>
            </button>

            <button
              type="button"
              className={`btn-secondary btn-sm ${showCursive ? 'active-btn' : ''}`}
              onClick={() => setShowCursive((v) => !v)}
            >
              <Sparkles size={14} />
              <span>手写体</span>
            </button>

            <div className="segmented-control">
              <button
                type="button"
                className={mode === 'browse' ? 'active' : ''}
                onClick={() => setMode('browse')}
              >
                <BookOpen size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                工作台 ({masteredWordsCount}/{words.length})
              </button>
              <button
                type="button"
                className={mode === 'cards' ? 'active' : ''}
                onClick={() => setMode('cards')}
              >
                <LayoutGrid size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                卡片墙
              </button>
              <button
                type="button"
                className={mode === 'quiz' ? 'active' : ''}
                onClick={() => {
                  setMode('quiz');
                  loadNextQuiz();
                }}
              >
                <HelpCircle size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
                自测
              </button>
            </div>
          </div>
        </div>

        {/* Category filter pills */}
        <div className="filter-pills-row">
          <button
            type="button"
            className={`filter-pill ${activeFilter === 'all' ? 'active' : ''}`}
            onClick={() => setActiveFilter('all')}
          >
            全部 ({words.length})
          </button>
          {(Object.keys(WORD_CATEGORY_META) as WordCategory[]).map((cat) => (
            <button
              key={cat}
              type="button"
              className={`filter-pill ${activeFilter === cat ? 'active' : ''}`}
              onClick={() => setActiveFilter(cat)}
            >
              {WORD_CATEGORY_META[cat].label} ({categoryCounts[cat] ?? 0})
            </button>
          ))}
          <button
            type="button"
            className={`filter-pill ${activeFilter === 'needs_review' ? 'active' : ''}`}
            onClick={() => setActiveFilter('needs_review')}
          >
            待掌握
          </button>
        </div>

        {/* Alef-Bet Initial Letter Jump Strip */}
        {mode !== 'quiz' && (
          <div className="alefbet-jump-row" aria-label="按希伯来首字母筛选">
            <span className="muted-caption" style={{ flexShrink: 0 }}>
              首字母索引：
            </span>
            <button
              type="button"
              className={`initial-chip ${initialLetter === 'all' ? 'active' : ''}`}
              onClick={() => setInitialLetter('all')}
            >
              全部
            </button>
            <div className="initial-chips-scroll" dir="rtl">
              {letters.map((l) => (
                <button
                  key={l.id}
                  type="button"
                  className={`initial-chip hebrew-init ${initialLetter === l.hebrew ? 'active' : ''}`}
                  onClick={() =>
                    setInitialLetter((prev) => (prev === l.hebrew ? 'all' : l.hebrew))
                  }
                  title={`筛选以 ${l.hebrew} (${l.nameEnglish}) 开头的单词`}
                >
                  {l.hebrew}
                </button>
              ))}
            </div>
          </div>
        )}
      </div>

      {mode === 'browse' ? (
        filteredWords.length === 0 ? (
          <div className="empty-state">
            <p>没有匹配当前条件的希伯来语单词。</p>
            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={() => {
                setSearchQuery('');
                setActiveFilter('all');
                setInitialLetter('all');
              }}
            >
              重置筛选条件
            </button>
          </div>
        ) : (
          <div className="words-workbench">
            {/* Left Virtualized Word List */}
            <aside className="words-list-pane" aria-label="单词列表">
              <div className="words-list-header">
                <span>匹配 {filteredWords.length} 个单词</span>
                <span className="muted-caption">↑ / ↓ 切换</span>
              </div>
              <div
                ref={listScrollRef}
                className="words-list-scroll virtual-scroll"
                onScroll={(e) => setScrollTop(e.currentTarget.scrollTop)}
              >
                <div
                  className="virtual-spacer"
                  style={{ height: Math.max(ROW_HEIGHT, totalHeight), position: 'relative' }}
                >
                  {visibleSlice.map((word, offsetIdx) => {
                    const actualIdx = startIndex + offsetIdx;
                    const mastery = wordMasteryMap[word.id] ?? 'unlearned';
                    const isActive = word.id === selectedWord?.id;
                    return (
                      <div
                        key={word.id}
                        role="button"
                        tabIndex={0}
                        className={`word-list-item virtual-row ${isActive ? 'active' : ''}`}
                        style={{
                          position: 'absolute',
                          top: actualIdx * ROW_STRIDE,
                          left: 0,
                          right: 0,
                          height: ROW_HEIGHT,
                        }}
                        onClick={() => setSelectedWordId(word.id)}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' || e.key === ' ') {
                            e.preventDefault();
                            setSelectedWordId(word.id);
                          }
                        }}
                      >
                        <div className="word-item-main">
                          <div className="word-item-hebrew" dir="rtl">
                            {showNiqqud ? word.hebrew : word.hebrewUnpointed}
                          </div>
                          <div className="word-item-meta">
                            <span className="word-item-zh">{word.meaningZh}</span>
                            <span className="word-item-translit">{word.transliteration}</span>
                          </div>
                        </div>
                        <div className="word-item-actions">
                          <button
                            type="button"
                            className="card-mini-icon-btn"
                            title="朗读单词"
                            onClick={(e) => {
                              e.stopPropagation();
                              speakHebrew(word.hebrew, word.transliteration, speechRate);
                            }}
                          >
                            <Volume2 size={13} />
                          </button>
                          <button
                            type="button"
                            className={`word-mastery-dot m-${mastery}`}
                            title="点击切换熟练度"
                            onClick={(e) => {
                              e.stopPropagation();
                              handleCycleMastery(word.id);
                            }}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </div>
            </aside>

            {/* Right Detail Workspace */}
            {selectedWord && (
              <section className="word-detail-pane">
                <div className="word-detail-header">
                  <div className="word-badges-row">
                    <span className="meta-badge gematria">
                      {WORD_CATEGORY_META[selectedWord.category].label}
                    </span>
                    <span className="meta-badge">{selectedWord.partOfSpeech}</span>
                    <span className="meta-badge">{selectedWord.grammarTag}</span>
                    {selectedWord.root && (
                      <span className="meta-badge root-badge" dir="rtl">
                        词根: {selectedWord.root}
                      </span>
                    )}
                  </div>

                  <div className="word-nav-arrows">
                    <span className="muted-caption">
                      {selectedIndex + 1} / {filteredWords.length}
                    </span>
                    <button
                      type="button"
                      className="btn-secondary btn-sm"
                      onClick={() => {
                        const prevIdx =
                          selectedIndex > 0 ? selectedIndex - 1 : filteredWords.length - 1;
                        selectAndScrollToIndex(prevIdx);
                      }}
                      title="上一个单词 (↑)"
                    >
                      <ArrowUp size={14} />
                      <span>上一词</span>
                    </button>
                    <button
                      type="button"
                      className="btn-secondary btn-sm"
                      onClick={() => {
                        const nextIdx =
                          selectedIndex < filteredWords.length - 1 ? selectedIndex + 1 : 0;
                        selectAndScrollToIndex(nextIdx);
                      }}
                      title="下一个单词 (↓)"
                    >
                      <span>下一词</span>
                      <ArrowDown size={14} />
                    </button>
                  </div>
                </div>

                {/* Big Display Stage */}
                <div className={`word-glyph-stage ${showCursive ? 'two-col' : ''}`}>
                  <div className="word-stage-card">
                    <span className="stage-label">
                      印刷体 {showNiqqud ? '(带元音点 Niqqud)' : '(日常无元音点)'}
                    </span>
                    <div className="word-hero-block" dir="rtl">
                      {showNiqqud ? selectedWord.hebrew : selectedWord.hebrewUnpointed}
                    </div>
                    {!showNiqqud && (
                      <span className="muted-caption" dir="rtl">
                        带点参考：{selectedWord.hebrew}
                      </span>
                    )}
                  </div>

                  {showCursive && (
                    <div className="word-stage-card">
                      <span className="stage-label">现代手写体 (Ktav)</span>
                      <div className="word-hero-cursive" dir="rtl">
                        {selectedWord.hebrewUnpointed}
                      </div>
                      <span className="muted-caption">手写日常通常省略元音点</span>
                    </div>
                  )}
                </div>

                {/* Meaning + Pronunciation + Mastery */}
                <div className="word-meaning-bar">
                  <div className="word-meaning-text">
                    <h2>{selectedWord.meaningZh}</h2>
                    <div className="word-phonetics-row">
                      <span>
                        转写：<strong>{selectedWord.transliteration}</strong>
                      </span>
                      <span className="ipa-chip">{selectedWord.ipa}</span>
                    </div>
                  </div>

                  <div className="word-cta-group">
                    <button
                      type="button"
                      className="btn-primary"
                      onClick={() =>
                        speakHebrew(selectedWord.hebrew, selectedWord.transliteration, speechRate)
                      }
                    >
                      <Volume2 size={16} />
                      <span>朗读单词</span>
                    </button>

                    <div className="mastery-segmented">
                      {MASTERY_OPTIONS.map((opt) => {
                        const active =
                          (wordMasteryMap[selectedWord.id] ?? 'unlearned') === opt.level;
                        return (
                          <button
                            key={opt.level}
                            type="button"
                            className={`${active ? 'active' : ''} m-${opt.level}`}
                            onClick={() => onSetWordMastery(selectedWord.id, opt.level)}
                          >
                            {opt.icon}
                            <span>{opt.label}</span>
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>

                {/* Letter-by-letter breakdown */}
                <div className="word-section-box">
                  <div className="word-section-header">
                    <h4>逐字母拆解（从右向左拼读，点击字母可查看笔顺）</h4>
                    <span className="muted-caption">共 {breakdown.length} 个辅音字母</span>
                  </div>
                  <div className="word-breakdown-strip" dir="rtl">
                    {breakdown.map((item, idx) => (
                      <button
                        key={`${item.char}-${idx}`}
                        type="button"
                        className="breakdown-letter-chip"
                        dir="ltr"
                        disabled={!item.letter}
                        onClick={() => item.letter && onOpenLetterDetail(item.letter.id)}
                        title={
                          item.letter
                            ? `点击查看 ${item.letter.nameEnglish} (${item.letter.nameChinese}) 的笔顺与发音`
                            : undefined
                        }
                      >
                        <span className="breakdown-char" dir="rtl">
                          {item.char}
                        </span>
                        <span className="breakdown-name">
                          {item.letter ? item.letter.nameEnglish : ''}
                        </span>
                        {item.isSofit && <span className="breakdown-sofit-tag">词尾</span>}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Grammar / Reading Note */}
                <div className="word-section-box">
                  <h4>拼读与词根解析</h4>
                  <p className="word-note-text">{selectedWord.note}</p>
                </div>

                {/* Optional Example Sentence */}
                {selectedWord.sentence && (
                  <div className="word-section-box word-sentence-box">
                    <div className="word-section-header">
                      <h4>实用例句</h4>
                      <button
                        type="button"
                        className="btn-secondary btn-sm"
                        onClick={() =>
                          speakHebrew(
                            selectedWord.sentence!.hebrew,
                            selectedWord.sentence!.transliteration,
                            speechRate
                          )
                        }
                      >
                        <Volume2 size={14} />
                        <span>朗读例句</span>
                      </button>
                    </div>
                    <div className="sentence-hebrew" dir="rtl">
                      {selectedWord.sentence.hebrew}
                    </div>
                    <div className="sentence-translit">
                      {selectedWord.sentence.transliteration}
                    </div>
                    <div className="sentence-zh">{selectedWord.sentence.meaningZh}</div>
                  </div>
                )}
              </section>
            )}
          </div>
        )
      ) : mode === 'cards' ? (
        /* Paginated Cards Wall Mode */
        filteredWords.length === 0 ? (
          <div className="empty-state">
            <p>没有匹配当前条件的希伯来语单词。</p>
          </div>
        ) : (
          <div className="words-cards-wall-wrapper">
            <div className="words-pagination-bar">
              <span className="muted-caption">
                共 {filteredWords.length} 个单词 · 第 {safePage} / {totalPages} 页
              </span>
              <div className="pagination-controls">
                <button
                  type="button"
                  className="btn-secondary btn-sm"
                  disabled={safePage <= 1}
                  onClick={() => setCardsPage((p) => Math.max(1, p - 1))}
                >
                  <ChevronLeft size={14} />
                  <span>上一页</span>
                </button>
                <button
                  type="button"
                  className="btn-secondary btn-sm"
                  disabled={safePage >= totalPages}
                  onClick={() => setCardsPage((p) => Math.min(totalPages, p + 1))}
                >
                  <span>下一页</span>
                  <ChevronRight size={14} />
                </button>
              </div>
            </div>

            <div className="words-cards-wall">
              {pagedCards.map((word) => {
                const mastery = wordMasteryMap[word.id] ?? 'unlearned';
                return (
                  <div
                    key={word.id}
                    role="button"
                    tabIndex={0}
                    className={`word-wall-card m-${mastery}`}
                    onClick={() => {
                      setSelectedWordId(word.id);
                      setMode('browse');
                    }}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter' || e.key === ' ') {
                        e.preventDefault();
                        setSelectedWordId(word.id);
                        setMode('browse');
                      }
                    }}
                  >
                    <div className="word-wall-top">
                      <span className="meta-badge">
                        {WORD_CATEGORY_META[word.category].badge}
                      </span>
                      <div className="word-item-actions">
                        <button
                          type="button"
                          className="card-mini-icon-btn"
                          title="朗读单词"
                          onClick={(e) => {
                            e.stopPropagation();
                            speakHebrew(word.hebrew, word.transliteration, speechRate);
                          }}
                        >
                          <Volume2 size={13} />
                        </button>
                        <button
                          type="button"
                          className={`word-mastery-dot m-${mastery}`}
                          title="切换熟练度"
                          onClick={(e) => {
                            e.stopPropagation();
                            handleCycleMastery(word.id);
                          }}
                        />
                      </div>
                    </div>

                    <div className="word-wall-glyphs">
                      <span className="word-wall-hebrew" dir="rtl">
                        {showNiqqud ? word.hebrew : word.hebrewUnpointed}
                      </span>
                      {showCursive && (
                        <span className="word-wall-cursive" dir="rtl">
                          {word.hebrewUnpointed}
                        </span>
                      )}
                    </div>

                    <div className="word-wall-meaning">{word.meaningZh}</div>
                    <div className="word-wall-phonetics">
                      <span>{word.transliteration}</span>
                      <span>{word.ipa}</span>
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        )
      ) : (
        /* Word Quiz Mode */
        <div className="quiz-stage">
          <div className="quiz-card">
            <div className="quiz-prompt-header">
              <div className="segmented-control">
                <button
                  type="button"
                  className={quizKind === 'meaning' ? 'active' : ''}
                  onClick={() => setQuizKind('meaning')}
                >
                  看词选义
                </button>
                <button
                  type="button"
                  className={quizKind === 'listening' ? 'active' : ''}
                  onClick={() => {
                    setQuizKind('listening');
                    speakHebrew(quizTarget.hebrew, quizTarget.transliteration, speechRate);
                  }}
                >
                  听音辨词
                </button>
              </div>

              <div className="quiz-score-badge">
                <Layers size={14} />
                <span>
                  得分 {quizScore.correct} / {quizScore.total}
                </span>
              </div>
            </div>

            <div className="quiz-stimulus-box word-quiz-stimulus">
              {quizKind === 'meaning' ? (
                <div className="word-quiz-prompt">
                  <span className="quiz-big-hebrew" dir="rtl">
                    {showNiqqud ? quizTarget.hebrew : quizTarget.hebrewUnpointed}
                  </span>
                  <button
                    type="button"
                    className="btn-secondary btn-sm"
                    onClick={() =>
                      speakHebrew(quizTarget.hebrew, quizTarget.transliteration, speechRate)
                    }
                  >
                    <Volume2 size={14} />
                    <span>朗读</span>
                  </button>
                </div>
              ) : (
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() =>
                    speakHebrew(quizTarget.hebrew, quizTarget.transliteration, speechRate)
                  }
                >
                  <Volume2 size={18} />
                  <span>播放单词发音</span>
                </button>
              )}
            </div>

            <div className="quiz-options-grid">
              {quizOptions.map((opt) => {
                const isPicked = selectedOptionId === opt.id;
                const isRight = opt.id === quizTarget.id;
                let cls = 'quiz-option-btn';
                if (selectedOptionId) {
                  if (isRight) cls += ' correct';
                  else if (isPicked) cls += ' wrong';
                  else cls += ' dimmed';
                }
                return (
                  <button
                    key={opt.id}
                    type="button"
                    className={cls}
                    onClick={() => handleAnswerQuiz(opt.id)}
                  >
                    <span className="opt-main">
                      {quizKind === 'listening' ? opt.hebrew : opt.meaningZh}
                    </span>
                    <span className="opt-sub">
                      {quizKind === 'listening'
                        ? `${opt.transliteration} · ${opt.meaningZh}`
                        : opt.transliteration}
                    </span>
                  </button>
                );
              })}
            </div>

            {selectedOptionId && (
              <div
                className={`quiz-feedback-box ${
                  selectedOptionId === quizTarget.id ? 'correct' : 'wrong'
                }`}
              >
                <div className="feedback-text">
                  <strong>
                    {selectedOptionId === quizTarget.id ? '回答正确！' : '再记一下：'}
                  </strong>
                  <span>
                    {quizTarget.hebrew} ({quizTarget.transliteration}) — {quizTarget.meaningZh}
                  </span>
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button
                    type="button"
                    className="btn-secondary btn-sm"
                    onClick={() =>
                      onSetWordMastery(
                        quizTarget.id,
                        selectedOptionId === quizTarget.id ? 'mastered' : 'learning'
                      )
                    }
                  >
                    {selectedOptionId === quizTarget.id ? '标为已掌握' : '加入学习中'}
                  </button>
                  <button
                    type="button"
                    className="btn-primary btn-sm"
                    onClick={() => loadNextQuiz()}
                  >
                    下一题
                  </button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
