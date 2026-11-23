import assert from 'node:assert/strict';
import { mkdtemp, rm, writeFile } from 'node:fs/promises';
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
  assert.ok(summary.phrases > 0);
  assert.equal(summary.readings, 12);
  assert.ok(summary.recordings > 0);
});

test('rejects duplicate word IDs', async () => {
  const broken = cloneContent();
  broken.words.push({ ...broken.words[0] });
  await assert.rejects(
    validateStudyContent(broken, { rootUrl }),
    new RegExp(`Duplicate word id: ${broken.words[0].id}`),
  );
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
