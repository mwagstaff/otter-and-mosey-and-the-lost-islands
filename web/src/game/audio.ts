import { audioURL, speechURL } from "../assets";
import { Chatter, dialogueAudioKey, MouthGate, type DialogueLine, type Speaker } from "../core";
import { options } from "./options";

/** Every sound effect in the game. The names are file names in the iOS project's Resources/Audio. */
export type SFX =
  | "tap" | "nav" | "correct" | "combo" | "wrong" | "pop" | "crystal" | "star" | "jump" | "swim" | "crack" | "chirp"
  | "portal" | "guardian" | "friendship" | "levelComplete" | "unlock" | "victory" | "key" | "whoosh" | "plank";

const quiet = (promise: Promise<void> | undefined) => void promise?.catch(() => {});

/** Plays music and effects. */
class AudioManager {
  private readonly pools = new Map<SFX, HTMLAudioElement[]>();
  private music?: HTMLAudioElement;
  private track?: string;
  private fade?: number;

  constructor() {
    // Browsers refuse sound until the page has been tapped or typed on, so start the music then.
    const unlock = () => {
      if (this.music?.paused && !options.settings.muted) quiet(this.music.play());
    };
    if (typeof window !== "undefined") {
      window.addEventListener("pointerdown", unlock);
      window.addEventListener("keydown", unlock);
      document.addEventListener("visibilitychange", () => {
        if (document.hidden) this.music?.pause();
        else unlock();
      });
    }
  }

  private get musicVolume(): number {
    return options.settings.muted ? 0 : options.settings.musicVolume * 0.55;
  }

  private get effectsVolume(): number {
    return options.settings.muted ? 0 : options.settings.effectsVolume;
  }

  /** Call when the sound settings change. */
  apply(): void {
    if (!this.music) return;
    this.music.volume = this.musicVolume;
    if (options.settings.muted) this.music.pause();
    else if (this.music.paused) quiet(this.music.play());
  }

  play(effect: SFX, volume = 1): void {
    if (this.effectsVolume <= 0) return;
    let pool = this.pools.get(effect);
    if (!pool) this.pools.set(effect, (pool = []));
    let player = pool.find((each) => each.paused || each.ended);
    if (!player && pool.length < 4) {
      player = new Audio(audioURL(effect));
      pool.push(player);
    }
    if (!player) return;
    player.volume = Math.min(1, this.effectsVolume * volume);
    player.currentTime = 0;
    quiet(player.play());
  }

  /** Cross-fades to a looping music track. Passing the current track does nothing. */
  playMusic(track: string): void {
    if (track === this.track) return;
    this.track = track;
    const old = this.music;
    const next = new Audio(audioURL(track));
    next.loop = true;
    next.volume = 0;
    this.music = next;
    if (!options.settings.muted) quiet(next.play());
    window.clearInterval(this.fade);
    let step = 0;
    this.fade = window.setInterval(() => {
      step += 1;
      const progress = Math.min(step / 16, 1);
      next.volume = this.musicVolume * progress;
      if (old) old.volume = Math.max(0, old.volume * (1 - progress));
      if (progress >= 1) {
        old?.pause();
        window.clearInterval(this.fade);
      }
    }, 50);
  }
}

export const audio = new AudioManager();

/**
 * Who is speaking right now and how loudly. Scenes read this to move mouths and show the
 * speech badge; the narrator keeps it up to date.
 */
export const speechStage = {
  speaker: undefined as Speaker | undefined,
  /** Smoothed loudness from 0 to 1. */
  level: 0,
  mouthOpen: false,
};

const envelopeRate = 30;
const envelopes = new Map<string, Promise<number[]>>();

/** The loudness of a clip, 30 values a second from 0 to 1, relative to its loudest moment. */
function envelopeOf(url: string): Promise<number[]> {
  let found = envelopes.get(url);
  if (!found) {
    found = (async () => {
      const data = await (await fetch(url)).arrayBuffer();
      const decoded = await new OfflineAudioContext(1, 1, 44100).decodeAudioData(data);
      const samples = decoded.getChannelData(0);
      const window = Math.max(Math.floor(decoded.sampleRate / envelopeRate), 1);
      const result: number[] = [];
      for (let start = 0; start < samples.length; start += window) {
        const end = Math.min(start + window, samples.length);
        let sum = 0;
        for (let index = start; index < end; index += 1) sum += samples[index]! * samples[index]!;
        result.push(Math.sqrt(sum / (end - start)));
      }
      const peak = Math.max(...result, 0);
      return peak > 0 ? result.map((value) => Math.min((value / peak) * 1.3, 1)) : [];
    })().catch(() => []);
    envelopes.set(url, found);
  }
  return found;
}

/**
 * Reads questions and dialogue aloud from the recordings made for the iOS game, so it sounds
 * the same everywhere. Questions without a recording stay silent unless a grown-up has allowed
 * the device's own voice.
 */
class Narrator {
  private player?: HTMLAudioElement;
  private ticker?: number;
  private gate = new MouthGate();

  private get volume(): number {
    return options.settings.muted ? 0 : Math.min(1, Math.max(options.settings.effectsVolume, 0.3));
  }

  private get deviceVoice(): boolean {
    return options.settings.deviceVoice && typeof speechSynthesis !== "undefined";
  }

  /** Whether anything would be heard for this question. */
  canSay(key: string | undefined, fallback: string): boolean {
    return speechURL(key) !== undefined || (this.deviceVoice && fallback !== "");
  }

  private start(url: string): HTMLAudioElement {
    const clip = new Audio(url);
    clip.volume = this.volume;
    quiet(clip.play());
    this.player = clip;
    return clip;
  }

  /** Plays the narrator clip for `key`, or reads `fallback` with the device voice if that is allowed. */
  say(key: string | undefined, fallback: string): void {
    this.stop();
    if (this.volume <= 0) return;
    const url = speechURL(key);
    if (url) {
      this.start(url);
    } else if (this.deviceVoice && fallback !== "") {
      // Only questions pass fallback text; character dialogue never uses the device voice.
      const utterance = new SpeechSynthesisUtterance(fallback.replaceAll("___", "blank"));
      utterance.lang = "en-GB";
      utterance.rate = 0.85;
      utterance.pitch = 1.1;
      utterance.volume = this.volume;
      speechSynthesis.speak(utterance);
    }
  }

  stop(): void {
    this.player?.pause();
    this.player = undefined;
    if (typeof speechSynthesis !== "undefined" && speechSynthesis.speaking) speechSynthesis.cancel();
    this.endLine();
  }

  /**
   * Starts a line of dialogue: plays its recording if there is one and voices are on, and
   * either way drives `speechStage` so the speaker's mouth and badge move.
   */
  speakLine(line: DialogueLine, voiced: boolean): void {
    this.stop();
    const url = voiced && this.volume > 0 ? speechURL(dialogueAudioKey(line)) : undefined;
    // Story lines are heard but nobody on screen is talking, so the speech stage stays empty.
    if (line.speaker === "narrator") {
      if (url) this.start(url);
      return;
    }
    let length = Chatter.duration(line.text.length);
    let envelope: number[] = [];
    const clip = url ? this.start(url) : undefined;
    if (url) {
      // Follow the recording's own loudness; until it is worked out, use the made-up rhythm.
      void envelopeOf(url).then((values) => {
        if (this.player !== clip || values.length === 0) return;
        envelope = values;
        length = values.length / envelopeRate;
      });
    }
    this.gate = new MouthGate();
    const began = performance.now();
    speechStage.speaker = line.speaker;
    this.ticker = window.setInterval(() => {
      const time = clip && envelope.length > 0 ? clip.currentTime : (performance.now() - began) / 1000;
      const loudness = envelope.length > 0 ? (envelope[Math.floor(time * envelopeRate)] ?? 0) : Chatter.level(time, length);
      speechStage.level = Math.max(loudness, speechStage.level * 0.7);
      speechStage.mouthOpen = this.gate.update(loudness, time);
      if (time >= length || clip?.ended) this.endLine();
    }, 1000 / 30);
  }

  private endLine(): void {
    window.clearInterval(this.ticker);
    this.ticker = undefined;
    speechStage.speaker = undefined;
    speechStage.level = 0;
    speechStage.mouthOpen = false;
  }
}

export const narrator = new Narrator();
