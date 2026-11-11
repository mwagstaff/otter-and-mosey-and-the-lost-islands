import AVFoundation
import CoreHaptics
import LostIslandsCore
import Observation
import UIKit

/// Every sound effect in the game. Raw values are file names in Resources/Audio.
enum SFX: String, CaseIterable {
    case tap, nav, correct, combo, wrong, pop, crystal, star, jump, swim, crack, chirp
    case portal, guardian, friendship, levelComplete, unlock, victory, key, whoosh, plank
}

/// Plays music and effects. Uses the ambient audio session, so the ring/silent switch
/// mutes the game and other apps' audio keeps playing.
final class AudioManager {
    static let shared = AudioManager()

    private var pools: [SFX: [AVAudioPlayer]] = [:]
    private var music: AVAudioPlayer?
    private var currentTrack: String?
    private var settings = AppSettings()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            let ended = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) == AVAudioSession.InterruptionType.ended.rawValue
            Task { @MainActor in AudioManager.shared.interruption(ended: ended) }
        }
    }

    private func interruption(ended: Bool) {
        if ended {
            try? AVAudioSession.sharedInstance().setActive(true)
            if !settings.muted { music?.play() }
        } else {
            music?.pause()
        }
    }

    func apply(_ settings: AppSettings) {
        self.settings = settings
        music?.volume = musicVolume
        if settings.muted { music?.pause() } else if music?.isPlaying == false { music?.play() }
    }

    private var musicVolume: Float { settings.muted ? 0 : Float(settings.musicVolume) * 0.55 }
    private var effectsVolume: Float { settings.muted ? 0 : Float(settings.effectsVolume) }

    private static func url(_ name: String) -> URL? {
        for ext in ["m4a", "wav", "mp3", "caf"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }

    func play(_ effect: SFX, volume: Float = 1) {
        guard effectsVolume > 0 else { return }
        var pool = pools[effect] ?? []
        var player = pool.first { !$0.isPlaying }
        if player == nil, pool.count < 4, let url = Self.url(effect.rawValue), let made = try? AVAudioPlayer(contentsOf: url) {
            made.prepareToPlay()
            pool.append(made)
            pools[effect] = pool
            player = made
        }
        guard let player else { return }
        player.volume = effectsVolume * volume
        player.currentTime = 0
        player.play()
    }

    /// Cross-fades to a looping music track. Passing the current track does nothing.
    func playMusic(_ track: String) {
        guard track != currentTrack else { return }
        currentTrack = track
        let old = music
        old?.setVolume(0, fadeDuration: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { old?.stop() }
        guard let url = Self.url(track), let player = try? AVAudioPlayer(contentsOf: url) else {
            music = nil
            return
        }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        if !settings.muted { player.play() }
        player.setVolume(musicVolume, fadeDuration: 0.8)
        music = player
    }

    func pauseForBackground() { music?.pause() }

    func resumeFromBackground() {
        if !settings.muted { music?.play() }
    }
}

/// Who is speaking right now and how loudly. Scenes and the dialogue panel read this to
/// move mouths and show the speech badge; `Narrator` keeps it up to date.
@Observable
final class SpeechStage {
    static let shared = SpeechStage()
    var speaker: Speaker?
    /// Smoothed loudness from 0 to 1.
    var level = 0.0
    var mouthOpen = false
}

/// Reads questions aloud. Uses the pre-recorded narrator clips bundled with the game
/// (Resources/Speech), so it works offline and sounds the same on every device. Questions
/// without a recording stay silent unless the grown-up has allowed the device's own voice.
final class Narrator {
    static let shared = Narrator()
    private var player: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private let voice = AVSpeechSynthesisVoice(language: "en-GB")
    var volume: Float = 0.9
    /// Allow the built-in system voice for questions with no narrator recording.
    var deviceVoice = false

    static func clipURL(_ key: String) -> URL? {
        Bundle.main.url(forResource: "say_\(key)", withExtension: "mp3")
    }

    /// Whether anything would be heard for this question.
    func canSay(key: String?, fallback: String) -> Bool {
        if let key, Self.clipURL(key) != nil { return true }
        return deviceVoice && !fallback.isEmpty
    }

    /// Plays the narrator clip for `key`, or reads `fallback` with the device voice if that is allowed.
    func say(key: String?, fallback: String) {
        stop()
        guard volume > 0 else { return }
        if let key, let url = Self.clipURL(key), let clip = try? AVAudioPlayer(contentsOf: url) {
            clip.volume = volume
            clip.play()
            player = clip
        } else if deviceVoice, !fallback.isEmpty {
            // Only questions pass fallback text; character dialogue never uses the device voice.
            let utterance = AVSpeechUtterance(string: fallback.replacingOccurrences(of: "___", with: "blank"))
            utterance.voice = voice
            utterance.rate = 0.42
            utterance.pitchMultiplier = 1.1
            utterance.volume = volume
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        endLine()
    }

    // MARK: - Character dialogue

    private var gate = MouthGate()
    private var ticker: Timer?
    private var lineStart = Date()
    /// How long the current line lasts: the recording's length, or the made-up rhythm's.
    private var chatterLength = 0.0

    /// Starts a line of dialogue: plays its recording if there is one and voices are on, and
    /// either way drives `SpeechStage` so the speaker's mouth and badge move.
    func speakLine(_ line: DialogueLine, voiced: Bool) {
        stop()
        guard line.speaker != .narrator else { return }
        chatterLength = Chatter.duration(forTextLength: line.text.count)
        envelope = []
        if voiced, volume > 0, let key = line.audioKey, let url = Self.clipURL(key), let clip = try? AVAudioPlayer(contentsOf: url) {
            clip.volume = volume
            clip.play()
            player = clip
            envelope = Self.envelope(of: url)
            if !envelope.isEmpty { chatterLength = Double(envelope.count) / Self.envelopeRate }
        }
        gate = MouthGate()
        lineStart = Date()
        SpeechStage.shared.speaker = line.speaker
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { _ in
            MainActor.assumeIsolated { Narrator.shared.tick() }
        }
    }

    private func tick() {
        let time = Date().timeIntervalSince(lineStart)
        let loudness: Double
        if envelope.isEmpty {
            loudness = Chatter.level(at: time, duration: chatterLength)
        } else {
            // Follow the recording's own loudness, read from the file rather than from live
            // metering, so it behaves the same on every device and in the simulator.
            let index = Int(time * Self.envelopeRate)
            loudness = envelope.indices.contains(index) ? envelope[index] : 0
        }
        let stage = SpeechStage.shared
        stage.level = max(loudness, stage.level * 0.7)
        stage.mouthOpen = gate.update(level: loudness, at: time)
        if time >= chatterLength { endLine() }
    }

    private var envelope: [Double] = []
    private static let envelopeRate = 30.0
    private static var envelopes: [URL: [Double]] = [:]

    /// The loudness of a clip, 30 values a second from 0 to 1, relative to its loudest moment.
    static func envelope(of url: URL) -> [Double] {
        if let cached = envelopes[url] { return cached }
        var result: [Double] = []
        if let file = try? AVAudioFile(forReading: url),
           let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
           (try? file.read(into: buffer)) != nil, let samples = buffer.floatChannelData?[0] {
            let window = max(Int(file.processingFormat.sampleRate / envelopeRate), 1)
            let count = Int(buffer.frameLength)
            var start = 0
            while start < count {
                let end = min(start + window, count)
                var sum: Float = 0
                for index in start..<end { sum += samples[index] * samples[index] }
                result.append(Double((sum / Float(end - start)).squareRoot()))
                start = end
            }
            let peak = result.max() ?? 0
            result = peak > 0 ? result.map { min($0 / peak * 1.3, 1) } : []
        }
        envelopes[url] = result
        return result
    }

    private func endLine() {
        ticker?.invalidate()
        ticker = nil
        let stage = SpeechStage.shared
        if stage.speaker != nil { stage.speaker = nil }
        stage.level = 0
        stage.mouthOpen = false
    }
}

/// Light, optional touch feedback. Nothing in the game depends on it.
final class Haptics {
    static let shared = Haptics()
    var enabled = true
    private var engine: CHHapticEngine?
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notify = UINotificationFeedbackGenerator()

    private init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        engine = try? CHHapticEngine()
        engine?.isAutoShutdownEnabled = true
    }

    func tap() { if enabled { light.impactOccurred() } }
    func nudge() { if enabled { soft.impactOccurred(intensity: 0.7) } }
    func success() { if enabled { notify.notificationOccurred(.success) } }

    /// A rising rumble for Friendship Power and big finales.
    func crescendo() {
        guard enabled, let engine else { return }
        var events: [CHHapticEvent] = []
        for step in 0..<8 {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25 + Float(step) * 0.09)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3 + Float(step) * 0.07)
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: Double(step) * 0.09))
        }
        events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
        ], relativeTime: 0.75, duration: 0.35))
        do {
            try engine.start()
            try engine.makePlayer(with: CHHapticPattern(events: events, parameters: [])).start(atTime: CHHapticTimeImmediate)
        } catch {
            // Haptics are a nicety; ignore failures.
        }
    }
}
