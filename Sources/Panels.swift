import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Guess the hidden five letter word in six attempts.").font(.title3.weight(.bold))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Every submitted guess must be a valid five letter word.")
                        Text("**Correct** means the letter and position are right.")
                        Text("**Present** means the letter belongs in another position.")
                        Text("**Absent** means the letter is unavailable in that quantity.")
                        Text("Start a new puzzle any time you like.")
                    }
                    Divider()
                    Text("Examples").font(.headline)
                    example("CRANE", [.correct, .absent, .absent, .absent, .absent], "C is in the word and in the correct spot.")
                    example("PILOT", [.absent, .present, .absent, .absent, .absent], "I is in the word but in the wrong spot.")
                    example("VAGUE", [.absent, .absent, .absent, .absent, .absent], "None of these letters are in the word.")
                }
                .padding(20)
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func example(_ word: String, _ states: [Eval], _ text: String) -> some View {
        let names = states.map { $0 == .correct ? "correct" : ($0 == .present ? "present elsewhere" : "absent") }
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                ForEach(0..<5, id: \.self) { i in
                    let ch = String(Array(word)[i])
                    Text(ch).font(.system(size: 26, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(theme.color(for: states[i]))
                        .accessibilityLabel("\(ch) \(names[i])")
                }
            }
            Text(text).font(.callout)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("strictMode") private var strictMode = false
    @AppStorage("themeSetting") private var themeSetting = 2
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("reduceMotionSetting") private var reduceSetting = 0
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Strict mode", isOn: $strictMode)
                } header: { Text("Gameplay") } footer: {
                    Text(model.inProgress ? "Strict mode is chosen before the first guess. A change here applies to your next game."
                                          : "Every guess must reuse the hints you have already revealed.")
                }
                Section("Appearance") {
                    Picker("Theme", selection: $themeSetting) {
                        Text("Automatic").tag(0); Text("Light").tag(1); Text("Black").tag(2)
                    }
                    Toggle("High contrast colors", isOn: $highContrast)
                    Picker("Reduce motion", selection: $reduceSetting) {
                        Text("Automatic").tag(0); Text("Always").tag(1)
                    }
                }
                Section {
                    Button("Reset statistics", role: .destructive) { confirmReset = true }
                } footer: { Text("Quintet keeps everything on this device. The word is chosen at random each game, so you can play as often as you like.") }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.opacity(0))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Reset all statistics?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.resetStatistics() }
            }
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if model.isOver {
                        VStack(spacing: 4) {
                            Text(model.status == .won ? "You solved it in \(model.guesses.count)" : "The word was \(model.answer)")
                                .font(.title3.weight(.bold))
                            Text(model.status == .won ? "Nice work." : "Better luck next time.").foregroundStyle(.secondary)
                        }
                    }
                    HStack(alignment: .top, spacing: 18) {
                        stat("\(model.stats.gamesPlayed)", "Played")
                        stat("\(model.stats.winPercent)", "Win %")
                        stat("\(model.stats.currentStreak)", "Current\nstreak")
                        stat("\(model.stats.maxStreak)", "Max\nstreak")
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Guess distribution").font(.headline)
                        distribution
                    }
                    if model.isOver {
                        VStack(spacing: 10) {
                            Button { model.startNewGame(); dismiss() } label: {
                                Text("New game").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                                    .background(theme.correct, in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
                            }
                            HStack(spacing: 10) {
                                ShareLink(item: model.shareText) {
                                    Label("Share", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(.vertical, 12)
                                }
                                Button { model.copyResult() } label: {
                                    Label(model.copiedMessage ? "Copied results to clipboard" : "Copy", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity).padding(.vertical, 12).minimumScaleFactor(0.7).lineLimit(1)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func stat(_ value: String, _ name: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 34, weight: .semibold))
            Text(name).font(.caption).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name.replacingOccurrences(of: "\n", with: " ")): \(value)")
    }

    private var distribution: some View {
        let d = model.stats.distribution
        let maxV = max(1, d.max() ?? 1)
        return VStack(spacing: 5) {
            ForEach(0..<6, id: \.self) { i in
                let n = d[i]
                let highlight = model.winAttempts == i + 1
                HStack(spacing: 8) {
                    Text("\(i + 1)").font(.callout.weight(.semibold)).frame(width: 14)
                    GeometryReader { g in
                        let w = n == 0 ? 22 : max(26, g.size.width * CGFloat(n) / CGFloat(maxV))   // nonzero values keep a visible minimum width
                        HStack { Text("\(n)").font(.callout.weight(.bold)).foregroundStyle(.white).padding(.trailing, 6) }
                            .frame(width: w, height: 22, alignment: .trailing)
                            .background(highlight ? theme.correct : theme.absent)
                    }
                    .frame(height: 22)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Solved in \(i + 1): \(n) \(n == 1 ? "game" : "games")\(highlight ? ", this game" : "")")
            }
        }
    }
}
