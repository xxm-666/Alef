import React, { useEffect, useState } from 'react';
import { Volume2 } from 'lucide-react';
import {
  ConfusableGroup,
  HebrewLetter,
  NiqqudItem,
} from '../types/hebrew';
import { HebrewGlyphSvg } from './HebrewGlyphSvg';
import { SyllableLab } from './SyllableLab';
import { speakHebrew } from '../utils/audio';
import { readStorage, writeStorage } from '../utils/storage';

interface SpecialRulesViewProps {
  letters: HebrewLetter[];
  confusableGroups: ConfusableGroup[];
  niqqudList: NiqqudItem[];
  onSelectLetter: (letterId: string) => void;
  speechRate: number;
}

type RulesTab = 'syllables' | 'sofit' | 'begadkefat' | 'confusable' | 'guttural' | 'niqqud';

const RULES_TAB_KEY = 'alef.rulesTab.v1';

const RULES_TABS: { id: RulesTab; badge: string; title: string; sub: string }[] = [
  { id: 'syllables', badge: 'בָּ', title: '音节拼读', sub: '辅音+元音练习' },
  { id: 'sofit', badge: 'ךםן', title: '词尾变形', sub: 'Sofit · כמנפ״ץ' },
  { id: 'begadkefat', badge: 'בּב', title: 'Dagesh 音变', sub: '软硬音 · בגדכפ״ת' },
  { id: 'confusable', badge: 'ד↔ר', title: '易混淆对比', sub: '形近字母辨析' },
  { id: 'guttural', badge: 'אהח', title: '喉音字母', sub: 'אהחע״ר 特性' },
  { id: 'niqqud', badge: 'אָאֶ', title: '元音速查', sub: 'Niqqud 符号表' },
];

export const SpecialRulesView: React.FC<SpecialRulesViewProps> = ({
  letters,
  confusableGroups,
  niqqudList,
  onSelectLetter,
  speechRate,
}) => {
  const [activeTab, setActiveTab] = useState<RulesTab>(() =>
    readStorage<RulesTab>(RULES_TAB_KEY, 'sofit')
  );

  useEffect(() => {
    writeStorage(RULES_TAB_KEY, activeTab);
  }, [activeTab]);

  const sofitLetters = letters.filter((l) => Boolean(l.sofitInfo));
  const begadkefatLetters = letters.filter((l) => Boolean(l.begadkefat));
  const gutturalLetters = letters.filter((l) => l.categories.includes('guttural'));

  return (
    <div className="view-container rules-view">
      <div className="rules-tabs-grid" role="tablist" aria-label="规则分类切换">
        {RULES_TABS.map((tab) => {
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              type="button"
              role="tab"
              aria-selected={isActive}
              className={`rules-tab-btn ${isActive ? 'active' : ''}`}
              onClick={() => setActiveTab(tab.id)}
            >
              <span className="rules-tab-badge" dir="rtl">
                {tab.badge}
              </span>
              <span className="rules-tab-text">
                <strong>{tab.title}</strong>
                <span>{tab.sub}</span>
              </span>
            </button>
          );
        })}
      </div>

      {activeTab === 'syllables' && <SyllableLab speechRate={speechRate} />}

      {activeTab === 'sofit' && (
        <div className="rules-section">
          <div className="rules-intro-banner">
            <h3>5 个词尾变形字母 (כ מ נ פ צ → ך ם ן ף ץ)</h3>
            <p>
              记忆口诀「כמנפ״ץ (Kamnapetz)」：这 5 个字母出现在单词最末尾（RTL 最左侧）时必须换写为词尾形 (Sofit)。注意除
              <strong> ם </strong>闭合外，其余 4 个词尾形 (<strong>ך ן ף ץ</strong>) 均向下突破基准底线。
            </p>
          </div>
          <div className="rules-cards-grid">
            {sofitLetters.map((letter) => (
              <div
                key={letter.id}
                role="button"
                tabIndex={0}
                className="rule-compare-card"
                onClick={() => onSelectLetter(letter.id)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    onSelectLetter(letter.id);
                  }
                }}
              >
                <div className="rule-card-header">
                  <strong>
                    {letter.nameEnglish} · {letter.nameChinese}
                  </strong>
                  <span className="meta-badge">
                    数值 {letter.gematria} → {letter.sofitInfo?.sofitGematria}
                  </span>
                </div>
                <div className="sofit-matrix">
                  <div className="matrix-col">
                    <span className="muted-caption">词中印刷 / 手写</span>
                    <div className="matrix-glyphs">
                      <span className="matrix-block" dir="rtl">
                        {letter.hebrew}
                      </span>
                      <HebrewGlyphSvg
                        strokes={letter.strokeGuide.cursiveStrokes}
                        size={42}
                        strokeWidth={6}
                      />
                    </div>
                  </div>
                  <div className="matrix-arrow">→</div>
                  <div className="matrix-col highlight">
                    <span className="muted-caption">词尾印刷 / 手写</span>
                    <div className="matrix-glyphs">
                      <span className="matrix-block" dir="rtl">
                        {letter.sofit}
                      </span>
                      {letter.strokeGuide.sofitCursiveStrokes && (
                        <HebrewGlyphSvg
                          strokes={letter.strokeGuide.sofitCursiveStrokes}
                          size={42}
                          strokeWidth={6}
                        />
                      )}
                    </div>
                  </div>
                </div>
                <p className="rule-desc-text">{letter.sofitInfo?.rule}</p>
                {letter.sofitInfo?.exampleWord && (
                  <div className="rule-example-footer">
                    <span className="ex-heb" dir="rtl">
                      {letter.sofitInfo.exampleWord.hebrew}
                    </span>
                    <code>{letter.sofitInfo.exampleWord.transliteration}</code>
                    <span>{letter.sofitInfo.exampleWord.meaning}</span>
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'begadkefat' && (
        <div className="rules-section">
          <div className="rules-intro-banner">
            <h3>Begadkefat 六大点音变字母 (ב ג ד כ פ ת)</h3>
            <p>
              这 6 个塞音字母根据内部是否带有中心圆点 <strong>Dagesh Kal</strong> 产生硬音（塞音）与软音（擦音）交替。
              在<strong>现代希伯来语</strong>中，只有 <strong>ב · כ · פ</strong> 保留读音区别；<strong>ג · ד · ת</strong> 的擦音化仅保留在圣经/古典朗诵体系中。
            </p>
          </div>
          <div className="rules-cards-grid">
            {begadkefatLetters.map((letter) => {
              const info = letter.begadkefat!;
              return (
                <div
                  key={letter.id}
                  role="button"
                  tabIndex={0}
                  className="rule-compare-card"
                  onClick={() => onSelectLetter(letter.id)}
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' || e.key === ' ') {
                      e.preventDefault();
                      onSelectLetter(letter.id);
                    }
                  }}
                >
                  <div className="rule-card-header">
                    <strong>
                      {letter.nameEnglish} · {letter.nameChinese}
                    </strong>
                    <span
                      className={`status-pill ${
                        info.modernPreserved ? 'preserved' : 'merged'
                      }`}
                    >
                      {info.modernPreserved ? '现代保留音变' : '现代已合并'}
                    </span>
                  </div>

                  <div className="dagesh-mini-pair">
                    <div className="dagesh-mini-box">
                      <span className="matrix-block" dir="rtl">
                        {info.withDagesh.glyph}
                      </span>
                      <span className="ipa-tag">{info.withDagesh.modernIpa}</span>
                      <span className="muted-caption">
                        古典：{info.withDagesh.biblicalIpa}
                      </span>
                    </div>
                    <div className="dagesh-mini-box soft">
                      <span className="matrix-block" dir="rtl">
                        {info.withoutDagesh.glyph}
                      </span>
                      <span className="ipa-tag">{info.withoutDagesh.modernIpa}</span>
                      <span className="muted-caption">
                        古典：{info.withoutDagesh.biblicalIpa}
                      </span>
                    </div>
                  </div>
                  <p className="rule-desc-text">{info.note}</p>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {activeTab === 'confusable' && (
        <div className="rules-section">
          <div className="rules-intro-banner">
            <h3>极易混淆的希伯来印刷体字母对比</h3>
            <p>
              希伯来语方体字 (Block Script) 中多组字母仅在圆角/直角、顶角是否留缺口、脚跟是否突出或是否穿破底线处存在细微差异。点击下方任意字母即可进入单字卡放大观察。
            </p>
          </div>
          <div className="confusable-groups-list">
            {confusableGroups.map((group) => {
              const groupLetters = group.letterIds
                .map((id) => letters.find((l) => l.id === id))
                .filter((item): item is HebrewLetter => Boolean(item));

              return (
                <div key={group.id} className="confusable-group-card">
                  <h4 className="group-title">{group.title}</h4>
                  <div className="group-glyphs-row">
                    {groupLetters.map((item) => (
                      <button
                        key={item.id}
                        type="button"
                        className="group-letter-btn"
                        onClick={() => onSelectLetter(item.id)}
                      >
                        <span className="group-big-char" dir="rtl">
                          {item.hebrew}
                          {item.sofit ? ` / ${item.sofit}` : ''}
                        </span>
                        <span className="group-letter-name">
                          {item.nameEnglish} · {item.nameChinese}
                        </span>
                        <span className="ipa-tag">{item.modernIpa}</span>
                      </button>
                    ))}
                  </div>
                  <ul className="group-notes-list">
                    {group.comparisonNotes.map((note, idx) => (
                      <li key={idx}>{note}</li>
                    ))}
                  </ul>
                  <p className="group-tip">{group.tip}</p>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {activeTab === 'guttural' && (
        <div className="rules-section">
          <div className="rules-intro-banner">
            <h3>喉音及准喉音字母 (אהחע״ר)</h3>
            <p>
              <strong>א · ה · ח · ע</strong> 为四大喉音字母，加上特性相近的小舌/齿龈音 <strong>ר</strong> 合称「אהחע״ר」。它们的三大语法共性：
              1) 绝不接受重读双写点 Dagesh Chazak；2) 偏爱搭配复合元音 Hatef (אֲ אֱ אֳ)；3) 词尾 ח、ע 及带 Mappiq 的 הּ（不含 א、ר）会引发前置过渡元音「偷渡音 Patach」(-aḥ，如 רוּחַ ruach)。
            </p>
          </div>
          <div className="rules-cards-grid">
            {gutturalLetters.map((letter) => (
              <div
                key={letter.id}
                role="button"
                tabIndex={0}
                className="rule-compare-card"
                onClick={() => onSelectLetter(letter.id)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' || e.key === ' ') {
                    e.preventDefault();
                    onSelectLetter(letter.id);
                  }
                }}
              >
                <div className="rule-card-header">
                  <span className="matrix-block" dir="rtl">
                    {letter.hebrew}
                  </span>
                  <div>
                    <strong>
                      {letter.nameEnglish} · {letter.nameChinese}
                    </strong>
                    <div className="muted-caption">
                      现代 {letter.modernIpa} · 圣经 {letter.biblicalIpa}
                    </div>
                  </div>
                </div>
                <p className="rule-desc-text">{letter.biblicalDiff}</p>
              </div>
            ))}
          </div>
        </div>
      )}

      {activeTab === 'niqqud' && (
        <div className="rules-section">
          <div className="rules-intro-banner">
            <h3>基础元音符号 (נִקּוּד Niqqud) 速查</h3>
            <p>
              现代日常报刊多不标元音，但字典、圣经、儿童读物与初学者教材会使用点与横符号标出元音（此处以字母 ב 作为示例底座）。
            </p>
          </div>
          <div className="niqqud-grid">
            {niqqudList.map((item) => (
              <div key={item.id} className="niqqud-card">
                <div className="niqqud-top">
                  <span className="niqqud-sample" dir="rtl">
                    {item.sample}
                  </span>
                  <div className="niqqud-names">
                    <strong dir="rtl">{item.nameHebrew}</strong>
                    <span>
                      {item.nameEnglish} · {item.nameChinese}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="card-mini-icon-btn"
                    title="听示例音读"
                    onClick={() => speakHebrew(item.nameHebrew, item.nameEnglish, speechRate)}
                  >
                    <Volume2 size={14} />
                  </button>
                </div>
                <div className="niqqud-sound-row">
                  <span className="ipa-tag">{item.ipa}</span>
                  <strong>元音：{item.vowelSound}</strong>
                </div>
                <p className="rule-desc-text">{item.note}</p>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
