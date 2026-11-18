export interface SpeakResult {
  mode: 'hebrew-tts' | 'phonetic-tts' | 'unavailable';
  voiceName?: string;
}

let cachedVoices: SpeechSynthesisVoice[] = [];
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
