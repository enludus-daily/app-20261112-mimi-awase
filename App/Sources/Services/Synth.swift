import AVFoundation
import Foundation

/// 音色（音はその場で合成する。音源のファイルは持たない）
enum Timbre: String, Codable, CaseIterable, Sendable, Identifiable {
    case piano, soft, musicBox, marimba

    var id: String { rawValue }
    var isPro: Bool { self == .musicBox || self == .marimba }

    func name(japanese: Bool) -> String {
        switch self {
        case .piano: japanese ? "ピアノ" : "Piano"
        case .soft: japanese ? "やわらか" : "Soft"
        case .musicBox: japanese ? "オルゴール" : "Music box"
        case .marimba: japanese ? "マリンバ" : "Marimba"
        }
    }

    /// 倍音の強さと、消える速さ（1 秒あたり）
    var partials: [(ratio: Double, amp: Double, decay: Double)] {
        switch self {
        case .piano: [(1, 1.0, 2.2), (2, 0.42, 3.4), (3, 0.2, 4.6), (4, 0.1, 6.0), (5, 0.05, 7.5)]
        case .soft: [(1, 1.0, 1.6), (2, 0.12, 2.6), (3, 0.03, 3.4)]
        case .musicBox: [(1, 1.0, 3.0), (3.01, 0.32, 6.0), (5.4, 0.12, 9.0), (8.9, 0.05, 12.0)]
        case .marimba: [(1, 1.0, 4.0), (3.93, 0.28, 9.0), (9.2, 0.05, 16.0)]
        }
    }

    var attack: Double { self == .soft ? 0.03 : 0.004 }
}

/// 音の波形を作る（AVFoundation に触れない純粋な計算。テストできる）
enum ToneRenderer {
    static let sampleRate = 44_100.0
    /// interval の 2 音目を鳴らすまでの間
    static let melodicGap = 0.42

    static func duration(of sound: SoundItem) -> Double {
        sound.isMelodic ? melodicGap + 1.1 : 1.2
    }

    static func render(_ sound: SoundItem, timbre: Timbre) -> [Float] {
        let total = Int(duration(of: sound) * sampleRate)
        var out = [Float](repeating: 0, count: total)
        let notes = sound.midiNotes
        for (i, midi) in notes.enumerated() {
            let offset = sound.isMelodic ? Int(Double(i) * melodicGap * sampleRate) : 0
            // 和音は少しだけずらして、やわらかく
            let strum = sound.isMelodic ? 0 : Int(Double(i) * 0.012 * sampleRate)
            add(note: midi, into: &out, from: offset + strum, timbre: timbre, gain: sound.isMelodic ? 1 : 1 / Double(notes.count).squareRoot())
        }
        // 大きすぎる所を抑える
        let peak = out.reduce(0) { max($0, abs($1)) }
        if peak > 0.9 { let k = 0.9 / peak; for i in out.indices { out[i] *= k } }
        return out
    }

    static func add(note midi: Int, into out: inout [Float], from start: Int, timbre: Timbre, gain: Double) {
        let f = MusicNames.frequency(midi: midi)
        let partials = timbre.partials
        let ampSum = partials.reduce(0) { $0 + $1.amp }
        let attackSamples = max(1, timbre.attack * sampleRate)
        let release = 0.08 * sampleRate
        guard start < out.count else { return }
        let length = out.count - start
        for n in 0..<length {
            let t = Double(n) / sampleRate
            var v = 0.0
            for p in partials where f * p.ratio < 9_000 {
                v += p.amp * exp(-p.decay * t) * sin(2 * .pi * f * p.ratio * t)
            }
            var env = min(1, Double(n) / attackSamples)
            let remaining = Double(length - n)
            if remaining < release { env *= remaining / release }
            out[start + n] += Float(v / ampSum * env * gain * 0.6)
        }
    }

    /// そろったときの小さな鈴（連続ほど高く）
    static func chime(level: Int) -> SoundItem {
        .note(84 + [0, 4, 7, 12, 16][min(max(level - 1, 0), 4)])
    }
}

/// 音を鳴らす。画面の操作から呼ぶ（メインスレッド）
@MainActor
final class Synth {
    var timbre: Timbre = .piano
    /// 0〜1
    var volume: Float = 0.55 { didSet { engine.mainMixerNode.outputVolume = volume } }
    var enabled = true

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let format = AVAudioFormat(standardFormatWithSampleRate: ToneRenderer.sampleRate, channels: 1)
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var started = false

    init() {}

    private func startIfNeeded() -> Bool {
        if started { return true }
        guard let format else { return false }
        do {
            // 音そのものが遊びの入力なので、消音スイッチでも鳴らす（音楽アプリと同じ）。ほかのアプリの音とは混ぜる
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            for _ in 0..<6 {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                players.append(player)
            }
            engine.mainMixerNode.outputVolume = volume
            try engine.start()
            started = true
        } catch {
            started = false
        }
        return started
    }

    func play(_ sound: SoundItem, gain: Float = 1) {
        guard enabled, startIfNeeded(), let buffer = buffer(for: sound), !players.isEmpty else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = gain
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        player.play()
    }

    func chime(level: Int) {
        play(ToneRenderer.chime(level: level), gain: 0.35)
    }

    /// 終わったときに、そろえた音を順に鳴らす
    func arpeggio(_ sounds: [SoundItem]) {
        for (i, sound) in sounds.prefix(6).enumerated() {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(140 * i))
                self?.play(sound, gain: 0.5)
            }
        }
    }

    /// よく使う音を先に作っておく（最初の 1 枚の遅れをなくす）
    func prepare(_ sounds: [SoundItem]) {
        for sound in sounds { _ = buffer(for: sound) }
    }

    private func buffer(for sound: SoundItem) -> AVAudioPCMBuffer? {
        let key = "\(timbre.rawValue)|\(sound)"
        if let cached = cache[key] { return cached }
        guard let format else { return nil }
        let samples = ToneRenderer.render(sound, timbre: timbre)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { src in
            channel.update(from: src.baseAddress!, count: samples.count)
        }
        if cache.count > 200 { cache.removeAll() }
        cache[key] = buffer
        return buffer
    }
}
