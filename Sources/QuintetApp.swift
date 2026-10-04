import SwiftUI

@main
struct QuintetApp: App {
    @StateObject private var model = GameModel()
    var body: some Scene {
        WindowGroup { ContentView().environmentObject(model) }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: GameModel
    @AppStorage("themeSetting") private var themeSetting = 2
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("reduceMotionSetting") private var reduceSetting = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var systemReduce
    @FocusState private var focused: Bool

    private var dark: Bool { themeSetting == 2 || (themeSetting == 0 && scheme == .dark) }
    private var theme: Theme { Theme.make(dark: dark, highContrast: highContrast) }
    private var reduce: Bool { reduceSetting == 1 || systemReduce }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()
            GeometryReader { geo in
                let colW = min(geo.size.width, 500)
                let keyH = max(34, min(58, geo.size.height * 0.075))
                let kbH = keyH * 3 + 16
                let gap: CGFloat = 5
                let availH = geo.size.height - 54 - kbH - 36
                let tile = max(24, min(62, (colW - 24 - gap * 4) / 5, (availH - gap * 5) / 6))
                VStack(spacing: 0) {
                    navBar.frame(width: colW)
                    Spacer(minLength: 6)
                    BoardView(tile: tile, gap: gap, reduceMotion: reduce)
                    if model.isOver && !model.showStats {
                        Button("New game") { model.startNewGame() }
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 28).padding(.vertical, 11)
                            .background(theme.correct, in: Capsule()).padding(.top, 12)
                    }
                    Spacer(minLength: 6)
                    KeyboardView(width: colW - 16, keyHeight: keyH).padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
            }
            if let t = model.toast {
                VStack { ToastView(text: t).padding(.top, 62); Spacer() }.allowsHitTesting(false)
            }
        }
        .environment(\.theme, theme)
        .preferredColorScheme(themeSetting == 1 ? .light : (themeSetting == 2 ? .dark : nil))
        .animation(.easeInOut(duration: 0.15), value: model.toast)
        .focusable().focused($focused).focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            if press.key == .return { model.submit(); return .handled }
            if press.key == .delete { model.backspace(); return .handled }
            if let c = press.characters.first, c.isLetter, c.isASCII { model.type(c); return .handled }
            return .ignored
        }
        .onAppear {
            focused = true
            model.reduceMotion = reduce
            if CommandLine.arguments.contains("-demo") || CommandLine.arguments.contains("-demowin") { model.showHelp = false; Task { await model.runDemo() } }
        }
        .onChange(of: reduce) { _, v in model.reduceMotion = v }
        .sheet(isPresented: $model.showHelp, onDismiss: { focused = true }) { HelpView().environment(\.theme, theme).preferredColorScheme(themeSetting == 1 ? .light : (themeSetting == 2 ? .dark : nil)).presentationBackground(theme.background) }
        .sheet(isPresented: $model.showSettings, onDismiss: { focused = true }) { SettingsView().environmentObject(model).environment(\.theme, theme).preferredColorScheme(themeSetting == 1 ? .light : (themeSetting == 2 ? .dark : nil)).presentationBackground(theme.background) }
        .sheet(isPresented: $model.showStats, onDismiss: { focused = true }) { StatsView().environmentObject(model).environment(\.theme, theme).preferredColorScheme(themeSetting == 1 ? .light : (themeSetting == 2 ? .dark : nil)).presentationDetents([.large]).presentationBackground(theme.background) }
        .alert("Start a new game?", isPresented: $model.confirmNewGame) {
            Button("New game", role: .destructive) { model.startNewGame() }
            Button("Keep playing", role: .cancel) {}
        } message: { Text("Your current game won't count toward your statistics.") }
    }

    private var navBar: some View {
        HStack {
            Menu {
                Button { model.requestNewGame() } label: { Label("New game", systemImage: "arrow.clockwise") }
                Button { model.showStats = true } label: { Label("Statistics", systemImage: "chart.bar") }
                Button { model.showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
            } label: {
                Label("Menu", systemImage: "line.3.horizontal").labelStyle(.titleAndIcon)
                    .font(.system(size: 15, weight: .semibold)).frame(minWidth: 70, minHeight: 44, alignment: .leading)
            }
            Spacer()
            Text("QUINTET").font(.system(size: 30, weight: .black, design: .serif)).tracking(1.5)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button { model.showHelp = true } label: {
                Label("Help", systemImage: "questionmark.circle").labelStyle(.titleAndIcon)
                    .font(.system(size: 15, weight: .semibold)).frame(minWidth: 70, minHeight: 44, alignment: .trailing)
            }
        }
        .foregroundStyle(theme.text)
        .padding(.horizontal, 12)
        .frame(height: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.emptyBorder).frame(height: 1) }
    }
}
