import { Capacitor, registerPlugin } from '@capacitor/core';
import { AUDIO_FILE_MAP, HUMAN_AUDIO_KEYS } from '../data/audioManifest';

export interface SpeakResult {
  mode: 'recorded' | 'hebrew-tts' | 'phonetic-tts' | 'unavailable';
  voiceName?: string;
}

interface NativePronunciationPlugin {
  play(options: { filename: string; rate: number }): Promise<void>;
  stop(): Promise<void>;
}

const nativePronunciation = registerPlugin<NativePronunciationPlugin>('AlefPronunciation');
const isIOSApp = Capacitor.getPlatform() === 'ios';

let cachedVoices: SpeechSynthesisVoice[] = [];
let activeUtterance: SpeechSynthesisUtterance | null = null;
let speakTimer: number | null = null;
let sharedAudioCtx: AudioContext | null = null;
let currentClip: HTMLAudioElement | null = null;
let nativePlayback: Promise<void> | null = null;
const activeTones = new Set<OscillatorNode>();

function updateAudioSession(): void {
  try {
    const session = (navigator as Navigator & { audioSession?: { type: string } }).audioSession;
    if (session) {
      session.type = currentClip || activeUtterance || activeTones.size ? 'playback' : 'auto';
    }
  } catch {
    // Older WebKit versions do not support switching audio session types.
  }
}

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
  const finish = () => {
    if (activeUtterance === utterance) {
      activeUtterance = null;
      updateAudioSession();
    }
  };
  utterance.onend = finish;
  utterance.onerror = finish;
  updateAudioSession();

  try {
    if (synth.paused) synth.resume();
    synth.speak(utterance);
  } catch (error) {
    finish();
    throw error;
  }
}

function clearSpeakTimer(): void {
  if (speakTimer !== null) {
    window.clearTimeout(speakTimer);
    speakTimer = null;
  }
}

function cancelUtterance(): void {
  if (!activeUtterance) return;
  activeUtterance = null;
  updateAudioSession();
  window.speechSynthesis.cancel();
}

function stopClip(): void {
  if (nativePlayback) {
    nativePlayback = null;
    void nativePronunciation.stop().catch(() => {});
  }
  if (!currentClip) return;
  const clip = currentClip;
  currentClip = null;
  clip.pause();
  clip.removeAttribute('src');
  clip.load();
  updateAudioSession();
}

/** 优先播放内置的真人 / 神经网络录音；成功发起播放返回 true。 */
function playRecordedClip(hebrewText: string, rate: number, onFail: () => void): boolean {
  const rel = AUDIO_FILE_MAP[hebrewText.trim()];
  if (!rel) return false;
  const safeRate = Math.max(0.5, Math.min(1.5, Number.isFinite(rate) ? rate : 1));
  if (isIOSApp && Capacitor.isPluginAvailable('AlefPronunciation')) {
    cancelUtterance();
    const pending = nativePronunciation.play({ filename: rel.slice(rel.lastIndexOf('/') + 1), rate: safeRate });
    nativePlayback = pending;
    void pending.then(() => {
      if (nativePlayback === pending) nativePlayback = null;
    }, () => {
      if (nativePlayback !== pending) return;
      nativePlayback = null;
      onFail();
    });
    return true;
  }
  if (typeof Audio === 'undefined') return false;
  try {
    cancelUtterance();
    const clip = new Audio(new URL(rel, document.baseURI).toString());
    clip.playbackRate = safeRate;
    clip.preservesPitch = true;
    currentClip = clip;
    updateAudioSession();
    const fallback = () => {
      if (currentClip !== clip) return;
      stopClip();
      onFail();
    };
    clip.addEventListener('error', fallback);
    clip.addEventListener('ended', () => {
      if (currentClip === clip) stopClip();
    });
    void clip.play().catch(fallback);
    return true;
  } catch {
    stopClip();
    return false;
  }
}

export function speakHebrew(
  hebrewText: string,
  phoneticFallback?: string,
  rate = 0.9
): SpeakResult {
  if (typeof window === 'undefined' || (isIOSApp && document.hidden)) return { mode: 'unavailable' };
  stopClip();
  clearSpeakTimer();

  const recorded = playRecordedClip(hebrewText, rate, () =>
    speakWithSynthesis(hebrewText, phoneticFallback, rate)
  );
  if (recorded) {
    return {
      mode: 'recorded',
      voiceName: HUMAN_AUDIO_KEYS.has(hebrewText.trim()) ? '真人录音' : '以色列神经网络语音',
    };
  }
  return speakWithSynthesis(hebrewText, phoneticFallback, rate);
}

function speakWithSynthesis(
  hebrewText: string,
  phoneticFallback?: string,
  rate = 0.9
): SpeakResult {
  if ((isIOSApp && document.hidden) || !('speechSynthesis' in window)) {
    return { mode: 'unavailable' };
  }

  try {
    const synth = window.speechSynthesis;

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
      cancelUtterance();
      speakTimer = window.setTimeout(() => {
        speakTimer = null;
        try {
          dispatchUtterance(utterance);
        } catch {
          // Playback is no longer available.
        }
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
  if (typeof window === 'undefined' || (isIOSApp && document.hidden)) return;
  try {
    const ctx = getAudioContext();
    if (!ctx) return;

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
    activeTones.add(osc);
    osc.onended = () => {
      osc.disconnect();
      gain.disconnect();
      activeTones.delete(osc);
      if (activeTones.size === 0) void ctx.suspend().catch(() => {});
      updateAudioSession();
    };
    updateAudioSession();
    void ctx.resume().catch(() => {});
  } catch {
    // Ignore audio context errors on restricted autoplay contexts
  }
}

function stopPageAudio(): void {
  stopClip();
  clearSpeakTimer();
  cancelUtterance();
  for (const tone of activeTones) {
    tone.disconnect();
    tone.stop();
  }
  activeTones.clear();
  if (sharedAudioCtx) void sharedAudioCtx.suspend().catch(() => {});
  updateAudioSession();
}

if (typeof window !== 'undefined') {
  window.addEventListener('pagehide', stopPageAudio);
  if (isIOSApp) {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) stopPageAudio();
    });
  }
}
