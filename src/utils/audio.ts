export interface SpeakResult {
  mode: 'hebrew-tts' | 'phonetic-tts' | 'unavailable';
  voiceName?: string;
}

let cachedVoices: SpeechSynthesisVoice[] = [];

/**
 * iOS Safari 默认把网页音频(Web Audio / speechSynthesis)归为“环境音”,
 * 会被静音键静音。将音频会话切到 "playback" 类别即可无视静音键。
 */
let silentAudio: HTMLAudioElement | null = null;
let unlocked = false;

function buildSilentWavUrl(): string {
  const sampleRate = 8000;
  const samples = 800; // 0.1s
  const buffer = new ArrayBuffer(44 + samples * 2);
  const v = new DataView(buffer);
  const w = (o: number, s: string) => [...s].forEach((c, i) => v.setUint8(o + i, c.charCodeAt(0)));
  w(0, 'RIFF');
  v.setUint32(4, 36 + samples * 2, true);
  w(8, 'WAVE');
  w(12, 'fmt ');
  v.setUint32(16, 16, true);
  v.setUint16(20, 1, true);
  v.setUint16(22, 1, true);
  v.setUint32(24, sampleRate, true);
  v.setUint32(28, sampleRate * 2, true);
  v.setUint16(32, 2, true);
  v.setUint16(34, 16, true);
  w(36, 'data');
  v.setUint32(40, samples * 2, true);
  return URL.createObjectURL(new Blob([buffer], { type: 'audio/wav' }));
}

export function unlockAudio(): void {
  if (typeof window === 'undefined') return;
  try {
    const session = (navigator as unknown as { audioSession?: { type: string } }).audioSession;
    if (session) session.type = 'playback';
  } catch {
    // ignore
  }
  const ctx = getAudioContext();
  if (ctx && ctx.state === 'suspended') void ctx.resume();
  if (unlocked) return;
  try {
    silentAudio = new Audio(buildSilentWavUrl());
    silentAudio.setAttribute('playsinline', '');
    silentAudio.loop = true;
    silentAudio.volume = 0.01;
    void silentAudio
      .play()
      .then(() => {
        unlocked = true;
      })
      .catch(() => {
        // 需要用户手势,下次交互再试
      });
  } catch {
    // ignore
  }
}

if (typeof window !== 'undefined') {
  const handler = () => {
    unlockAudio();
    if (unlocked) {
      window.removeEventListener('touchend', handler, true);
      window.removeEventListener('pointerdown', handler, true);
      window.removeEventListener('click', handler, true);
    }
  };
  window.addEventListener('touchend', handler, true);
  window.addEventListener('pointerdown', handler, true);
  window.addEventListener('click', handler, true);
}
let activeUtterance: SpeechSynthesisUtterance | null = null;
let speakTimer: number | null = null;
let sharedAudioCtx: AudioContext | null = null;

function refreshVoices(): SpeechSynthesisVoice[] {
  if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
    return [];
  }
  const voices = window.speechSynthesis.getVoices();
  if (voices.length > 0) {
    cachedVoices = voices;
  }
  return cachedVoices;
}

if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
  refreshVoices();
  window.speechSynthesis.addEventListener?.('voiceschanged', refreshVoices);
}

export function getHebrewVoice(): SpeechSynthesisVoice | null {
  const voices = refreshVoices();
  return (
    voices.find((v) => {
      const lang = v.lang.toLowerCase();
      return lang === 'he-il' || lang.startsWith('he') || lang.startsWith('iw');
    }) ?? null
  );
}

function getEnglishFallbackVoice(): SpeechSynthesisVoice | null {
  const voices = refreshVoices();
  return (
    voices.find((v) => v.lang.toLowerCase() === 'en-us') ??
    voices.find((v) => v.lang.toLowerCase().startsWith('en')) ??
    voices[0] ??
    null
  );
}

export function getSpeechStatus(): { available: boolean; hasHebrewVoice: boolean; voiceName?: string } {
  if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
    return { available: false, hasHebrewVoice: false };
  }
  const heVoice = getHebrewVoice();
  return {
    available: true,
    hasHebrewVoice: Boolean(heVoice),
    voiceName: heVoice?.name,
  };
}

function dispatchUtterance(utterance: SpeechSynthesisUtterance): void {
  const synth = window.speechSynthesis;
  activeUtterance = utterance;
  utterance.onend = () => {
    if (activeUtterance === utterance) {
      activeUtterance = null;
    }
  };
  utterance.onerror = () => {
    if (activeUtterance === utterance) {
      activeUtterance = null;
    }
  };

  if (synth.paused) {
    synth.resume();
  }
  synth.speak(utterance);
}

export function speakHebrew(
  hebrewText: string,
  phoneticFallback?: string,
  rate = 0.9
): SpeakResult {
  if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
    return { mode: 'unavailable' };
  }

  try {
    unlockAudio();
    const synth = window.speechSynthesis;
    if (speakTimer !== null) {
      window.clearTimeout(speakTimer);
      speakTimer = null;
    }

    const voices = refreshVoices();
    const heVoice = getHebrewVoice();
    const safeRate = Math.max(0.5, Math.min(1.5, Number.isFinite(rate) ? rate : 0.9));

    let utterance: SpeechSynthesisUtterance;
    let result: SpeakResult;

    if (heVoice) {
      utterance = new SpeechSynthesisUtterance(hebrewText);
      utterance.voice = heVoice;
      utterance.lang = heVoice.lang || 'he-IL';
      result = { mode: 'hebrew-tts', voiceName: heVoice.name };
    } else if (voices.length === 0) {
      // On iOS Safari / PWA, getVoices() may be empty on first tap even though he-IL is built in
      utterance = new SpeechSynthesisUtterance(hebrewText);
      utterance.lang = 'he-IL';
      result = { mode: 'hebrew-tts' };
    } else {
      const fallbackText = phoneticFallback || hebrewText;
      utterance = new SpeechSynthesisUtterance(fallbackText);
      if (phoneticFallback) {
        const enVoice = getEnglishFallbackVoice();
        if (enVoice) utterance.voice = enVoice;
        utterance.lang = enVoice?.lang || 'en-US';
        result = { mode: 'phonetic-tts', voiceName: enVoice?.name };
      } else {
        utterance.lang = 'he-IL';
        result = { mode: 'hebrew-tts' };
      }
    }

    utterance.rate = safeRate;
    utterance.volume = 1;

    // Avoid calling cancel() synchronously before speak() when idle, as iOS WebKit / Chromium
    // can silently drop the newly queued utterance.
    if (synth.speaking || synth.pending) {
      synth.cancel();
      speakTimer = window.setTimeout(() => {
        speakTimer = null;
        dispatchUtterance(utterance);
      }, 45);
    } else {
      dispatchUtterance(utterance);
    }

    return result;
  } catch {
    return { mode: 'unavailable' };
  }
}

function getAudioContext(): AudioContext | null {
  if (typeof window === 'undefined') return null;
  if (sharedAudioCtx && sharedAudioCtx.state !== 'closed') {
    return sharedAudioCtx;
  }
  const AudioCtx =
    window.AudioContext ||
    (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AudioCtx) return null;
  sharedAudioCtx = new AudioCtx();
  return sharedAudioCtx;
}

export function playFeedbackTone(kind: 'correct' | 'wrong' | 'flip'): void {
  try {
    unlockAudio();
    const ctx = getAudioContext();
    if (!ctx) return;

    if (ctx.state === 'suspended') {
      void ctx.resume();
    }

    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);

    const now = ctx.currentTime;
    if (kind === 'correct') {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(523.25, now);
      osc.frequency.exponentialRampToValueAtTime(783.99, now + 0.12);
      gain.gain.setValueAtTime(0.08, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.22);
      osc.start(now);
      osc.stop(now + 0.22);
    } else if (kind === 'wrong') {
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(240, now);
      osc.frequency.exponentialRampToValueAtTime(175, now + 0.18);
      gain.gain.setValueAtTime(0.07, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.2);
      osc.start(now);
      osc.stop(now + 0.2);
    } else {
      osc.type = 'sine';
      osc.frequency.setValueAtTime(420, now);
      gain.gain.setValueAtTime(0.03, now);
      gain.gain.exponentialRampToValueAtTime(0.001, now + 0.08);
      osc.start(now);
      osc.stop(now + 0.08);
    }
  } catch {
    // Ignore audio context errors on restricted autoplay contexts
  }
}
