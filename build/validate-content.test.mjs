import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';
import test from 'node:test';
import { extractDailyLetterIds, loadStudyContent, validateStudyContent } from './validate-content.mjs';

const rootUrl = new URL('../', import.meta.url);
const baseContent = await loadStudyContent(rootUrl);

function cloneContent() {
  return structuredClone(baseContent);
}

test('repository study content passes validation and matches DailyLetter.swift', async () => {
  const summary = await validateStudyContent(baseContent, { rootUrl });
  assert.equal(summary.letters, 22);
  assert.ok(summary.words > 1000);
  assert.ok(summary.phrases >= 120);
  assert.ok(baseContent.readings.filter(({ category }) => category === 'modern').length >= 24);
  assert.ok(baseContent.readings.filter(({ category }) => category === 'classic').length >= 14);
  assert.ok(summary.recordings > 0);
});

test('comic dialogue and props all have matching bundled audio', async () => {
  const swiftSource = await readFile(new URL('ios/App/App/StudyComicView.swift', rootUrl), 'utf8');
  const literalFields = /partnerReplyHebrew: "([^"]+)"|partner: ScenarioPartnerPrompt\(\s*hebrew: "([^"]+)"|tapAudioHebrew: "([^"]+)"|ScenarioPopupItem\([^\n]*?hebrew: "([^"]+)"/gu;
  const clips = [...swiftSource.matchAll(literalFields)].map((match) => match.slice(1).find(Boolean));
  const audio = new Map(Object.entries(baseContent.audio).map(([key, value]) => [key.normalize('NFC'), value]));
  assert.ok(clips.length > 0);
  for (const text of clips) {
    assert.ok(audio.has(text.normalize('NFC')), `Missing comic audio for "${text}"`);
  }
});

test('explicit vocabulary aliases point to a primary entry with the same pointed form', () => {
  const wordsById = new Map(baseContent.words.map((word) => [word.id, word]));
  const aliases = baseContent.words.filter((word) => word.equivalentTo);
  assert.equal(wordsById.get('lematah')?.equivalentTo, 'lemata');
  assert.ok(wordsById.has('mishtamesh') && wordsById.has('pack_tech_mishtamesh'));
  assert.equal(wordsById.get('pack_tech_mishtamesh')?.equivalentTo, undefined);
  for (const alias of aliases) {
    const primary = wordsById.get(alias.equivalentTo);
    assert.ok(primary, `Missing primary entry for ${alias.id}`);
    assert.equal(primary.equivalentTo, undefined, `Alias chain at ${alias.id}`);
    assert.equal(alias.hebrew.normalize('NFC'), primary.hebrew.normalize('NFC'), alias.id);
  }
});

test('rejects duplicate word IDs', async () => {
  const broken = cloneContent();
  broken.words.push({ ...broken.words[0] });
  await assert.rejects(
    validateStudyContent(broken, { rootUrl }),
    new RegExp(`Duplicate word id: ${broken.words[0].id}`),
  );
});

test('classifies the vocabulary and rejects unrecognized classifications', async () => {
  const shalom = baseContent.words.find(({ id }) => id === 'shalom');
  assert.equal(shalom.frequency, 'common');
  assert.equal(shalom.difficulty, 'beginner');
  const boardingPass = baseContent.words.find(({ id }) => id === 'kartis-aliya-lamatos');
  assert.equal(boardingPass.difficulty, 'advanced');
  assert.equal(new Set(baseContent.words.map(({ frequency }) => frequency)).size, 3);
  assert.equal(new Set(baseContent.words.map(({ difficulty }) => difficulty)).size, 3);

  const broken = cloneContent();
  broken.words[0].difficulty = 'expert';
  await assert.rejects(validateStudyContent(broken, { rootUrl }), /unknown difficulty "expert"/);
});

test('rejects missing audio mapping for a word', async () => {
  const broken = cloneContent();
  broken.words[0] = { ...broken.words[0], hebrew: 'מִלָּה־חֲסֵרָה' };
  await assert.rejects(
    validateStudyContent(broken, { rootUrl }),
    /missing an entry in audioManifest/,
  );
});

test('rejects invalid reading question.correctIndex', async () => {
  const broken = cloneContent();
  broken.readings[0] = {
    ...broken.readings[0],
    question: { ...broken.readings[0].question, correctIndex: 99 },
  };
  await assert.rejects(
    validateStudyContent(broken, { rootUrl }),
    /invalid question\.correctIndex/,
  );
});

test('each reading gloss can be opened with and without niqqud', () => {
  for (const reading of baseContent.readings) {
    for (const field of ['hebrew', 'unpointed']) {
      const visibleDefinitions = new Set();
      for (const sentence of reading.sentences) {
        const tokens = sentence[field].replace(/\p{M}/gu, '').match(/[א-ת]+/gu) ?? [];
        for (const token of tokens) {
          if (reading.glosses[token]) visibleDefinitions.add(reading.glosses[token]);
        }
      }
      assert.deepEqual(visibleDefinitions, new Set(Object.values(reading.glosses)), `${reading.id}: ${field}`);
    }
  }
});

test('unpointed classic readings retain the consonants of the cited text', () => {
  for (const reading of baseContent.readings.filter(({ category }) => category === 'classic')) {
    for (const sentence of reading.sentences) {
      assert.equal(sentence.unpointed, sentence.hebrew.replace(/\p{M}/gu, ''), reading.id);
    }
  }
});

test('labels the classic reading recordings by their actual playback style', async () => {
  const genesis = baseContent.readings.find(({ id }) => id === 'genesis');
  const psalm = baseContent.readings.find(({ id }) => id === 'psalm-23');
  assert.deepEqual(genesis.sentences.map(({ audio }) => audio.style), ['modernSynthesis', 'scriptureReading']);
  assert.deepEqual(psalm.sentences.map(({ audio }) => audio.style), ['traditionalChant', 'traditionalChant']);
  assert.ok(psalm.sentences.every(({ audio }) => audio.performer === 'Rabbi Dan Be’eri'));

  const broken = cloneContent();
  delete broken.readings.find(({ id }) => id === 'psalm-23').sentences[0].audio;
  await assert.rejects(validateStudyContent(broken, { rootUrl }), /"psalm-23" sentence #1 is missing a valid audio style/);
});

test('rejects orphan inflection key', async () => {
  const broken = cloneContent();
  broken.inflections['nonexistent-word-id'] = { ...Object.values(broken.inflections)[0] };
  await assert.rejects(
    validateStudyContent(broken, { rootUrl }),
    /Inflection entry "nonexistent-word-id" does not reference a known word id/,
  );
});

test('rejects mismatch with DailyLetter.swift alphabet IDs', async () => {
  const tempDir = await mkdtemp(join(tmpdir(), 'alef-daily-test-'));
  try {
    const fakeSwift = join(tempDir, 'DailyLetter.swift');
    await writeFile(
      fakeSwift,
      'struct DailyLetter {\n  static let alphabet: [DailyLetter] = [\n    .init(id: "wrong", glyph: "א", name: "Alef")\n  ]\n}\n',
      'utf8',
    );
    assert.deepEqual(extractDailyLetterIds('static let alphabet: [DailyLetter] = [.init(id: "alef", glyph: "א", name: "Alef")]'), ['alef']);
    await assert.rejects(
      validateStudyContent(baseContent, { rootUrl, dailyLetterSwiftPath: pathToFileURL(fakeSwift) }),
      /DailyLetter\.swift alphabet IDs/,
    );
  } finally {
    await rm(tempDir, { recursive: true, force: true });
  }
});

test('rejects minimal pair with identical word IDs or identical IPA', async () => {
  const sameId = cloneContent();
  sameId.minimalPairs[0] = { ...sameId.minimalPairs[0], secondWordId: sameId.minimalPairs[0].firstWordId };
  await assert.rejects(
    validateStudyContent(sameId, { rootUrl }),
    /uses identical wordId/,
  );

  const sameIpa = cloneContent();
  sameIpa.words = sameIpa.words.map((word) =>
    word.id === sameIpa.minimalPairs[0].secondWordId
      ? { ...word, ipa: sameIpa.words.find((w) => w.id === sameIpa.minimalPairs[0].firstWordId).ipa }
      : word,
  );
  await assert.rejects(
    validateStudyContent(sameIpa, { rootUrl }),
    /shares identical IPA/,
  );
});

test('rejects learning path missing a letter or referencing unknown word', async () => {
  const missingLetter = cloneContent();
  missingLetter.learningPath[0] = { ...missingLetter.learningPath[0], letterIds: [] };
  await assert.rejects(
    validateStudyContent(missingLetter, { rootUrl }),
    /does not cover all 22 letters/,
  );

  const badWord = cloneContent();
  badWord.learningPath[0] = { ...badWord.learningPath[0], wordIds: ['missing-word-id'] };
  await assert.rejects(
    validateStudyContent(badWord, { rootUrl }),
    /references unknown wordId "missing-word-id"/,
  );
});
