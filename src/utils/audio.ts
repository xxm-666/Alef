export interface SpeakResult {
  mode: 'hebrew-tts' | 'phonetic-tts' | 'unavailable';
  voiceName?: string;
}

let cachedVoices: SpeechSynthesisVoice[] = [];

function refreshVoices(): SpeechSynthesisVoice[] {
  if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
    return [];
  }
  cachedVoices = window.speechSynthesis.getVoices();
  return cachedVoices;
}

if (typeof window !== 'undefined' && 'speechSynthesis' in window) {
  refreshVoices();
  window.speechSynthesis.addEventListener?.('voiceschanged', refreshVoices);
}

export function getHebrewVoice(): SpeechSynthesisVoice | null {
  const voices = cachedVoices.length > 0 ? cachedVoices : refreshVoices();
  return (
    voices.find((v) => {
      const lang = v.lang.toLowerCase();
      return lang === 'he-il' || lang.startsWith('he') || lang.startsWith('iw');
    }) ?? null
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

export function speakHebrew(
  hebrewText: string,
  phoneticFallback?: string,
  rate = 0.9
): SpeakResult {
  if (typeof window === 'undefined' || !('speechSynthesis' in window)) {
    return { mode: 'unavailable' };
  }

  try {
    window.speechSynthesis.cancel();
    const heVoice = getHebrewVoice();

    if (heVoice) {
      const utterance = new SpeechSynthesisUtterance(hebrewText);
      utterance.voice = heVoice;
      utterance.lang = heVoice.lang || 'he-IL';
      utterance.rate = rate;
      window.speechSynthesis.speak(utterance);
      return { mode: 'hebrew-tts', voiceName: heVoice.name };
    }

    const fallbackText = phoneticFallback || hebrewText;
    const utterance = new SpeechSynthesisUtterance(fallbackText);
    utterance.lang = phoneticFallback ? 'en-US' : 'he-IL';
    utterance.rate = rate;
    window.speechSynthesis.speak(utterance);
    return { mode: phoneticFallback ? 'phonetic-tts' : 'hebrew-tts' };
  } catch {
    return { mode: 'unavailable' };
  }
}

export function playFeedbackTone(kind: 'correct' | 'wrong' | 'flip'): void {
  if (typeof window === 'undefined') return;
  const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
  if (!AudioCtx) return;

  try {
    const ctx = new AudioCtx();
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
    osc.onended = () => {
      void ctx.close();
    };
  } catch {
    // Ignore audio context errors on restricted autoplay contexts
  }
}
