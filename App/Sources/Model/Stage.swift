import Foundation

/// 遊び方（聞き分けるものの種類）
enum Mode: String, Codable, CaseIterable, Sendable, Identifiable {
    case unison, octave, chord, interval

    var id: String { rawValue }

    func title(japanese: Bool) -> String {
        switch self {
        case .unison: japanese ? "同じ音" : "Same note"
        case .octave: japanese ? "オクターブ" : "Octaves"
        case .chord: japanese ? "和音" : "Chords"
        case .interval: japanese ? "音程" : "Intervals"
        }
    }

    func rule(japanese: Bool) -> String {
        switch self {
        case .unison: japanese ? "同じ高さの音を 2 枚そろえる" : "Pair two cards of the same pitch"
        case .octave: japanese ? "高さはちがっても、同じ音名ならペア" : "Same note name, one octave apart"
        case .chord: japanese ? "同じ響きの和音を 2 枚そろえる" : "Pair two cards of the same chord"
        case .interval: japanese ? "2 つの音の幅が同じならペア" : "Same distance between two notes"
        }
    }

    /// 無料で遊べる段階（chord・interval は最初の 3 段階だけ無料）
    var freeStages: Int {
        switch self {
        case .unison, .octave: Stage.perMode
        case .chord, .interval: 3
        }
    }
}

/// 1 つの段階（手で決めた表。各モード 15 段階、全部で 60）
struct Stage: Identifiable, Hashable, Sendable {
    static let perMode = 15

    let mode: Mode
    /// 1 から
    let number: Int

    var id: String { "\(mode.rawValue)-\(number)" }
    var isFree: Bool { number <= mode.freeStages }

    var pairs: Int {
        let table: [Int]
        switch mode {
        case .unison: table = [2, 3, 3, 4, 4, 4, 6, 6, 6, 8, 8, 8, 10, 12, 12]
        case .octave: table = [2, 3, 3, 4, 4, 5, 5, 6, 6, 6, 8, 8, 10, 12, 12]
        case .chord: table = [2, 3, 3, 4, 4, 4, 6, 6, 6, 8, 8, 8, 10, 10, 12]
        case .interval: table = [2, 3, 3, 4, 4, 4, 5, 6, 6, 6, 8, 8, 10, 12, 12]
        }
        return table[index]
    }

    /// 音どうしのいちばん狭い間（半音）。小さいほど似た音が並ぶ
    var gap: Int {
        switch mode {
        case .unison: return [5, 4, 3, 3, 2, 2, 3, 2, 2, 2, 1, 1, 1, 1, 1][index]
        case .octave: return [4, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1][index]
        case .chord: return [3, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1][index]
        case .interval: return 1
        }
    }

    /// 和音で使う種類
    var qualities: [ChordQuality] {
        switch number {
        case 1...6: [.major, .minor]
        case 7...9: [.major, .minor, .sus4]
        case 10...12: [.major, .minor, .sus4, .diminished, .augmented]
        default: ChordQuality.allCases
        }
    }

    /// 和音の転回を混ぜるか（最後の 3 段階。同じ和音でも並びがちがう）
    var invertsChords: Bool { mode == .chord && number >= 13 }

    /// 音程で使う幅（半音）
    var intervals: [Int] {
        switch number {
        case 1: [12, 7]
        case 2...3: [12, 7, 4]
        case 4...6: [12, 7, 5, 4, 3]
        case 7...9: [12, 9, 7, 5, 4, 3, 2]
        case 10...12: [12, 11, 10, 9, 8, 7, 5, 4, 3, 2, 1]
        default: Array(1...12)
        }
    }

    /// 似た音を寄せる強さ（0 = ばらばら、大きいほど狭い範囲に集める）
    var crowding: Int { min(3, (number - 1) / 4) }

    private var index: Int { min(max(number - 1, 0), Stage.perMode - 1) }

    var spec: BoardSpec {
        BoardSpec(mode: mode, pairs: pairs, gap: gap, crowding: crowding,
                  qualities: qualities, intervals: intervals, invertsChords: invertsChords)
    }

    static func all(_ mode: Mode) -> [Stage] { (1...perMode).map { Stage(mode: mode, number: $0) } }
    static var allStages: [Stage] { Mode.allCases.flatMap { all($0) } }

    static func find(_ id: String) -> Stage? { allStages.first { $0.id == id } }

    var next: Stage? {
        if number < Stage.perMode { return Stage(mode: mode, number: number + 1) }
        guard let i = Mode.allCases.firstIndex(of: mode), i + 1 < Mode.allCases.count else { return nil }
        return Stage(mode: Mode.allCases[i + 1], number: 1)
    }
}

/// 盤の作り方
struct BoardSpec: Hashable, Sendable {
    var mode: Mode
    var pairs: Int
    var gap: Int
    var crowding: Int
    var qualities: [ChordQuality] = [.major, .minor]
    var intervals: [Int] = [12, 7, 4]
    var invertsChords = false

    /// 今日の盤（曜日でモードが変わる。中くらいの難しさ）
    static func daily(for date: Date, calendar: Calendar) -> BoardSpec {
        let weekday = calendar.component(.weekday, from: date) // 1 = 日曜
        let modes: [Mode] = [.octave, .unison, .octave, .chord, .unison, .interval, .chord]
        let mode = modes[(weekday - 1) % modes.count]
        return Stage(mode: mode, number: 8).spec.with(pairs: 6)
    }

    func with(pairs: Int) -> BoardSpec {
        var copy = self
        copy.pairs = pairs
        return copy
    }
}

/// 1 枚のカード
struct Card: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let concept: Concept
    let sound: SoundItem
}

/// 決まった種から同じ並びを作る乱数（今日の盤・撮影・テストが毎回同じになる）
struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 日付から種を作る（同じ日は同じ盤）
    static func seed(for date: Date, calendar: Calendar) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return UInt64((c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0))
    }
}

/// 盤を作る。苦手（weights の大きい Concept）が多く入る並びを選ぶ
enum BoardMaker {
    /// 使う音の範囲（イヤホンなしの iPhone のスピーカーでも聞き分けやすい高さ：C4〜C6）
    static let low = 60
    static let high = 84

    static func make(_ spec: BoardSpec, seed: UInt64, weights: [Concept: Double] = [:]) -> [Card] {
        var rng = SeededRandom(seed: seed)
        // 候補を何通りか作り、苦手の重みがいちばん大きいものを選ぶ（重みがなければ最初の候補）
        let tries = weights.isEmpty ? 1 : 6
        var best: [Concept] = []
        var bestScore = -1.0
        for _ in 0..<tries {
            let concepts = pickConcepts(spec, rng: &rng)
            let score = concepts.reduce(0) { $0 + (weights[$1] ?? 0) }
            if score > bestScore {
                best = concepts
                bestScore = score
            }
        }
        var cards: [Card] = []
        for concept in best {
            let pair = sounds(for: concept, spec: spec, rng: &rng)
            cards.append(Card(id: 0, concept: concept, sound: pair.0))
            cards.append(Card(id: 0, concept: concept, sound: pair.1))
        }
        cards.shuffle(using: &rng)
        return cards.enumerated().map { Card(id: $0.offset, concept: $0.element.concept, sound: $0.element.sound) }
    }

    /// 苦手を中心にした盤（Pro）。苦手が足りなければ、その近くの音で埋める
    static func weakness(mode: Mode, focus: [Concept], pairs: Int, seed: UInt64) -> [Card] {
        let base = Stage(mode: mode, number: 9).spec.with(pairs: pairs)
        var weights: [Concept: Double] = [:]
        for (i, concept) in focus.enumerated() { weights[concept] = Double(10 - min(i, 9)) }
        return make(base, seed: seed, weights: weights)
    }

    // MARK: -

    static func pickConcepts(_ spec: BoardSpec, rng: inout SeededRandom) -> [Concept] {
        switch spec.mode {
        case .unison:
            return spacedValues(count: spec.pairs, range: low...high, gap: spec.gap, crowding: spec.crowding, rng: &rng)
                .map { .pitch($0) }
        case .octave:
            // 音名 0〜11 から、間を空けて選ぶ（環になっているので 12 を超えたら戻す）
            let count = min(spec.pairs, 12)
            let gap = max(1, min(spec.gap, 12 / count))
            let start = Int.random(in: 0..<12, using: &rng)
            var classes = spacedValues(count: count, range: 0...(12 - gap), gap: gap, crowding: 0, rng: &rng)
                .map { ($0 + start) % 12 }
            if Set(classes).count < count { classes = Array(0..<12).shuffled(using: &rng).prefix(count).map { $0 } }
            return classes.map { .pitchClass($0) }
        case .chord:
            var options: [Concept] = []
            for root in 60...71 { for q in spec.qualities { options.append(.chord(root: root, quality: q)) } }
            options.shuffle(using: &rng)
            var chosen: [Concept] = []
            // 根音の間を gap 以上あける（入らなければ間をつめて足す）
            for allowedGap in stride(from: spec.gap, through: 0, by: -1) {
                for option in options where chosen.count < spec.pairs && !chosen.contains(option) {
                    guard case let .chord(root, _) = option else { continue }
                    let ok = chosen.allSatisfy { c in
                        guard case let .chord(r, _) = c else { return true }
                        return r == root ? allowedGap == 0 : abs(r - root) >= allowedGap
                    }
                    if ok { chosen.append(option) }
                }
                if chosen.count >= spec.pairs { break }
            }
            return chosen
        case .interval:
            let pool = spec.intervals.shuffled(using: &rng)
            return pool.prefix(min(spec.pairs, pool.count)).map { .interval($0) }
        }
    }

    /// ペアの 2 枚が鳴らす音
    static func sounds(for concept: Concept, spec: BoardSpec, rng: inout SeededRandom) -> (SoundItem, SoundItem) {
        switch concept {
        case .pitch(let m):
            return (.note(m), .note(m))
        case .pitchClass(let p):
            let lowNote = 60 + p
            return (.note(lowNote), .note(lowNote + 12))
        case let .chord(root, quality):
            let second = spec.invertsChords ? Int.random(in: 1...2, using: &rng) : 0
            return (.chord(root: root, quality: quality, inversion: 0), .chord(root: root, quality: quality, inversion: second))
        case .interval(let s):
            // 2 枚は始まりの音を変える（幅だけで聞き分ける）
            let top = high - s
            let a = Int.random(in: low...max(low, top), using: &rng)
            var b = Int.random(in: low...max(low, top), using: &rng)
            if top > low && abs(a - b) < 2 { b = a + 2 <= top ? a + 2 : max(low, a - 2) }
            return (.interval(start: a, semitones: s), .interval(start: b, semitones: s))
        }
    }

    /// range の中から、間が gap 以上の値を count 個選ぶ。crowding が大きいほど狭い窓に集める
    static func spacedValues(count: Int, range: ClosedRange<Int>, gap: Int, crowding: Int, rng: inout SeededRandom) -> [Int] {
        guard count > 0 else { return [] }
        let span = range.upperBound - range.lowerBound
        let gap = max(1, min(gap, count > 1 ? span / (count - 1) : gap))
        let needed = (count - 1) * gap
        let freeSpace = span - needed
        // 窓の広さ：crowding 0 は全部、3 はほぼ最小
        let window = needed + max(0, freeSpace * (3 - min(crowding, 3)) / 3)
        let start = range.lowerBound + Int.random(in: 0...max(0, span - window), using: &rng)
        var extra = window - needed
        var values: [Int] = []
        var current = start
        for i in 0..<count {
            if i > 0 { current += gap }
            let add = extra > 0 ? Int.random(in: 0...min(extra, max(1, extra / max(1, count - i))), using: &rng) : 0
            current += add
            extra -= add
            values.append(current)
        }
        return values
    }
}
