import { Delete } from 'lucide-react';

const HEBREW_KEYS = Array.from('אבגדהוזחטיכלמנסעפצקרשתךםןףץ״ ');

interface WordSpellingInputProps {
  value: string;
  onChange: (value: string) => void;
  onSubmit: () => void;
  submitted: boolean;
}

export function WordSpellingInput({ value, onChange, onSubmit, submitted }: WordSpellingInputProps) {
  return (
    <>
      <input
        className="spelling-display-box spelling-text-input"
        dir="rtl"
        lang="he"
        aria-label="输入希伯来语单词"
        placeholder="输入或点选希伯来字母"
        autoComplete="off"
        autoCapitalize="none"
        spellCheck={false}
        value={value}
        readOnly={submitted}
        onChange={(event) => onChange(event.target.value)}
        onKeyDown={(event) => {
          if (event.key === 'Enter' && !event.nativeEvent.isComposing && !submitted) {
            event.preventDefault();
            onSubmit();
          }
        }}
      />
      {!submitted && (
        <>
          <div className="hebrew-keyboard-grid" role="group" aria-label="希伯来语键盘" dir="rtl" lang="he">
            {HEBREW_KEYS.map((character) => (
              <button key={character} type="button" className={`hebrew-key-btn${character === ' ' ? ' hebrew-space-key' : ''}`}
                aria-label={character === '״' ? '希伯来语双引号' : undefined} onClick={() => onChange(value + character)}>
                {character === ' ' ? '空格' : character}
              </button>
            ))}
          </div>
          <div className="spelling-actions-row">
            <button
              type="button"
              className="btn-secondary btn-sm"
              disabled={!value}
              onClick={() => {
                const letters = Array.from(value.replace(/[\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7]+$/u, ''));
                onChange(letters.slice(0, -1).join(''));
              }}
            >
              <Delete size={14} aria-hidden="true" /> 退格
            </button>
            <button type="button" className="btn-ghost btn-sm" disabled={!value} onClick={() => onChange('')}>
              清空
            </button>
          </div>
        </>
      )}
    </>
  );
}
