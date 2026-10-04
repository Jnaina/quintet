import SwiftUI
import UIKit

enum Words {
    static let list: [String] = {
        guard let url = Bundle.main.url(forResource: "words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return ["CRANE"] }
        return text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces).uppercased() }.filter { $0.count == 5 }
    }()
    static let set = Set(list)
}

struct SavedGame: Codable {
    var id: String
    var number: Int
    var answer: String
    var guesses: [String]
    var evals: [[Int]]
    var status: GameStatus
    var strict: Bool
    var recorded: Bool
    var startedAt: Date
    var completedAt: Date?
}

@MainActor
final class GameModel: ObservableObject {
    static let maxGuesses = 6

    @Published private(set) var answer = ""
    @Published private(set) var guesses: [String] = []
    @Published private(set) var evals: [[Eval]] = []
    @Published private(set) var status = GameStatus.playing
    @Published private(set) var strict = false
    @Published private(set) var gameNumber = 0
    @Published var current = ""
    @Published private(set) var revealed = [[Bool]](repeating: [Bool](repeating: false, count: 5), count: 6)
    @Published private(set) var keyStates: [Character: Eval] = [:]
    @Published private(set) var isRevealing = false
    @Published var toast: String?
    @Published var shakeTick = 0
    @Published var bounceTick = 0
    @Published private(set) var stats = Stats()
    @Published var showStats = false
    @Published var showHelp = false
    @Published var showSettings = false
    @Published var confirmNewGame = false
    @Published var copiedMessage = false

    var reduceMotion = false          // updated by the view from settings + system preference
    private var recorded = false
    private var startedAt = Date()
    private var completedAt: Date?
    private var gameID = UUID().uuidString
    private var toastTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let notify = UINotificationFeedbackGenerator()

    init() {
        if let d = defaults.data(forKey: "stats.v1"), let s = try? JSONDecoder().decode(Stats.self, from: d) { stats = s }
        if let d = defaults.data(forKey: "game.v1"), let g = try? JSONDecoder().decode(SavedGame.self, from: d), Words.set.contains(g.answer) {
            restore(g)
        } else {
            startNewGame()
        }
        if !defaults.bool(forKey: "seenHelp") { showHelp = true; defaults.set(true, forKey: "seenHelp") }
    }

    // MARK: derived

    var inProgress: Bool { status == .playing && !guesses.isEmpty }
    var isOver: Bool { status != .playing }
    var winAttempts: Int? { status == .won ? guesses.count : nil }

    func letter(row: Int, col: Int) -> String {
        if row < guesses.count { return String(Array(guesses[row])[col]) }
        if row == guesses.count && status == .playing {
            let c = Array(current)
            return col < c.count ? String(c[col]) : ""
        }
        return ""
    }

    func eval(row: Int, col: Int) -> Eval? { row < evals.count ? evals[row][col] : nil }

    func accessibilityLabel(row: Int, col: Int) -> String {
        let l = letter(row: row, col: col)
        let pos = "Row \(row + 1) column \(col + 1)"
        if l.isEmpty { return "\(pos) empty" }
        guard let e = eval(row: row, col: col), revealed[row][col] else { return "\(pos) letter \(l)" }
        let s: String
        switch e {
        case .correct: s = "correct"
        case .present: s = "present elsewhere"
        case .absent: s = "absent"
        }
        return "\(pos) letter \(l) \(s)"
    }

    var shareText: String {
        let result = status == .won ? "\(guesses.count)/6" : "X/6"
        let hc = defaults.bool(forKey: "highContrast")
        var lines = ["Quintet #\(gameNumber) \(result)\(strict ? " *" : "")", ""]
        for ev in evals {
            lines.append(ev.map { $0 == .correct ? (hc ? "🟧" : "🟩") : ($0 == .present ? (hc ? "🟦" : "🟨") : "⬛") }.joined())
        }
        return lines.joined(separator: "\n")
    }

    // MARK: new / restore

    func requestNewGame() {
        if inProgress { confirmNewGame = true } else { startNewGame() }
    }

    func startNewGame() {
        toastTask?.cancel()
        var recent = defaults.stringArray(forKey: "recent.v1") ?? []
        var pick = Words.list.randomElement() ?? "CRANE"
        for _ in 0..<20 where recent.contains(pick) { pick = Words.list.randomElement() ?? pick }
        recent.append(pick)
        defaults.set(Array(recent.suffix(120)), forKey: "recent.v1")
        let n = defaults.integer(forKey: "gameCounter") + 1
        defaults.set(n, forKey: "gameCounter")
        answer = pick; gameNumber = n; gameID = UUID().uuidString
        guesses = []; evals = []; current = ""; status = .playing; recorded = false
        strict = defaults.bool(forKey: "strictMode")          // chosen before the first guess
        revealed = [[Bool]](repeating: [Bool](repeating: false, count: 5), count: 6)
        keyStates = [:]; isRevealing = false; toast = nil
        startedAt = Date(); completedAt = nil
        showStats = false
        save()
    }

    private func restore(_ g: SavedGame) {
        answer = g.answer; gameNumber = g.number; gameID = g.id
        guesses = g.guesses; evals = g.evals.map { $0.map { Eval(rawValue: $0) ?? .absent } }
        status = g.status; strict = g.strict; recorded = g.recorded
        startedAt = g.startedAt; completedAt = g.completedAt
        for r in 0..<guesses.count { revealed[r] = [Bool](repeating: true, count: 5); mergeKeyStates(&keyStates, word: guesses[r], eval: evals[r]) }
        if status != .playing && !recorded { record() }
    }

    private func save() {
        let g = SavedGame(id: gameID, number: gameNumber, answer: answer, guesses: guesses, evals: evals.map { $0.map(\.rawValue) },
                          status: status, strict: strict, recorded: recorded, startedAt: startedAt, completedAt: completedAt)
        if let d = try? JSONEncoder().encode(g) { defaults.set(d, forKey: "game.v1") }
    }

    private func saveStats() {
        if let d = try? JSONEncoder().encode(stats) { defaults.set(d, forKey: "stats.v1") }
    }

    func resetStatistics() { stats = Stats(); saveStats() }

    // MARK: input

    func type(_ ch: Character) {
        guard status == .playing, !isRevealing, current.count < 5, ch.isASCII, ch.isLetter else { return }
        current.append(Character(ch.uppercased()))
        light.impactOccurred(intensity: 0.5)
    }

    func backspace() {
        guard status == .playing, !isRevealing, !current.isEmpty else { return }
        current.removeLast()
    }

    func submit() {
        guard status == .playing, !isRevealing else { return }
        guard current.count == 5 else { reject("Not enough letters"); return }
        guard Words.set.contains(current) else { reject("Not in word list"); return }
        if strict, let msg = strictViolation(guess: current, history: zip(guesses, evals).map { (word: $0, eval: $1) }) { reject(msg); return }
        let word = current
        let ev = evaluate(answer: answer, guess: word)
        let row = guesses.count
        guesses.append(word); evals.append(ev); current = ""
        if ev.allSatisfy({ $0 == .correct }) { status = .won; completedAt = Date() }
        else if guesses.count == Self.maxGuesses { status = .lost; completedAt = Date() }
        save()                                   // state is saved after every accepted guess
        Task { await reveal(row: row) }
    }

    private func reject(_ message: String) {
        showToast(message)
        shakeTick += 1
        notify.notificationOccurred(.error)
    }

    // MARK: reveal and completion

    private func reveal(row: Int) async {
        isRevealing = true
        for i in 0..<5 {
            // the next tile starts when the previous one is 60% through its flip
            try? await Task.sleep(nanoseconds: reduceMotion ? 80_000_000 : UInt64(FlipTiming.stagger * 1_000_000_000))
            revealed[row][i] = true
        }
        try? await Task.sleep(nanoseconds: reduceMotion ? 200_000_000 : UInt64((FlipTiming.full + 0.05) * 1_000_000_000))
        mergeKeyStates(&keyStates, word: guesses[row], eval: evals[row])
        let names = evals[row].map { $0 == .correct ? "correct" : ($0 == .present ? "present elsewhere" : "absent") }
        AccessibilityNotification.Announcement("Row \(row + 1): " + zip(guesses[row], names).map { "\($0) \($1)" }.joined(separator: ", ")).post()
        switch status {
        case .won:
            bounceTick += 1
            notify.notificationOccurred(.success)
            let messages = ["Exceptional", "Magnificent", "Impressive", "Splendid", "Great", "Close one"]
            showToast(messages[max(0, min(5, guesses.count - 1))], duration: 2.4)
            try? await Task.sleep(nanoseconds: reduceMotion ? 700_000_000 : 1_600_000_000)
            record()
            showStats = true
        case .lost:
            showToast(answer, duration: 4)
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            record()
            showStats = true
        case .playing:
            break
        }
        isRevealing = false
    }

    /// Idempotent: a finished game can update the statistics only once.
    private func record() {
        guard status != .playing, !recorded else { return }
        recorded = true
        stats.record(won: status == .won, attempts: guesses.count)
        saveStats(); save()
    }

    func showToast(_ message: String, duration: Double = 1.6) {
        toastTask?.cancel()
        toast = message
        AccessibilityNotification.Announcement(message).post()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled { self?.toast = nil }
        }
    }

    func copyResult() {
        UIPasteboard.general.string = shareText
        copiedMessage = true
        showToast("Copied results to clipboard")
        Task { try? await Task.sleep(nanoseconds: 1_800_000_000); copiedMessage = false }
    }

    // MARK: demo (launch argument -demo, used for screenshots)

    func runDemo() async {
        guard guesses.isEmpty else { return }
        let picks = Words.list.filter { $0 != answer }.prefix(40).shuffled()
        if CommandLine.arguments.contains("-demowin") {
            for w in picks.prefix(2) + [answer] {
                for ch in w { type(ch); try? await Task.sleep(nanoseconds: 60_000_000) }
                submit()
                try? await Task.sleep(nanoseconds: 2_600_000_000)
            }
            return
        }
        for w in picks.prefix(3) {
            for ch in w { type(ch); try? await Task.sleep(nanoseconds: 60_000_000) }
            submit()
            try? await Task.sleep(nanoseconds: 2_400_000_000)
        }
        for ch in "ZZQXV" { type(ch); try? await Task.sleep(nanoseconds: 60_000_000) }
    }
}
