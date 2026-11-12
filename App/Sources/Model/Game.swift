import Foundation

/// 取り違え：聞いたことがあるのに、ちがう音を「同じ」と選んだ組
struct Confusion: Hashable, Codable, Sendable {
    let a: Concept
    let b: Concept

    /// 順番をそろえる（ミとファ、ファとミを同じ組にする）
    init(_ x: Concept, _ y: Concept) {
        if x <= y { a = x; b = y } else { a = y; b = x }
    }
}

/// 1 回の盤の遊び（画面から切り離した決まり）
struct Game: Sendable {
    enum Flip: Equatable, Sendable {
        /// 押せない（もうそろった・表になっている）
        case ignored
        /// 1 枚目をめくった
        case first
        /// そろった（連続の数）
        case match(combo: Int)
        /// ちがった。remembered = 聞いたことのある音で外した（聞き直しに入る）
        case miss(remembered: Bool)
    }

    let cards: [Card]
    private(set) var matched: Set<Int> = []
    /// 表になっている、まだそろっていないカード（0〜2 枚）
    private(set) var faceUp: [Int] = []
    /// 1 回でもめくったカード
    private(set) var seen: Set<Int> = []
    /// ペアをためした回数（2 枚めくるごとに 1）
    private(set) var moves = 0
    /// 聞いて覚えていた音で当てた回数
    private(set) var hits = 0
    /// 聞いて覚えていたはずの音で外した回数
    private(set) var misses = 0
    private(set) var combo = 0
    private(set) var bestCombo = 0
    /// そろった順（ペアの Concept）
    private(set) var foundOrder: [Concept] = []
    private(set) var confusions: [Confusion] = []

    init(cards: [Card]) {
        self.cards = cards
    }

    var pairs: Int { cards.count / 2 }
    var isFinished: Bool { !cards.isEmpty && matched.count == cards.count }
    var pairsLeft: Int { (cards.count - matched.count) / 2 }

    func card(_ id: Int) -> Card? { cards.first { $0.id == id } }

    func partner(of id: Int) -> Int? {
        guard let c = card(id) else { return nil }
        return cards.first { $0.id != id && $0.concept == c.concept }?.id
    }

    /// ちがった 2 枚が表のまま残っているか（次にめくると伏せる）
    var hasPendingMiss: Bool { faceUp.count == 2 }

    mutating func flip(_ id: Int) -> Flip {
        guard card(id) != nil, !matched.contains(id), !isFinished else { return .ignored }
        if hasPendingMiss { hideMismatch() }
        guard !faceUp.contains(id) else { return .ignored }

        guard let first = faceUp.first else {
            faceUp = [id]
            seen.insert(id)
            return .first
        }

        // 2 枚目
        moves += 1
        let a = cards[index(first)]
        let b = cards[index(id)]
        let partnerSeen = partner(of: first).map { seen.contains($0) } ?? false
        let bSeen = seen.contains(id)
        seen.insert(id)

        if a.concept == b.concept {
            matched.insert(first)
            matched.insert(id)
            faceUp = []
            foundOrder.append(a.concept)
            if partnerSeen { hits += 1 }
            combo += 1
            bestCombo = max(bestCombo, combo)
            return .match(combo: combo)
        } else {
            combo = 0
            faceUp = [first, id]
            let remembered = partnerSeen || bSeen
            if remembered {
                misses += 1
                confusions.append(Confusion(a.concept, b.concept))
            }
            return .miss(remembered: remembered)
        }
    }

    /// ちがった 2 枚を伏せる
    mutating func hideMismatch() {
        if faceUp.count == 2 { faceUp = [] }
    }

    /// 3 つ星の目安（耳で覚えれば届く手数）
    static func par(pairs: Int) -> (three: Int, two: Int) {
        (Int((Double(pairs) * 1.6).rounded(.up)), pairs * 2 + 2)
    }

    var stars: Int {
        guard isFinished else { return 0 }
        let par = Self.par(pairs: pairs)
        if moves <= par.three { return 3 }
        if moves <= par.two { return 2 }
        return 1
    }

    /// 聞き分けの正確さ（覚えていたはずの場面で当てた割合）。場面がなければ nil
    var accuracy: Double? {
        let total = hits + misses
        return total == 0 ? nil : Double(hits) / Double(total)
    }

    private func index(_ id: Int) -> Int { cards.firstIndex { $0.id == id } ?? 0 }
}
