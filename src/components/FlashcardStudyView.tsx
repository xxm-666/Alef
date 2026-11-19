import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  CheckCircle2,
  Clock,
  ExternalLink,
  HelpCircle,
  RefreshCw,
  RotateCcw,
  Shuffle,
  Volume2,
  XCircle,
} from 'lucide-react';
import { HebrewLetter, MasteryLevel } from '../types/hebrew';
import { HebrewGlyphSvg } from './HebrewGlyphSvg';
import { playFeedbackTone, speakHebrew } from '../utils/audio';
import { readStorage, writeStorage } from '../utils/storage';

interface FlashcardStudyViewProps {
  letters: HebrewLetter[];
  masteryMap: Record<string, MasteryLevel>;
  onSetMastery: (letterId: string, level: MasteryLevel) => void;
  onOpenDetail: (letterId: string) => void;
  speechRate: number;
}

type StudySubMode = 'flip' | 'quiz';
type CardFrontType = 'block' | 'cursive' | 'both' | 'sofit';
type DeckScope = 'all' | 'needs_review' | 'sofit' | 'begadkefat';
type QuizType = 'block-to-sound' | 'cursive-to-block' | 'sofit-match' | 'dagesh-quiz';

const CORRECT_ANSWER_DELAY_MS = 700;

interface QuizQuestion {
  promptTitle: string;
  promptHebrew?: string;
  promptCursiveId?: string;
  options: { id: string; label: string; subLabel?: string }[];
  correctId: string;
  explanation: string;
  speakTarget?: { hebrew: string; fallback: string };
}

function shuffleArray<T>(items: T[]): T[] {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
}

function buildQuizQuestion(
  letters: HebrewLetter[],
  quizType: QuizType,
  previousAnswer?: string
): QuizQuestion {
  function pickTarget(pool: HebrewLetter[]) {
    const previousLetterId = quizType === 'dagesh-quiz' ? previousAnswer?.replace(/-(hard|soft)$/, '') : previousAnswer;
    const alternatives = pool.filter((letter) => letter.id !== previousLetterId);
    const candidates = alternatives.length ? alternatives : pool;
    return candidates[Math.floor(Math.random() * candidates.length)];
  }

  if (quizType === 'sofit-match') {
    const sofitPool = letters.filter((l) => Boolean(l.sofit));
    const target = pickTarget(sofitPool);
    const distractors = shuffleArray(sofitPool.filter((l) => l.id !== target.id)).slice(0, 3);
    const options = shuffleArray([target, ...distractors]).map((item) => ({
      id: item.id,
      label: item.sofit!,
      subLabel: `${item.nameEnglish} Sofit`,
    }));
    return {
      promptTitle: `请选择字母「${target.hebrew} (${target.nameEnglish} · ${target.nameChinese})」的词尾形 (Sofit)：`,
      promptHebrew: target.hebrew,
      options,
      correctId: target.id,
      explanation: `${target.hebrew} 在词尾须写作 ${target.sofit}，示例词：${target.sofitInfo?.exampleWord.hebrew} (${target.sofitInfo?.exampleWord.meaning})。`,
      speakTarget: { hebrew: target.nameHebrew, fallback: target.nameEnglish },
    };
  }

  if (quizType === 'dagesh-quiz') {
    const dageshPool = letters.filter((l) => Boolean(l.begadkefat));
    const target = pickTarget(dageshPool);
    const askWithDagesh = Math.random() > 0.5;
    const variant = askWithDagesh
      ? target.begadkefat!.withDagesh
      : target.begadkefat!.withoutDagesh;

    const allVariants = dageshPool.flatMap((item) => [
      {
        id: `${item.id}-hard`,
        label: `${item.begadkefat!.withDagesh.modernIpa}`,
        subLabel: item.begadkefat!.withDagesh.modernSound,
      },
      {
        id: `${item.id}-soft`,
        label: `${item.begadkefat!.withoutDagesh.modernIpa}`,
        subLabel: item.begadkefat!.withoutDagesh.modernSound,
      },
    ]);

    const correctId = `${target.id}-${askWithDagesh ? 'hard' : 'soft'}`;
    const uniqueDistractors = shuffleArray(
      allVariants.filter(
        (v) => v.id !== correctId && v.label !== variant.modernIpa
      )
    ).slice(0, 3);

    const options = shuffleArray([
      {
        id: correctId,
        label: variant.modernIpa,
        subLabel: variant.modernSound,
      },
      ...uniqueDistractors,
    ]);

    return {
      promptTitle: `在现代希伯来语中，这个字形的读音是？（古典圣经音值：${variant.biblicalIpa}）`,
      promptHebrew: variant.glyph,
      options,
      correctId,
      explanation: `${variant.name}：现代 ${variant.modernIpa}，古典 ${variant.biblicalIpa}。${target.begadkefat!.note}`,
      speakTarget: { hebrew: target.nameHebrew, fallback: target.nameEnglish },
    };
  }

  const target = pickTarget(letters);
  const distractors = shuffleArray(letters.filter((l) => l.id !== target.id)).slice(0, 3);

  if (quizType === 'cursive-to-block') {
    return {
      promptTitle: '请选出下方手写体 (Ktav) 对应的印刷体字母：',
      promptCursiveId: target.id,
      options: shuffleArray([target, ...distractors]).map((item) => ({
        id: item.id,
        label: item.hebrew,
        subLabel: `${item.nameEnglish} · ${item.nameChinese}`,
      })),
      correctId: target.id,
      explanation: `手写体对应 ${target.hebrew} (${target.nameEnglish} · ${target.nameChinese})：${target.cursiveDesc}`,
      speakTarget: { hebrew: target.nameHebrew, fallback: target.nameEnglish },
    };
  }

  return {
    promptTitle: '请选出该印刷体字母的正确名称与现代读音：',
    promptHebrew: target.hebrew,
    options: shuffleArray([target, ...distractors]).map((item) => ({
      id: item.id,
      label: `${item.nameEnglish} (${item.nameChinese})`,
      subLabel: `${item.modernIpa} · ${item.modernSound}`,
    })),
    correctId: target.id,
    explanation: `${target.hebrew} (${target.nameHebrew}) 读作 ${target.modernIpa} — ${target.modernSound}。`,
    speakTarget: { hebrew: target.nameHebrew, fallback: target.nameEnglish },
  };
}

const FLASHCARD_STATE_KEY = 'alef.flashcardState.v1';

interface PersistedFlashcardState {
  subMode: StudySubMode;
  frontType: CardFrontType;
  deckScope: DeckScope;
  cardIndex: number;
  quizType: QuizType;
}

export const FlashcardStudyView: React.FC<FlashcardStudyViewProps> = ({
  letters,
  masteryMap,
  onSetMastery,
  onOpenDetail,
  speechRate,
}) => {
  const initialFlash = useMemo(
    () =>
      readStorage<PersistedFlashcardState>(FLASHCARD_STATE_KEY, {
        subMode: 'flip',
        frontType: 'block',
        deckScope: 'all',
        cardIndex: 0,
        quizType: 'block-to-sound',
      }),
    []
  );

  const [subMode, setSubMode] = useState<StudySubMode>(initialFlash.subMode);
  const [showDeckOptions, setShowDeckOptions] = useState(false);
  const [frontType, setFrontType] = useState<CardFrontType>(initialFlash.frontType);
  const [deckScope, setDeckScope] = useState<DeckScope>(initialFlash.deckScope);
  const [shuffledIds, setShuffledIds] = useState<string[] | null>(null);
  const [cardIndex, setCardIndex] = useState(initialFlash.cardIndex);
  const [isFlipped, setIsFlipped] = useState(false);

  const [quizType, setQuizType] = useState<QuizType>(initialFlash.quizType);
  const [question, setQuestion] = useState<QuizQuestion>(() =>
    buildQuizQuestion(letters, initialFlash.quizType)
  );
  const [selectedOptionId, setSelectedOptionId] = useState<string | null>(null);
  const [quizStats, setQuizStats] = useState({ correct: 0, total: 0, streak: 0 });

  useEffect(() => {
    writeStorage<PersistedFlashcardState>(FLASHCARD_STATE_KEY, {
      subMode,
      frontType,
      deckScope,
      cardIndex,
      quizType,
    });
  }, [subMode, frontType, deckScope, cardIndex, quizType]);

  const baseDeck = useMemo(() => {
    const filtered = letters.filter((l) => {
      const m = masteryMap[l.id] ?? 'unlearned';
      if (deckScope === 'needs_review') return m !== 'mastered';
      if (deckScope === 'sofit') return Boolean(l.sofit);
      if (deckScope === 'begadkefat') return Boolean(l.begadkefat);
      return true;
    });
    return filtered.length > 0 ? filtered : letters;
  }, [letters, deckScope, masteryMap]);

  const activeDeck = useMemo(() => {
    if (!shuffledIds) return baseDeck;
    const byId = new Map(baseDeck.map((l) => [l.id, l]));
    const ordered = shuffledIds
      .map((id) => byId.get(id))
      .filter((item): item is HebrewLetter => Boolean(item));
    return ordered.length === baseDeck.length ? ordered : baseDeck;
  }, [baseDeck, shuffledIds]);

  const safeIndex = cardIndex < activeDeck.length ? cardIndex : 0;
  const currentCard = activeDeck[safeIndex];

  useEffect(() => {
    setCardIndex(0);
    setIsFlipped(false);
    setShuffledIds(null);
  }, [deckScope]);

  useEffect(() => {
    if (subMode !== 'flip') return;
    function handleKey(e: KeyboardEvent) {
      if (
        e.target instanceof HTMLInputElement ||
        e.target instanceof HTMLTextAreaElement
      ) {
        return;
      }
      if (e.code === 'Space') {
        e.preventDefault();
        setIsFlipped((v) => {
          playFeedbackTone('flip');
          return !v;
        });
      } else if (e.key === 'ArrowRight') {
        goNext();
      } else if (e.key === 'ArrowLeft') {
        goPrev();
      }
    }
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [subMode, safeIndex, activeDeck.length]);

  function goNext() {
    setIsFlipped(false);
    setCardIndex((prev) => (prev + 1) % activeDeck.length);
  }

  function goPrev() {
    setIsFlipped(false);
    setCardIndex((prev) => (prev - 1 + activeDeck.length) % activeDeck.length);
  }

  function handleShuffle() {
    setShuffledIds(shuffleArray(baseDeck.map((l) => l.id)));
    setCardIndex(0);
    setIsFlipped(false);
  }

  function handleRateAndAdvance(level: MasteryLevel) {
    onSetMastery(currentCard.id, level);
    goNext();
  }

  const startNewQuestion = useCallback((nextType: QuizType = quizType) => {
    setSelectedOptionId(null);
    setQuestion(buildQuizQuestion(letters, nextType, nextType === quizType ? question.correctId : undefined));
  }, [letters, quizType, question.correctId]);

  useEffect(() => {
    if (subMode !== 'quiz' || selectedOptionId !== question.correctId) return;
    const timer = window.setTimeout(startNewQuestion, CORRECT_ANSWER_DELAY_MS);
    return () => window.clearTimeout(timer);
  }, [subMode, selectedOptionId, question.correctId, startNewQuestion]);

  function handleSelectQuizAnswer(optionId: string) {
    if (selectedOptionId !== null) return;
    setSelectedOptionId(optionId);
    const isCorrect = optionId === question.correctId;
    playFeedbackTone(isCorrect ? 'correct' : 'wrong');
    setQuizStats((prev) => ({
      correct: prev.correct + (isCorrect ? 1 : 0),
      total: prev.total + 1,
      streak: isCorrect ? prev.streak + 1 : 0,
    }));
  }

  const promptCursiveLetter = question.promptCursiveId
    ? letters.find((l) => l.id === question.promptCursiveId)
    : null;

  return (
    <div className="view-container flashcard-view">
      <div className="toolbar-card flashcard-toolbar">
        <div className="segmented-control">
          <button
            type="button"
            className={subMode === 'flip' ? 'active' : ''}
            onClick={() => setSubMode('flip')}
          >
            翻转闪卡
          </button>
          <button
            type="button"
            className={subMode === 'quiz' ? 'active' : ''}
            onClick={() => {
              setSubMode('quiz');
              startNewQuestion(quizType);
            }}
          >
            四选一
          </button>
        </div>

        {subMode === 'flip' && (
          <button
            type="button"
            className="btn-secondary btn-sm flash-deck-toggle"
            aria-expanded={showDeckOptions}
            aria-controls="flash-deck-options"
            onClick={() => setShowDeckOptions((open) => !open)}
          >
            卡组选项
          </button>
        )}

        {subMode === 'flip' ? (
          <div
            id="flash-deck-options"
            className={`flashcard-controls-group flash-deck-options ${showDeckOptions ? 'flash-deck-options-open' : ''}`}
          >
            <div className="segmented-control">
              <button
                type="button"
                className={frontType === 'block' ? 'active' : ''}
                onClick={() => setFrontType('block')}
              >
                印刷体正面
              </button>
              <button
                type="button"
                className={frontType === 'cursive' ? 'active' : ''}
                onClick={() => setFrontType('cursive')}
              >
                手写体正面
              </button>
              <button
                type="button"
                className={frontType === 'both' ? 'active' : ''}
                onClick={() => setFrontType('both')}
              >
                双字形对照
              </button>
              <button
                type="button"
                className={frontType === 'sofit' ? 'active' : ''}
                onClick={() => setFrontType('sofit')}
              >
                词尾形优先
              </button>
            </div>

            <select
              className="select-pill"
              value={deckScope}
              onChange={(e) => setDeckScope(e.target.value as DeckScope)}
              aria-label="选择词库范围"
            >
              <option value="all">全部 22 字母</option>
              <option value="needs_review">仅未掌握/学习中</option>
              <option value="sofit">仅词尾变形 (5)</option>
              <option value="begadkefat">仅 Begadkefat (6)</option>
            </select>

            <button
              type="button"
              className="btn-secondary btn-sm"
              onClick={handleShuffle}
            >
              <Shuffle size={14} />
              <span>随机打乱</span>
            </button>
            {shuffledIds && (
              <button
                type="button"
                className="btn-ghost btn-sm"
                onClick={() => {
                  setShuffledIds(null);
                  setCardIndex(0);
                  setIsFlipped(false);
                }}
              >
                <RotateCcw size={14} />
                <span>恢复顺序</span>
              </button>
            )}
          </div>
        ) : (
          <div className="flashcard-controls-group">
            <div className="segmented-control">
              <button
                type="button"
                className={quizType === 'block-to-sound' ? 'active' : ''}
                onClick={() => {
                  setQuizType('block-to-sound');
                  startNewQuestion('block-to-sound');
                }}
              >
                印刷体辨音
              </button>
              <button
                type="button"
                className={quizType === 'cursive-to-block' ? 'active' : ''}
                onClick={() => {
                  setQuizType('cursive-to-block');
                  startNewQuestion('cursive-to-block');
                }}
              >
                手写配印刷
              </button>
              <button
                type="button"
                className={quizType === 'sofit-match' ? 'active' : ''}
                onClick={() => {
                  setQuizType('sofit-match');
                  startNewQuestion('sofit-match');
                }}
              >
                词尾 Sofit
              </button>
              <button
                type="button"
                className={quizType === 'dagesh-quiz' ? 'active' : ''}
                onClick={() => {
                  setQuizType('dagesh-quiz');
                  startNewQuestion('dagesh-quiz');
                }}
              >
                Dagesh 音变
              </button>
            </div>
            <div className="quiz-score-badge">
              <span>
                得分：{quizStats.correct}/{quizStats.total}
              </span>
              <span>连对：{quizStats.streak}</span>
            </div>
          </div>
        )}
      </div>

      {subMode === 'flip' && currentCard && (
        <div className="flashcard-stage">
          <div className="deck-progress-row">
            <span>
              卡片 {safeIndex + 1} / {activeDeck.length}
            </span>
            <span className="muted-caption flashcard-keyboard-hint">快捷键：空格键翻面 · ←/→ 切换上下张</span>
          </div>

          <div
            className={`flip-card-wrapper ${isFlipped ? 'flipped' : ''}`}
            onClick={() => {
              playFeedbackTone('flip');
              setIsFlipped((v) => !v);
            }}
            role="button"
            tabIndex={0}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault();
                playFeedbackTone('flip');
                setIsFlipped((v) => !v);
              }
            }}
          >
            <div className="flip-card-inner">
              <div className="flip-card-face flip-front">
                <span className="front-order-tag">#{currentCard.order}</span>

                <div className="front-glyph-stage">
                  {frontType === 'block' && (
                    <span className="front-huge-hebrew" dir="rtl">
                      {currentCard.hebrew}
                    </span>
                  )}
                  {frontType === 'cursive' && (
                    <HebrewGlyphSvg
                      strokes={currentCard.strokeGuide.cursiveStrokes}
                      size={140}
                      strokeWidth={6}
                      showGuides
                    />
                  )}
                  {frontType === 'both' && (
                    <div className="front-both-pair">
                      <span className="front-huge-hebrew" dir="rtl">
                        {currentCard.hebrew}
                      </span>
                      <HebrewGlyphSvg
                        strokes={currentCard.strokeGuide.cursiveStrokes}
                        size={110}
                        strokeWidth={6}
                      />
                    </div>
                  )}
                  {frontType === 'sofit' && (
                    <span className="front-huge-hebrew" dir="rtl">
                      {currentCard.sofit || currentCard.hebrew}
                    </span>
                  )}
                </div>

                <div className="front-bottom-bar">
                  <button
                    type="button"
                    className="btn-secondary btn-sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      speakHebrew(
                        currentCard.nameHebrew,
                        currentCard.nameEnglish,
                        speechRate
                      );
                    }}
                  >
                    <Volume2 size={14} />
                    <span>听发音提示</span>
                  </button>
                  <span className="muted-caption">点击卡片查看背面详情</span>
                </div>
              </div>

              <div className="flip-card-face flip-back">
                <div className="back-header-row">
                  <div className="back-glyph-mini" dir="rtl">
                    {currentCard.hebrew}
                    {currentCard.sofit ? ` / ${currentCard.sofit}` : ''}
                  </div>
                  <div className="back-title-group">
                    <h3>
                      <span dir="rtl">{currentCard.nameHebrew}</span> ·{' '}
                      {currentCard.nameEnglish} · {currentCard.nameChinese}
                    </h3>
                    <span className="muted-caption">
                      Gematria = {currentCard.gematria} · 转写 {currentCard.transliteration}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="btn-ghost btn-sm"
                    onClick={(e) => {
                      e.stopPropagation();
                      onOpenDetail(currentCard.id);
                    }}
                    title="在单字卡片页打开完整详情与描红"
                  >
                    <ExternalLink size={14} />
                    <span>完整详情</span>
                  </button>
                </div>

                <div className="back-details-grid">
                  <div className="back-info-block">
                    <strong>现代读音 ({currentCard.modernIpa})</strong>
                    <p>{currentCard.modernSound}</p>
                  </div>
                  <div className="back-info-block">
                    <strong>圣经差异 ({currentCard.biblicalIpa})</strong>
                    <p>{currentCard.biblicalDiff}</p>
                  </div>
                  <div className="back-info-block">
                    <strong>象形与手写</strong>
                    <p>
                      {currentCard.meaning}。{currentCard.cursiveDesc}
                    </p>
                  </div>
                  {currentCard.examples[0] && (
                    <div className="back-info-block">
                      <strong>代表例词</strong>
                      <p>
                        <span className="ex-heb" dir="rtl">
                          {currentCard.examples[0].hebrew}
                        </span>{' '}
                        <code>{currentCard.examples[0].transliteration}</code> —{' '}
                        {currentCard.examples[0].meaning}
                      </p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          </div>

          <div className="flashcard-rating-bar">
            <button type="button" className="btn-secondary" onClick={goPrev}>
              上一张
            </button>
            <div className="rating-buttons">
              <button
                type="button"
                className="rate-btn rate-unlearned"
                onClick={() => handleRateAndAdvance('unlearned')}
              >
                <XCircle size={15} />
                <span>不熟 · 再练</span>
              </button>
              <button
                type="button"
                className="rate-btn rate-learning"
                onClick={() => handleRateAndAdvance('learning')}
              >
                <Clock size={15} />
                <span>学习中</span>
              </button>
              <button
                type="button"
                className="rate-btn rate-mastered"
                onClick={() => handleRateAndAdvance('mastered')}
              >
                <CheckCircle2 size={15} />
                <span>已掌握</span>
              </button>
            </div>
            <button type="button" className="btn-secondary" onClick={goNext}>
              下一张
            </button>
          </div>
        </div>
      )}

      {subMode === 'quiz' && (
        <div className="quiz-stage">
          <div className="quiz-card">
            <div className="quiz-prompt-header">
              <HelpCircle size={18} />
              <h3>{question.promptTitle}</h3>
              {question.speakTarget && (
                <button
                  type="button"
                  className="btn-ghost btn-sm"
                  onClick={() =>
                    speakHebrew(
                      question.speakTarget!.hebrew,
                      question.speakTarget!.fallback,
                      speechRate
                    )
                  }
                >
                  <Volume2 size={14} />
                  <span>朗读</span>
                </button>
              )}
            </div>

            <div className="quiz-stimulus-box">
              {question.promptHebrew && (
                <span className="quiz-big-hebrew" dir="rtl">
                  {question.promptHebrew}
                </span>
              )}
              {promptCursiveLetter && (
                <HebrewGlyphSvg
                  strokes={promptCursiveLetter.strokeGuide.cursiveStrokes}
                  size={120}
                  strokeWidth={6}
                  showGuides
                />
              )}
            </div>

            <div className="quiz-options-grid">
              {question.options.map((opt) => {
                const isSelected = selectedOptionId === opt.id;
                const isCorrect = opt.id === question.correctId;
                let stateClass = '';
                if (selectedOptionId !== null) {
                  if (isCorrect) stateClass = 'correct';
                  else if (isSelected) stateClass = 'wrong';
                  else stateClass = 'dimmed';
                }

                return (
                  <button
                    key={opt.id}
                    type="button"
                    className={`quiz-option-btn ${stateClass}`}
                    onClick={() => handleSelectQuizAnswer(opt.id)}
                  >
                    <span className="opt-main" dir="auto">
                      {opt.label}
                    </span>
                    {opt.subLabel && <span className="opt-sub">{opt.subLabel}</span>}
                  </button>
                );
              })}
            </div>

            {selectedOptionId !== null && (
              <div
                className={`quiz-feedback-box ${
                  selectedOptionId === question.correctId ? 'correct' : 'wrong'
                }`}
              >
                <div className="feedback-text">
                  <strong>
                    {selectedOptionId === question.correctId ? '回答正确！' : '再记一下：'}
                  </strong>
                  <span>{question.explanation}</span>
                </div>
                <button
                  type="button"
                  className="btn-primary"
                  onClick={() => startNewQuestion(quizType)}
                >
                  <RefreshCw size={14} />
                  <span>下一题</span>
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
