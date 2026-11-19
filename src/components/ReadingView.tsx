import { useState } from 'react';
import { Eye, EyeOff, Volume2 } from 'lucide-react';
import { HEBREW_READINGS, READING_CATEGORIES, type HebrewReading } from '../data/hebrewReadings';
import { speakHebrew } from '../utils/audio';

interface ReadingProps {
  showNiqqud: boolean;
  onToggleNiqqud: () => void;
  speechRate: number;
  onRecordActivity: () => void;
}

export function ReadingView({ onToggleNiqqud, ...articleProps }: ReadingProps) {
  const [readingId, setReadingId] = useState(HEBREW_READINGS[0].id);
  const reading = HEBREW_READINGS.find((item) => item.id === readingId) ?? HEBREW_READINGS[0];
  const { showNiqqud } = articleProps;

  return (
    <div className="reading-view">
      <div className="reading-controls">
        <label className="reading-picker">
          <span>篇目</span>
          <select
            className="select-pill"
            value={reading.id}
            onChange={(event) => setReadingId(event.target.value)}
          >
            {Object.entries(READING_CATEGORIES).map(([category, label]) => (
              <optgroup key={category} label={label}>
                {HEBREW_READINGS.filter((item) => item.category === category).map((item) => (
                  <option key={item.id} value={item.id}>{item.title}</option>
                ))}
              </optgroup>
            ))}
          </select>
        </label>
        <button
          type="button"
          className={`btn-secondary btn-sm ${showNiqqud ? 'active-btn' : ''}`}
          aria-pressed={showNiqqud}
          onClick={onToggleNiqqud}
        >
          {showNiqqud ? <Eye size={14} /> : <EyeOff size={14} />}
          元音点
        </button>
      </div>
      <ReadingArticle key={reading.id} reading={reading} {...articleProps} />
    </div>
  );
}

function ReadingArticle({ reading, showNiqqud, speechRate, onRecordActivity }:
  Omit<ReadingProps, 'onToggleNiqqud'> & { reading: HebrewReading }) {
  const [activeWord, setActiveWord] = useState<{ sentenceIndex: number; tokenIndex: number } | null>(null);
  const [answer, setAnswer] = useState<number | null>(null);
  const isCorrect = answer === reading.question.correctIndex;

  return (
    <article className="reading-article">
      <header>
        <p className="muted-caption">{reading.source ?? READING_CATEGORIES[reading.category]}</p>
        <h2>{reading.title}</h2>
        <p className="muted-caption">点按带下划线的词查看释义。</p>
      </header>

      <div className="reading-passage">
        {reading.sentences.map((sentence, sentenceIndex) => {
          const tokens = (showNiqqud ? sentence.hebrew : sentence.unpointed).split(/((?:[א-ת]\p{M}*)+)/u);
          const selectedIndex = activeWord?.sentenceIndex === sentenceIndex ? activeWord.tokenIndex : -1;
          const selectedWord = tokens[selectedIndex];
          const gloss = selectedWord && reading.glosses[selectedWord.replace(/\p{M}/gu, '')];

          return (
            <div className="reading-line" key={sentence.hebrew}>
              <button
                type="button"
                className="btn-secondary btn-sm reading-audio"
                aria-label={`朗读第 ${sentenceIndex + 1} 句`}
                title={`朗读第 ${sentenceIndex + 1} 句`}
                onClick={() => speakHebrew(sentence.hebrew, sentence.transliteration, speechRate)}
              >
                <Volume2 size={16} />
              </button>
              <div>
                <p className="reading-hebrew" lang="he" dir="rtl">
                  {tokens.map((token, tokenIndex) => (
                    reading.glosses[token.replace(/\p{M}/gu, '')] ? (
                      <button
                        type="button"
                        className="reading-word"
                        key={tokenIndex}
                        aria-pressed={selectedIndex === tokenIndex}
                        onClick={() => setActiveWord(selectedIndex === tokenIndex ? null : { sentenceIndex, tokenIndex })}
                      >
                        {token}
                      </button>
                    ) : token
                  ))}
                </p>
                <div className="reading-gloss" role="status">
                  {gloss && <><bdi lang="he" dir="rtl">{selectedWord}</bdi> · {gloss}</>}
                </div>
              </div>
            </div>
          );
        })}
      </div>

      <details className="reading-translation">
        <summary>中文译文</summary>
        {reading.sentences.map((sentence) => <p key={sentence.hebrew}>{sentence.chinese}</p>)}
      </details>

      <fieldset className="reading-question">
        <legend>{reading.question.prompt}</legend>
        <div className="reading-choices">
          {reading.question.choices.map((choice, index) => (
            <button
              type="button"
              className={`btn-secondary btn-sm ${answer === index ? 'active-btn' : ''}`}
              key={choice}
              aria-pressed={answer === index}
              disabled={isCorrect}
              onClick={() => {
                setAnswer(index);
                if (index === reading.question.correctIndex) onRecordActivity();
              }}
            >
              {choice}
            </button>
          ))}
        </div>
        <p className="reading-feedback" role="status">
          {isCorrect ? '回答正确。' : answer !== null ? '再读一下原文，然后重试。' : null}
        </p>
      </fieldset>
    </article>
  );
}
