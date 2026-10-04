import Foundation

// Pure game logic (no UI): tile evaluation, strict-mode validation, keyboard state ordering.

enum Eval: Int, Codable, Comparable {
    case absent = 0, present = 1, correct = 2
    static func < (a: Eval, b: Eval) -> Bool { a.rawValue < b.rawValue }
}

enum GameStatus: String, Codable { case playing, won, lost }

/// Two-pass evaluation from the specification: exact matches first, then the remaining letter inventory.
func evaluate(answer: String, guess: String) -> [Eval] {
    let a = Array(answer.uppercased()), g = Array(guess.uppercased())
    precondition(a.count == 5 && g.count == 5)
    var result = [Eval](repeating: .absent, count: 5)
    var remaining: [Character: Int] = [:]
    for c in a { remaining[c, default: 0] += 1 }
    for i in 0..<5 where g[i] == a[i] {
        result[i] = .correct
        remaining[g[i], default: 0] -= 1
    }
    for i in 0..<5 where result[i] != .correct {
        if (remaining[g[i]] ?? 0) > 0 {
            result[i] = .present
            remaining[g[i], default: 0] -= 1
        }
    }
    return result
}

private let ordinals = ["first", "second", "third", "fourth", "fifth"]

/// Returns a short message if `guess` ignores information revealed by earlier guesses, otherwise nil.
func strictViolation(guess: String, history: [(word: String, eval: [Eval])]) -> String? {
    let g = Array(guess.uppercased())
    for (word, ev) in history {
        let w = Array(word.uppercased())
        for i in 0..<5 where ev[i] == .correct && g[i] != w[i] {
            return "The \(ordinals[i]) letter must be \(w[i])"
        }
    }
    var required: [Character: Int] = [:]
    for (word, ev) in history {
        let w = Array(word.uppercased())
        var count: [Character: Int] = [:]
        for i in 0..<5 where ev[i] != .absent { count[w[i], default: 0] += 1 }
        for (c, n) in count { required[c] = max(required[c] ?? 0, n) }
    }
    for (c, n) in required.sorted(by: { $0.key < $1.key }) {
        let have = g.filter { $0 == c }.count
        if have < n { return n > 1 ? "Guess must contain \(n) \(c)s" : "Guess must contain \(c)" }
    }
    for (word, ev) in history {
        let w = Array(word.uppercased())
        for i in 0..<5 where ev[i] == .present && g[i] == w[i] {
            return "\(w[i]) can't go in the \(ordinals[i]) position"
        }
    }
    return nil
}

/// Keyboard information only gets stronger: unused < absent < present < correct.
func mergeKeyStates(_ states: inout [Character: Eval], word: String, eval: [Eval]) {
    for (c, e) in zip(word.uppercased(), eval) {
        if let old = states[c], old >= e { continue }
        states[c] = e
    }
}

struct Stats: Codable, Equatable {
    var gamesPlayed = 0
    var gamesWon = 0
    var currentStreak = 0
    var maxStreak = 0
    var distribution = [Int](repeating: 0, count: 6)   // index 0...5 = solved in 1...6 guesses

    var winPercent: Int {
        gamesPlayed == 0 ? 0 : Int((Double(gamesWon) / Double(gamesPlayed) * 100).rounded())
    }

    mutating func record(won: Bool, attempts: Int) {
        gamesPlayed += 1
        if won {
            gamesWon += 1
            distribution[max(0, min(5, attempts - 1))] += 1
            currentStreak += 1
            maxStreak = max(maxStreak, currentStreak)
        } else {
            currentStreak = 0
        }
    }
}

/// Split-flap ("airport board") timing. A tile clacks through `flaps` flaps, each flap being a top half falling
/// then a bottom half landing; the next tile starts when the previous one is 60% through its whole animation.
enum FlipTiming {
    static let flaps = 3
    static let slowdown: Double = CommandLine.arguments.contains("-slowflip") ? 10 : 1      // debug: inspect the animation frame by frame
    static var flap: Double { 0.042 * slowdown }              // one click of the board
    static var half: Double { flap / 2 }
    static var full: Double { flap * Double(flaps) }          // 0.126 s per tile (was 0.224 s, and 0.40 s for the first smooth flip)
    static var stagger: Double { full * 0.6 }                 // 0.0756 s between tile starts
}
