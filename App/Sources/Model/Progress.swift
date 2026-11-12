import Foundation

/// 当てた・外した回数
struct Tally: Codable, Hashable, Sendable {
    var hits = 0
    var misses = 0

    var total: Int { hits + misses }
    var rate: Double? { total == 0 ? nil : Double(hits) / Double(total) }

    mutating func add(hits: Int, misses: Int) {
        self.hits += hits
        self.misses += misses
    }
}

/// 1 日の記録
struct DayRecord: Codable, Hashable, Sendable {
    var boards = 0
    var pairs = 0
    var dailyDone = false
    var dailyStars = 0
    var dailyMoves = 0
}

/// 盤の種類（記録の付け方が変わる）
enum BoardKind: Hashable, Codable, Sendable {
    case tutorial
    case stage(String)
    case daily
    case weakness
}

/// 遊び終えた 1 回の結果
struct BoardResult: Sendable, Equatable {
    var kind: BoardKind
    var mode: Mode
    var pairs: Int
    var moves: Int
    var stars: Int
    var hits: Int
    var misses: Int
    var confusions: [Confusion]
}

/// 端末の中だけに残す記録（UserDefaults に JSON で保存）
struct Progress: Codable, Sendable, Equatable {
    var stars: [String: Int] = [:]
    var bestMoves: [String: Int] = [:]
    var days: [String: DayRecord] = [:]
    var tallies: [Mode: Tally] = [:]
    var confusionCounts: [Confusion: Int] = [:]
    var tutorialDone = false
    var lastPaywallDay: String?

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: 記録する

    mutating func record(_ result: BoardResult, on date: Date, calendar: Calendar) {
        let key = Self.dayKey(date, calendar: calendar)
        var day = days[key] ?? DayRecord()
        day.boards += 1
        day.pairs += result.pairs
        switch result.kind {
        case .tutorial:
            tutorialDone = true
        case .stage(let id):
            stars[id] = max(stars[id] ?? 0, result.stars)
            bestMoves[id] = min(bestMoves[id] ?? .max, result.moves)
        case .daily:
            if !day.dailyDone || result.stars > day.dailyStars {
                day.dailyStars = max(day.dailyStars, result.stars)
                day.dailyMoves = day.dailyDone ? min(day.dailyMoves, result.moves) : result.moves
            }
            day.dailyDone = true
        case .weakness:
            break
        }
        days[key] = day
        tallies[result.mode, default: Tally()].add(hits: result.hits, misses: result.misses)
        for confusion in result.confusions { confusionCounts[confusion, default: 0] += 1 }
    }

    // MARK: 読む

    func stars(of stage: Stage) -> Int { stars[stage.id] ?? 0 }

    /// 段階が開いているか（前の段階を 1 つ星以上で終えたら開く。各モードの 1 段階目は最初から開く）
    func isOpen(_ stage: Stage) -> Bool {
        stage.number == 1 || stars(of: Stage(mode: stage.mode, number: stage.number - 1)) > 0
    }

    /// 次に遊ぶ段階（まだ星のない、開いている最初の段階）
    func nextStage(in mode: Mode) -> Stage {
        Stage.all(mode).first { stars(of: $0) == 0 && isOpen($0) } ?? Stage(mode: mode, number: Stage.perMode)
    }

    func totalStars(_ mode: Mode) -> Int { Stage.all(mode).reduce(0) { $0 + stars(of: $1) } }

    func isDailyDone(on date: Date, calendar: Calendar) -> Bool {
        days[Self.dayKey(date, calendar: calendar)]?.dailyDone ?? false
    }

    /// 今日の盤を続けた日数（今日まだなら、昨日までの連続を数える。途切れたら 0）
    func streak(on date: Date, calendar: Calendar) -> Int {
        var day = calendar.startOfDay(for: date)
        if !isDailyDone(on: day, calendar: calendar) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while isDailyDone(on: day, calendar: calendar) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// 遊んだ日の合計（途切れても減らない）
    var playedDays: Int { days.values.filter { $0.boards > 0 }.count }
    var totalPairs: Int { days.values.reduce(0) { $0 + $1.pairs } }

    /// 取り違えの多い順
    func topConfusions(_ limit: Int, mode: Mode? = nil) -> [(Confusion, Int)] {
        confusionCounts
            .filter { mode == nil || $0.key.a.mode == mode }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.a < $1.key.a }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// 盤を作るときの苦手の重み
    func weights(for mode: Mode) -> [Concept: Double] {
        var result: [Concept: Double] = [:]
        for (confusion, count) in confusionCounts where confusion.a.mode == mode {
            result[confusion.a, default: 0] += Double(count)
            result[confusion.b, default: 0] += Double(count)
        }
        return result
    }

    /// 苦手のいちばん多いモードと、その音（多い順）
    func weakestFocus() -> (Mode, [Concept])? {
        guard let top = topConfusions(1).first else { return nil }
        let mode = top.0.a.mode
        let focus = weights(for: mode).sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
        return (mode, focus)
    }

    /// 週ごとのマス（古い週から。各週は日〜土の 7 日、値はその日の盤の数）
    func weeks(_ count: Int, endingAt date: Date, calendar: Calendar) -> [[Int?]] {
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today) - 1
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -weekday, to: today) else { return [] }
        return (0..<count).reversed().map { back in
            (0..<7).map { offset -> Int? in
                guard let day = calendar.date(byAdding: .day, value: offset - back * 7, to: lastWeekStart) else { return nil }
                if day > today { return nil }
                return days[Self.dayKey(day, calendar: calendar)]?.boards ?? 0
            }
        }
    }
}
