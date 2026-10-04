import Foundation
var failures = 0
func check(_ c: Bool, _ m: String) { if c { print("ok  :", m) } else { print("FAIL:", m); failures += 1 } }

check(evaluate(answer: "APPLE", guess: "ALLEY") == [.correct, .present, .absent, .present, .absent], "APPLE vs ALLEY (spec example)")
check(evaluate(answer: "ABBEY", guess: "BABES") == [.present, .present, .correct, .correct, .absent], "ABBEY vs BABES, duplicate letters")
check(evaluate(answer: "CRANE", guess: "CRANE") == [Eval](repeating: .correct, count: 5), "exact match")
check(evaluate(answer: "SPEED", guess: "EERIE") == [.present, .present, .absent, .absent, .absent], "SPEED vs EERIE, third E is absent")
check(evaluate(answer: "ROBOT", guess: "FLOOR") == [.absent, .absent, .present, .correct, .present], "ROBOT vs FLOOR")
check(evaluate(answer: "ALLOW", guess: "LLAMA") == [.present, .correct, .present, .absent, .absent], "ALLOW vs LLAMA")

var k: [Character: Eval] = [:]
mergeKeyStates(&k, word: "CRANE", eval: [.correct, .absent, .present, .absent, .absent])
mergeKeyStates(&k, word: "CLOCK", eval: [.absent, .absent, .absent, .absent, .absent])
check(k["C"] == .correct && k["A"] == .present && k["R"] == .absent, "keyboard states never get weaker")

let chair = [(word: "CRANE", eval: evaluate(answer: "CHAIR", guess: "CRANE"))]
check(strictViolation(guess: "SLOTH", history: chair) == "The first letter must be C", "strict: correct letter must stay in place")
check(strictViolation(guess: "CHAIR", history: chair) == nil, "strict: consistent guess accepted")
check(strictViolation(guess: "CHAMP", history: chair) == "Guess must contain R", "strict: present letter must be reused")

let allow = [(word: "LLAMA", eval: evaluate(answer: "ALLOW", guess: "LLAMA"))]
check(strictViolation(guess: "ALOFT", history: allow)?.contains("2 L") == true, "strict: duplicate count enforced")
check(strictViolation(guess: "LLAMA", history: allow)?.contains("can't go") == true, "strict: present letter not reused in a wrong position")
check(strictViolation(guess: "ALLOW", history: allow) == nil, "strict: the real answer is always allowed")

var s = Stats()
s.record(won: true, attempts: 4); s.record(won: true, attempts: 2); s.record(won: false, attempts: 6)
check(s.gamesPlayed == 3 && s.gamesWon == 2 && s.currentStreak == 0 && s.maxStreak == 2 && s.distribution[3] == 1 && s.distribution[1] == 1 && s.winPercent == 67, "stats: played, won, streaks, win %, distribution")

let words = (try! String(contentsOfFile: "Resources/words.txt")).split(separator: "\n").map { $0.uppercased() }
check(words.count == 3555 && words.allSatisfy { $0.count == 5 }, "word list: 3555 five-letter words")
check(Set(words).count == words.count, "word list: no duplicates")


// split-flap timing
check(abs(FlipTiming.full - 0.126) < 1e-9 && FlipTiming.full < 0.224, "split-flap tile animation is faster again (0.126 s vs 0.224 s)")
check(abs(FlipTiming.stagger / FlipTiming.full - 0.6) < 1e-9, "next tile starts at 60% of the previous tile's animation")
check(FlipTiming.flaps == 3 && abs(FlipTiming.flap * 3 - FlipTiming.full) < 1e-9, "3 flaps per tile")
check(FlipTiming.half * 60 >= 1.0, "each half-flap lasts at least one 60 fps frame")

print(failures == 0 ? "ALL ENGINE TESTS PASSED" : "\(failures) FAILURE(S)")
exit(failures == 0 ? 0 : 1)
