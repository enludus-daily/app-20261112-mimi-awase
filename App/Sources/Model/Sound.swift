import Foundation

/// 音の名前の書き方（設定で切り替える）
enum Notation: String, Codable, CaseIterable, Sendable, Identifiable {
    /// ド レ ミ（英語では Do Re Mi）
    case solfege
    /// C D E
    case letters

    var id: String { rawValue }
}

/// 和音の種類。段階が進むと増える
enum ChordQuality: String, Codable, CaseIterable, Sendable, Comparable {
    case major, minor, sus4, diminished, augmented, major7

    /// 根音からの半音の数
    var intervals: [Int] {
        switch self {
        case .major: [0, 4, 7]
        case .minor: [0, 3, 7]
        case .sus4: [0, 5, 7]
        case .diminished: [0, 3, 6]
        case .augmented: [0, 4, 8]
        case .major7: [0, 4, 7, 11]
        }
    }

    var symbol: String {
        switch self {
        case .major: ""
        case .minor: "m"
        case .sus4: "sus4"
        case .diminished: "dim"
        case .augmented: "aug"
        case .major7: "maj7"
        }
    }

    func name(japanese: Bool) -> String {
        switch self {
        case .major: japanese ? "長三和音" : "major"
        case .minor: japanese ? "短三和音" : "minor"
        case .sus4: japanese ? "サスフォー" : "sus4"
        case .diminished: japanese ? "減三和音" : "diminished"
        case .augmented: japanese ? "増三和音" : "augmented"
        case .major7: japanese ? "長七の和音" : "major 7th"
        }
    }

    private var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
    static func < (lhs: ChordQuality, rhs: ChordQuality) -> Bool { lhs.order < rhs.order }
}

/// 1 枚のカードが鳴らす音（実際の高さ）
enum SoundItem: Hashable, Codable, Sendable {
    /// 1 つの音（MIDI の番号。60 = 真ん中のド）
    case note(Int)
    /// 和音（根音・種類・転回。転回 1 は根音を 1 オクターブ上へ）
    case chord(root: Int, quality: ChordQuality, inversion: Int)
    /// 2 つの音を続けて鳴らす（下の音 → 上の音）
    case interval(start: Int, semitones: Int)

    /// 鳴らす音（MIDI）。interval は鳴らす順
    var midiNotes: [Int] {
        switch self {
        case .note(let m):
            return [m]
        case let .chord(root, quality, inversion):
            var notes = quality.intervals.map { root + $0 }
            for i in 0..<min(max(inversion, 0), notes.count - 1) { notes[i] += 12 }
            return notes.sorted()
        case let .interval(start, semitones):
            return [start, start + semitones]
        }
    }

    /// 和音はいっせいに、音程は順に鳴らす
    var isMelodic: Bool {
        if case .interval = self { return true }
        return false
    }
}

/// ペアの「同じ」を決めるもの。同じ Concept の 2 枚がペアになる
enum Concept: Hashable, Codable, Sendable, Comparable {
    /// 同じ高さの音
    case pitch(Int)
    /// 同じ音名（オクターブ違い）0〜11
    case pitchClass(Int)
    /// 同じ和音
    case chord(root: Int, quality: ChordQuality)
    /// 同じ音程（半音の数）
    case interval(Int)

    /// 並べる・比べるための値
    var sortKey: Int {
        switch self {
        case .pitch(let m): 0 * 10_000 + m
        case .pitchClass(let p): 1 * 10_000 + p
        case let .chord(root, quality): 2 * 10_000 + root * 10 + (ChordQuality.allCases.firstIndex(of: quality) ?? 0)
        case .interval(let s): 3 * 10_000 + s
        }
    }

    static func < (lhs: Concept, rhs: Concept) -> Bool { lhs.sortKey < rhs.sortKey }

    var mode: Mode {
        switch self {
        case .pitch: .unison
        case .pitchClass: .octave
        case .chord: .chord
        case .interval: .interval
        }
    }

    /// 2 つの Concept の「近さ」を言葉にする（取り違えの記録に使う）
    static func distance(_ a: Concept, _ b: Concept, japanese: Bool) -> String? {
        switch (a, b) {
        case let (.pitch(x), .pitch(y)):
            return MusicNames.distance(abs(x - y), japanese: japanese)
        case let (.pitchClass(x), .pitchClass(y)):
            let d = abs(x - y) % 12
            return MusicNames.distance(min(d, 12 - d), japanese: japanese)
        case let (.chord(r1, q1), .chord(r2, q2)):
            if r1 == r2 { return japanese ? "同じ根音・ちがう響き" : "same root, other color" }
            if q1 == q2 { return japanese ? "同じ響き・ちがう高さ" : "same color, other root" }
            return nil
        case let (.interval(x), .interval(y)):
            return japanese ? "幅の差 \(abs(x - y)) 半音" : "\(abs(x - y)) semitone apart"
        default:
            return nil
        }
    }
}

/// 音の名前（ドレミ・CDE・音程・和音）
enum MusicNames {
    static let solfegeJA = ["ド", "ド♯", "レ", "レ♯", "ミ", "ファ", "ファ♯", "ソ", "ソ♯", "ラ", "ラ♯", "シ"]
    static let solfegeEN = ["Do", "Do♯", "Re", "Re♯", "Mi", "Fa", "Fa♯", "Sol", "Sol♯", "La", "La♯", "Ti"]
    static let letters = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    static let intervalJA = ["同じ音", "短2度", "長2度", "短3度", "長3度", "完全4度", "増4度", "完全5度", "短6度", "長6度", "短7度", "長7度", "オクターブ"]
    static let intervalEN = ["unison", "minor 2nd", "major 2nd", "minor 3rd", "major 3rd", "perfect 4th", "tritone", "perfect 5th", "minor 6th", "major 6th", "minor 7th", "major 7th", "octave"]
    static let intervalShort = ["P1", "m2", "M2", "m3", "M3", "P4", "TT", "P5", "m6", "M6", "m7", "M7", "P8"]
    /// 覚えるための歌い出し（よく知られた曲の頭の音程の代わりに、ドレミで書く）
    static let intervalHintJA = ["", "ミ→ファ", "ド→レ", "ラ→ド", "ド→ミ", "ド→ファ", "ド→ファ♯", "ド→ソ", "ミ→ド", "ド→ラ", "ド→シ♭", "ド→シ", "ド→ド"]
    static let intervalHintEN = ["", "Mi→Fa", "Do→Re", "La→Do", "Do→Mi", "Do→Fa", "Do→Fa♯", "Do→Sol", "Mi→Do", "Do→La", "Do→Ti♭", "Do→Ti", "Do→Do"]

    static func pitchClass(_ midi: Int) -> Int { ((midi % 12) + 12) % 12 }
    static func octave(_ midi: Int) -> Int { midi / 12 - 1 }

    /// 音名（オクターブなし）
    static func name(pitchClass p: Int, notation: Notation, japanese: Bool) -> String {
        let i = ((p % 12) + 12) % 12
        switch notation {
        case .solfege: return japanese ? solfegeJA[i] : solfegeEN[i]
        case .letters: return letters[i]
        }
    }

    /// 音名（CDE のときはオクターブの数字つき。C4 = 真ん中のド）
    static func name(midi: Int, notation: Notation, japanese: Bool) -> String {
        let base = name(pitchClass: pitchClass(midi), notation: notation, japanese: japanese)
        return notation == .letters ? base + "\(octave(midi))" : base
    }

    static func interval(_ semitones: Int, japanese: Bool) -> String {
        let i = min(max(semitones, 0), 12)
        return japanese ? intervalJA[i] : intervalEN[i]
    }

    static func distance(_ semitones: Int, japanese: Bool) -> String {
        switch semitones {
        case 0: return japanese ? "同じ高さ" : "same pitch"
        case 1: return japanese ? "半音ちがい" : "a half step apart"
        case 2: return japanese ? "全音ちがい" : "a whole step apart"
        default: return japanese ? "\(semitones) 半音ちがい" : "\(semitones) half steps apart"
        }
    }

    /// カードに出す短い名前
    static func label(_ concept: Concept, notation: Notation, japanese: Bool) -> String {
        switch concept {
        case .pitch(let m):
            return name(midi: m, notation: notation, japanese: japanese)
        case .pitchClass(let p):
            return name(pitchClass: p, notation: notation, japanese: japanese)
        case let .chord(root, quality):
            let r = name(pitchClass: pitchClass(root), notation: notation, japanese: japanese)
            if notation == .letters { return r + quality.symbol }
            return r + (quality.symbol.isEmpty ? "" : " " + quality.symbol)
        case .interval(let s):
            return japanese ? intervalJA[min(max(s, 0), 12)] : intervalShort[min(max(s, 0), 12)]
        }
    }

    /// 詳しい名前（記録・聞き直しに出す）
    static func longLabel(_ concept: Concept, notation: Notation, japanese: Bool) -> String {
        switch concept {
        case .pitch, .pitchClass:
            return label(concept, notation: notation, japanese: japanese)
        case let .chord(root, quality):
            let r = name(pitchClass: pitchClass(root), notation: notation, japanese: japanese)
            return japanese ? "\(r)の\(quality.name(japanese: true))" : "\(r) \(quality.name(japanese: false))"
        case .interval(let s):
            let hint = japanese ? intervalHintJA[min(max(s, 0), 12)] : intervalHintEN[min(max(s, 0), 12)]
            return interval(s, japanese: japanese) + (hint.isEmpty ? "" : "（\(hint)）")
        }
    }

    /// 周波数（A4 = 440Hz）
    static func frequency(midi: Int) -> Double {
        440 * pow(2, Double(midi - 69) / 12)
    }
}
