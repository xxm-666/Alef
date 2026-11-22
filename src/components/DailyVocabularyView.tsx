import { useState } from 'react';
import { ArrowLeft, ArrowRight, CalendarCheck, CheckCircle2, Volume2 } from 'lucide-react';
import {
  DAILY_GROUP_OPTIONS, DAILY_GROUP_SIZE, dailyGroupStatus, DailySpellingAnswer, DailyVocabularyGroup,
  DailyVocabularyPlan, hasStartedDailyGroup, isDailyGroupComplete,
} from '../data/dailyVocabulary';
import { HebrewWord } from '../types/hebrew';
import { playFeedbackTone, speakHebrew } from '../utils/audio';
import { WordSpellingInput } from './WordSpellingInput';

export function DailyVocabularyEntry({ plan, onOpen }: { plan: DailyVocabularyPlan; onOpen: () => void }) {
  const complete = plan.groups.filter(isDailyGroupComplete).length;
  const next = plan.groups[complete];
  const status = !plan.groups.length ? '暂无待学新词' : `已完成 ${complete} / ${plan.groups.length} 组`;
  return (
    <section className="daily-vocabulary-entry" aria-label="今日记词">
      <CalendarCheck size={22} aria-hidden="true" />
      <div>
        <h2>今日记词</h2>
        <p>{status}{next && ` · ${dailyGroupStatus(next)}`}</p>
      </div>
      <button type="button" className="btn-primary btn-sm" onClick={onOpen}>
        {next && hasStartedDailyGroup(next) ? '继续记词' : '查看今日计划'}
        <ArrowRight size={15} aria-hidden="true" />
      </button>
    </section>
  );
}

interface DailyVocabularyViewProps {
  plan: DailyVocabularyPlan;
  words: Map<string, HebrewWord>;
  speechRate: number;
  onExit: () => void;
  onReturnToPlan: () => void;
  onSetLimit: (count: number) => void;
  onAdvance: (group: DailyVocabularyGroup) => boolean;
  onAnswer: (group: DailyVocabularyGroup, word: HebrewWord, input: string) => DailySpellingAnswer | null;
}

export function DailyVocabularyView({
  plan, words, speechRate, onExit, onReturnToPlan, onSetLimit, onAdvance, onAnswer,
}: DailyVocabularyViewProps) {
  const [activeId, setActiveId] = useState<string>();
  const [revealed, setRevealed] = useState(false);
  const [spelling, setSpelling] = useState('');
  const [saveError, setSaveError] = useState('');
  const complete = plan.groups.filter(isDailyGroupComplete).length;
  const activeIndex = plan.groups.findIndex((group) => group.wordIds[0] === activeId);
  const group = plan.groups[activeIndex];

  function openGroup(selected?: DailyVocabularyGroup) {
    if (!selected) onReturnToPlan();
    setActiveId(selected?.wordIds[0]);
    setRevealed(false);
    setSpelling('');
    setSaveError('');
    window.requestAnimationFrame(() => {
      document.getElementById('daily-vocabulary-heading')?.focus({ preventScroll: true });
      document.querySelector('main')?.scrollTo({ top: 0 });
    });
  }

  function pronunciation(word: HebrewWord, title = '听发音') {
    return (
      <button type="button" className="btn-secondary btn-sm" onClick={() => speakHebrew(word.hebrew, word.transliteration, speechRate)}>
        <Volume2 size={16} aria-hidden="true" /> {title}
      </button>
    );
  }

  function renderGroup() {
    const total = group.wordIds.length;
    if (isDailyGroupComplete(group)) {
      const correct = group.answers.filter((answer) => answer.correct).length;
      return (
        <>
          <section className="daily-vocabulary-card daily-vocabulary-result">
            <CheckCircle2 size={30} aria-hidden="true" />
            <h3 id="daily-vocabulary-question" tabIndex={-1}>本组完成</h3>
            <p>拼对 {correct} / {total} 词</p>
          </section>
          {correct < total && (
            <section className="daily-vocabulary-card">
              <h3>待巩固的词</h3>
              <p>拼错的词已安排到期复习。</p>
              <ul className="daily-vocabulary-mistakes">
                {group.wordIds.map((id, index) => {
                  const word = words.get(id);
                  if (!word || group.answers[index].correct) return null;
                  return (
                    <li key={id}>
                      <b dir="rtl" lang="he">{word.hebrew}</b>
                      <span>{word.meaningZh}</span>
                    </li>
                  );
                })}
              </ul>
            </section>
          )}
          <button type="button" className="btn-primary" onClick={() => openGroup(plan.groups[complete])}>
            {plan.groups[complete] ? '开始下一组' : '返回今日计划'} <ArrowRight size={16} aria-hidden="true" />
          </button>
        </>
      );
    }

    const memorizing = group.studied < total;
    const index = memorizing ? group.studied : group.answers.length - Number(group.feedbackPending);
    const word = words.get(group.wordIds[index]);
    if (!word) return null;
    const answer = memorizing ? undefined : group.answers[index];
    const stage = memorizing ? '认读' : '拼写';

    function advance() {
      if (!onAdvance(group)) return;
      setRevealed(false);
      setSpelling('');
      window.requestAnimationFrame(() => document.getElementById('daily-vocabulary-question')?.focus({ preventScroll: true }));
    }

    const submit = () => {
      if (!spelling.trim()) return;
      try {
        const submitted = onAnswer(group, word, spelling);
        if (!submitted) return;
        setSaveError('');
        playFeedbackTone(submitted.correct ? 'correct' : 'wrong');
      } catch {
        setSaveError('无法保存进度，请检查浏览器存储后重试。');
        return;
      }
      window.requestAnimationFrame(() => document.getElementById('daily-vocabulary-feedback')?.focus({ preventScroll: true }));
    };

    return (
      <>
        <div className="daily-vocabulary-meter">
          <span>{stage} · 第 {index + 1} / {total} 词</span>
          <progress aria-label={`${stage}进度`} value={memorizing ? group.studied : group.answers.length} max={total} />
        </div>
        {memorizing ? (
          <section className="daily-vocabulary-card daily-vocabulary-word">
            <h3 id="daily-vocabulary-question" tabIndex={-1} dir="rtl" lang="he">{word.hebrew}</h3>
            {pronunciation(word)}
            <div className="daily-vocabulary-reveal" aria-live="polite">
              {revealed ? <><strong>{word.meaningZh}</strong><p>{word.transliteration}</p></>
                : <p>先回想词义，再翻看答案。</p>}
            </div>
            {revealed ? (
              <button type="button" className="btn-primary" onClick={advance}>
                {index + 1 === total ? '开始本组拼写' : '下一词'} <ArrowRight size={16} aria-hidden="true" />
              </button>
            ) : (
              <button type="button" className="btn-primary" onClick={() => setRevealed(true)}>显示释义</button>
            )}
          </section>
        ) : (
          <div className="daily-vocabulary-card spelling-quiz-body">
            <section className="spelling-prompt-box">
              <h3 id="daily-vocabulary-question" tabIndex={-1}>写出「{word.meaningZh}」</h3>
              <p>提示 · {word.transliteration}。可输入带点写法或无点全拼。</p>
            </section>
            <WordSpellingInput value={answer?.input ?? spelling} onChange={setSpelling} onSubmit={submit} submitted={Boolean(answer)} />
            {answer ? (
              <>
                <div id="daily-vocabulary-feedback" tabIndex={-1} className={`quiz-feedback-box ${answer.correct ? 'correct' : 'wrong'}`}>
                  <div className="feedback-text">
                    <strong>{answer.correct ? '回答正确' : '答案有误'}</strong>
                    <span>正确拼写 <b dir="rtl" lang="he">{word.hebrew}</b> · <b dir="rtl" lang="he">{word.hebrewUnpointed}</b></span>
                  </div>
                </div>
                {pronunciation(word, '听正确发音')}
                <button type="button" className="btn-primary" onClick={advance}>
                  {index + 1 === total ? '查看本组结果' : '下一题'} <ArrowRight size={16} aria-hidden="true" />
                </button>
              </>
            ) : (
              <>
                {saveError && <p role="alert">{saveError}</p>}
                <button type="button" className="btn-primary" disabled={!spelling.trim()} onClick={submit}>确认答案</button>
              </>
            )}
          </div>
        )}
      </>
    );
  }

  return (
    <div className="view-container daily-vocabulary-view">
      <header className="daily-vocabulary-heading">
        <button type="button" className="btn-secondary btn-sm" onClick={group ? () => openGroup() : onExit}>
          <ArrowLeft size={16} aria-hidden="true" /> {group ? '今日计划' : '返回'}
        </button>
        <h2 id="daily-vocabulary-heading" tabIndex={-1}>{group ? `第 ${activeIndex + 1} 组` : '今日记词'}</h2>
      </header>
      {group ? renderGroup() : (
        <>
          <section className="daily-vocabulary-card">
            <h3>今日计划</h3>
            <p>每组最多 {DAILY_GROUP_SIZE} 词，先认读，再拼写。</p>
            <div className="daily-vocabulary-meter">
              <span>已完成 {complete} / {plan.groups.length} 组</span>
              {plan.groups.length > 0 && <progress aria-label="今日分组进度" value={complete} max={plan.groups.length} />}
            </div>
            {!plan.groups.length ? <p>暂无待学新词。已安排过的单词可在到期复习中巩固。</p> : (
              <ol className="daily-vocabulary-groups">
                {plan.groups.map((item, index) => (
                  <li key={item.wordIds[0]}>
                    <div><strong>第 {index + 1} 组 · {item.wordIds.length} 词</strong><p>{dailyGroupStatus(item)}</p></div>
                    {index <= complete ? (
                      <button type="button" className={index === complete ? 'btn-primary btn-sm' : 'btn-secondary btn-sm'}
                        onClick={() => openGroup(item)} aria-label={`第 ${index + 1} 组 · ${index < complete ? '查看结果' : hasStartedDailyGroup(item) ? '继续' : '开始'}`}>
                        {index < complete ? '查看结果' : hasStartedDailyGroup(item) ? '继续' : '开始'}
                      </button>
                    ) : <small>上一组完成后开始</small>}
                  </li>
                ))}
              </ol>
            )}
            {complete > 0 && complete === plan.groups.length && <p className="daily-vocabulary-done">今日新词已完成，明天接着学。</p>}
          </section>
          <section className="daily-vocabulary-card">
            <h3>每日新词分组</h3>
            {plan.groups.some(hasStartedDailyGroup) && <p>今天已开始，调整从明天生效。</p>}
            <div className="segmented-control" role="group" aria-label="每日新词分组">
              {DAILY_GROUP_OPTIONS.map((count) => (
                <button key={count} type="button" className={count === plan.groupsPerDay ? 'active' : ''}
                  aria-pressed={count === plan.groupsPerDay} onClick={() => onSetLimit(count)}>{count} 组</button>
              ))}
            </div>
          </section>
        </>
      )}
    </div>
  );
}
