import { AUDIO_FILE_MAP } from '../data/audioManifest';
import { HEBREW_LETTERS } from '../data/hebrewLetters';
import { HEBREW_PHRASES } from '../data/hebrewPhrases';
import { HEBREW_READINGS } from '../data/hebrewReadings';
import { HEBREW_WORDS } from '../data/hebrewWords';

const packTexts = [
  ...HEBREW_LETTERS.map((letter) => letter.nameHebrew),
  ...HEBREW_WORDS.map((word) => word.hebrew),
  ...HEBREW_PHRASES.map((phrase) => phrase.hebrew),
  ...HEBREW_READINGS.flatMap((reading) => reading.sentences.map((sentence) => sentence.hebrew)),
];

const recordedPaths = new Map(Object.entries(AUDIO_FILE_MAP).map(([text, path]) => [text.normalize('NFC'), path]));
const packPaths = [...new Set(packTexts.flatMap((text) => recordedPaths.get(text.normalize('NFC')) ?? []))];
export const offlineAudioCount = packPaths.length;

export function canDownloadOfflineAudio() {
  return 'caches' in window && 'serviceWorker' in navigator;
}

async function getPack() {
  const base = new URL('.', document.baseURI);
  const cache = await caches.open(`alef-offline-audio-v1:${base.pathname}`);
  const urls = packPaths.map((path) => new URL(path, base).href);
  const entries = await Promise.all(urls.map(async (url) => ({ url, cached: Boolean(await cache.match(url)) })));
  return { cache, missing: entries.filter(({ cached }) => !cached).map(({ url }) => url) };
}

export async function getOfflineAudioProgress() {
  const { missing } = await getPack();
  return offlineAudioCount - missing.length;
}

export async function downloadOfflineAudio(onProgress: (completed: number) => void) {
  const { cache, missing } = await getPack();
  let completed = offlineAudioCount - missing.length;
  onProgress(completed);

  for (const url of missing) {
    const response = await fetch(url, { cache: 'no-store' });
    if (response.status !== 200 || !response.headers.get('content-type')?.startsWith('audio/')) {
      throw new Error('Audio download failed');
    }
    await cache.put(url, response);
    completed += 1;
    onProgress(completed);
  }
}
