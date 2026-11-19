import React, { useMemo, useState } from 'react';
import { HelpCircle, Layers, Volume2 } from 'lucide-react';
import { playFeedbackTone, speakHebrew } from '../utils/audio';

import { CONSONANT_OPTIONS, VOWEL_PATTERNS, type ConsonantItem, type VowelPattern } from '../data/syllables';

interface SyllableLabProps {
  speechRate: number;
}

interface GeneratedSyllable {
  key: string;
  hebrew: string;
  roman: string;
  ipa: string;
  pattern: VowelPattern;
  consonant: ConsonantItem;
}

function buildSyllable(c: ConsonantItem, v: VowelPattern): GeneratedSyllable {
  const hebrew = `${c.glyph}${v.mark}${v.suffix ?? ''}`;
  const roman =
    v.id === 'shva'
      ? c.isSilent
        ? '(e / ∅)'
        : `${c.roman}(e)`
      : c.isSilent
      ? v.vowelRoman
      : `${c.roman}${v.vowelRoman}`;
  const ipa = c.isSilent ? `/${v.vowelIpa}/` : `/${c.ipa}${v.vowelIpa}/`;
  return {
    key: `${c.id}-${v.id}`,
    hebrew,
    roman,
    ipa,
    pattern: v,
    consonant: c,
  };
}

export const SyllableLab: React.FC<SyllableLabProps> = ({ speechRate }) => {
  const [selectedConsonantId, setSelectedConsonantId] = useState<string>('bet');
  const [labMode, setLabMode] = useState<'explore' | 'quiz'>('explore');

  // Quiz state
  const [quizTarget, setQuizTarget] = useState<GeneratedSyllable>(() =>
    buildSyllable(CONSONANT_OPTIONS[1], VOWEL_PATTERNS[0])
  );
  const [quizOptions, setQuizOptions] = useState<GeneratedSyllable[]>(() => [
    buildSyllable(CONSONANT_OPTIONS[1], VOWEL_PATTERNS[0]),
    buildSyllable(CONSONANT_OPTIONS[1], VOWEL_PATTERNS[2]),
    buildSyllable(CONSONANT_OPTIONS[1], VOWEL_PATTERNS[4]),
    buildSyllable(CONSONANT_OPTIONS[1], VOWEL_PATTERNS[5]),
  ]);
  const [pickedKey, setPickedKey] = useState<string | null>(null);
  const [score, setScore] = useState({ correct: 0, total: 0 });

  const selectedConsonant = useMemo(
    () => CONSONANT_OPTIONS.find((c) => c.id === selectedConsonantId) ?? CONSONANT_OPTIONS[1],
    [selectedConsonantId]
  );

  const syllables = useMemo(
    () => VOWEL_PATTERNS.map((v) => buildSyllable(selectedConsonant, v)),
    [selectedConsonant]
  );

  function nextSyllableQuiz() {
    const cPool = CONSONANT_OPTIONS.filter((c) => !c.isSilent);
    const randC = cPool[Math.floor(Math.random() * cPool.length)];
    const coreVowels = VOWEL_PATTERNS.filter((v) =>
      ['kamatz', 'tzere', 'chirik', 'cholam', 'shuruk'].includes(v.id)
    );
    const shuffledV = [...coreVowels].sort(() => Math.random() - 0.5).slice(0, 4);
    const opts = shuffledV.map((v) => buildSyllable(randC, v));
    const target = opts[Math.floor(Math.random() * opts.length)];
    setQuizTarget(target);
    setQuizOptions(opts);
    setPickedKey(null);
    speakHebrew(target.hebrew, target.roman, speechRate);
  }

  function handleAnswer(optKey: string) {
    if (pickedKey) return;
    setPickedKey(optKey);
    const isRight = optKey === quizTarget.key;
    playFeedbackTone(isRight ? 'correct' : 'wrong');
    setScore((prev) => ({
      correct: prev.correct + (isRight ? 1 : 0),
      total: prev.total + 1,
    }));
  }

  return (
    <div className="syllable-lab">
      <div className="rules-intro-banner syllable-lab-banner">
        <div>
          <h3>音节拼读实验室（辅音 + 元音点 Niqqud）</h3>
          <p>
            选择任意希伯来辅音，点击下方元音组合卡片即可听音拼读，快速掌握「辅音 + 元音符号」的读音规律。
          </p>
        </div>
        <div className="segmented-control">
          <button
            type="button"
            className={labMode === 'explore' ? 'active' : ''}
            onClick={() => setLabMode('explore')}
          >
            自由拼读
          </button>
          <button
            type="button"
            className={labMode === 'quiz' ? 'active' : ''}
            onClick={() => {
              setLabMode('quiz');
              nextSyllableQuiz();
            }}
          >
            <HelpCircle size={13} style={{ marginRight: 4, verticalAlign: '-2px' }} />
            听音辨音节
          </button>
        </div>
      </div>

      {labMode === 'explore' ? (
        <>
          <div className="consonant-picker-bar" dir="rtl">
            {CONSONANT_OPTIONS.map((c) => (
              <button
                key={c.id}
                type="button"
                className={`consonant-chip ${selectedConsonant.id === c.id ? 'active' : ''}`}
                onClick={() => setSelectedConsonantId(c.id)}
                title={`${c.label} (${c.ipa})`}
              >
                <span className="consonant-chip-glyph">{c.glyph}</span>
                <span className="consonant-chip-sub" dir="ltr">
                  {c.isSilent ? '静音' : `/${c.ipa}/`}
                </span>
              </button>
            ))}
          </div>

          <div className="syllables-grid">
            {syllables.map((item) => (
              <button
                key={item.key}
                type="button"
                className="syllable-card"
                onClick={() => speakHebrew(item.hebrew, item.roman, speechRate)}
              >
                <div className="syllable-card-top">
                  <span className="meta-badge">{item.pattern.nameZh}</span>
                  <Volume2 size={14} className="syllable-speaker" />
                </div>
                <div className="syllable-big-glyph" dir="rtl">
                  {item.hebrew}
                </div>
                <div className="syllable-reading-row">
                  <strong>{item.roman}</strong>
                  <span className="ipa-chip">{item.ipa}</span>
                </div>
                <div className="syllable-vowel-name">{item.pattern.name}</div>
                <p className="syllable-tip">{item.pattern.tip}</p>
              </button>
            ))}
          </div>

          <div className="shva-examples-bar">
            <span className="shva-examples-label">词首 Sheva 真词对照：</span>
            <button
              type="button"
              className="shva-example-chip"
              onClick={() => speakHebrew('סְלִיחָה', 'slicha', speechRate)}
            >
              <Volume2 size={13} />
              <span className="ex-heb" dir="rtl">
                סְלִיחָה
              </span>
              <code>slicha</code>
              <span className="muted-caption">（静音 ∅）</span>
            </button>
            <button
              type="button"
              className="shva-example-chip"
              onClick={() => speakHebrew('מְדַבֵּר', 'medaber', speechRate)}
            >
              <Volume2 size={13} />
              <span className="ex-heb" dir="rtl">
                מְדַבֵּר
              </span>
              <code>medaber</code>
              <span className="muted-caption">（轻读 /e/）</span>
            </button>
          </div>
        </>
      ) : (
        <div className="quiz-stage">
          <div className="quiz-card">
            <div className="quiz-prompt-header">
              <h3>听发音，选出正确的希伯来语拼读音节</h3>
              <div className="quiz-score-badge">
                <Layers size={14} />
                <span>
                  得分 {score.correct} / {score.total}
                </span>
              </div>
            </div>

            <div className="quiz-stimulus-box">
              <button
                type="button"
                className="btn-primary"
                onClick={() => speakHebrew(quizTarget.hebrew, quizTarget.roman, speechRate)}
              >
                <Volume2 size={18} />
                <span>播放音节发音（{quizTarget.consonant.label} 组）</span>
              </button>
            </div>

            <div className="quiz-options-grid">
              {quizOptions.map((opt) => {
                const isPicked = pickedKey === opt.key;
                const isRight = opt.key === quizTarget.key;
                let cls = 'quiz-option-btn';
                if (pickedKey) {
                  if (isRight) cls += ' correct';
                  else if (isPicked) cls += ' wrong';
                  else cls += ' dimmed';
                }
                return (
                  <button
                    key={opt.key}
                    type="button"
                    className={cls}
                    onClick={() => handleAnswer(opt.key)}
                  >
                    <span className="opt-main" style={{ fontSize: 38 }} dir="rtl">
                      {opt.hebrew}
                    </span>
                    <span className="opt-sub">
                      {pickedKey ? `${opt.roman} · ${opt.pattern.name}` : opt.pattern.nameZh}
                    </span>
                  </button>
                );
              })}
            </div>

            {pickedKey && (
              <div
                className={`quiz-feedback-box ${
                  pickedKey === quizTarget.key ? 'correct' : 'wrong'
                }`}
              >
                <div className="feedback-text">
                  <strong>{pickedKey === quizTarget.key ? '回答正确！' : '再听一次：'}</strong>
                  <span>
                    {quizTarget.hebrew} = {quizTarget.roman} ({quizTarget.ipa}) ·{' '}
                    {quizTarget.pattern.name}
                  </span>
                </div>
                <button
                  type="button"
                  className="btn-primary btn-sm"
                  onClick={nextSyllableQuiz}
                >
                  下一题
                </button>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
};
