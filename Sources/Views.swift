import SwiftUI

struct ShakeEffect: GeometryEffect {
    var travel: CGFloat = 12
    var shakes: CGFloat = 4
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// One visual state of a tile: a letter on an optional evaluation colour, or a dark "flap" face.
struct Face: Equatable {
    var letter: String
    var eval: Eval?
    var neutral = false          // dark board-style face shown while the flaps are clacking
}

struct FaceView: View {
    let face: Face
    let size: CGFloat
    @Environment(\.theme) private var theme

    private var fill: Color {
        if let e = face.eval { return theme.color(for: e) }
        return face.neutral ? Color(hex: 0x2A2A2D) : .clear
    }
    private var border: Color {
        if face.eval != nil || face.neutral { return .clear }
        return face.letter.isEmpty ? theme.emptyBorder : theme.typedBorder
    }
    private var textColor: Color { (face.eval != nil || face.neutral) ? theme.tileText : theme.text }

    var body: some View {
        ZStack {
            Rectangle().fill(fill)
            Rectangle().strokeBorder(border, lineWidth: 2)
            Text(face.letter)
                .font(.system(size: size * 0.54, weight: .bold))
                .foregroundStyle(textColor)
                .minimumScaleFactor(0.5)
            if let e = face.eval {                             // a shape cue so colour is never the only signal
                VStack { HStack { Spacer(); marker(e) }; Spacer() }.padding(size * 0.07)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private func marker(_ e: Eval) -> some View {
        let s = size * 0.2
        switch e {
        case .correct: Circle().fill(.white.opacity(0.9)).frame(width: s, height: s)
        case .present: Rectangle().fill(.white.opacity(0.9)).frame(width: s * 0.8, height: s * 0.8).rotationEffect(.degrees(45))
        case .absent: Capsule().fill(.white.opacity(0.7)).frame(width: s, height: s * 0.28)
        }
    }
}

struct TileView: View {
    let letter: String
    let eval: Eval?
    let revealed: Bool
    let size: CGFloat
    let reduceMotion: Bool
    let winRow: Bool
    let column: Int
    let bounceTick: Int
    let label: String

    @State private var showEval = false
    @State private var animating = false
    @State private var cur = Face(letter: "", eval: nil)
    @State private var next = Face(letter: "", eval: nil)
    @State private var topAngle = 0.0
    @State private var bottomAngle = 90.0
    @State private var topOn = true
    @State private var bottomOn = false
    @State private var pop: CGFloat = 1
    @State private var bounceY: CGFloat = 0

    var body: some View {
        ZStack {
            if animating {
                // split-flap: static next-top and current-bottom, plus the two moving flaps
                half(next, top: true)
                half(cur, top: false)
                half(cur, top: true)
                    .rotation3DEffect(.degrees(topAngle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.4)
                    .opacity(topOn ? 1 : 0)
                half(next, top: false)
                    .rotation3DEffect(.degrees(bottomAngle), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.4)
                    .opacity(bottomOn ? 1 : 0)
                Rectangle().fill(Color.black.opacity(0.6)).frame(width: size, height: 1.5)       // hinge seam
            } else {
                FaceView(face: Face(letter: letter, eval: showEval ? eval : nil), size: size)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(pop)
        .offset(y: bounceY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .onAppear { showEval = revealed }
        .onChange(of: letter) { old, new in
            guard old.isEmpty, !new.isEmpty, !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.05)) { pop = 1.1 }
            withAnimation(.easeIn(duration: 0.05).delay(0.05)) { pop = 1 }
        }
        .onChange(of: revealed) { _, now in
            if now { flip() } else { showEval = false; animating = false }
        }
        .onChange(of: bounceTick) { _, _ in
            guard winRow, !reduceMotion else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(column) * 70_000_000)
                withAnimation(.easeOut(duration: 0.10)) { bounceY = -size * 0.3 }
                try? await Task.sleep(nanoseconds: 100_000_000)
                withAnimation(.easeIn(duration: 0.12)) { bounceY = 0 }
            }
        }
    }

    private func half(_ f: Face, top: Bool) -> some View {
        FaceView(face: f, size: size)
            .mask(alignment: top ? .top : .bottom) { Rectangle().frame(width: size, height: size / 2) }
    }

    /// Letters the board clacks through before landing: the three letters before the target, then the target itself.
    private func sequence() -> [Face] {
        let t = Int(letter.unicodeScalars.first?.value ?? 65) - 65
        var out: [Face] = []
        for k in stride(from: FlipTiming.flaps - 1, to: 0, by: -1) {
            let idx = ((t - k) % 26 + 26) % 26
            out.append(Face(letter: String(UnicodeScalar(UInt8(65 + idx))), eval: nil, neutral: true))
        }
        out.append(Face(letter: letter, eval: eval))
        return out
    }

    private func flip() {
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.2)) { showEval = true }
            return
        }
        Task { @MainActor in
            let steps = sequence()
            var current = Face(letter: letter, eval: nil)
            animating = true
            for face in steps {
                cur = current; next = face
                var t = Transaction(); t.disablesAnimations = true
                withTransaction(t) { topAngle = 0; bottomAngle = 90; topOn = true; bottomOn = false }
                withAnimation(.easeIn(duration: FlipTiming.half)) { topAngle = -90 }          // top flap falls
                try? await Task.sleep(nanoseconds: UInt64(FlipTiming.half * 1_000_000_000))
                withTransaction(t) { topOn = false; bottomOn = true }
                withAnimation(.easeOut(duration: FlipTiming.half)) { bottomAngle = 0 }        // bottom flap lands
                try? await Task.sleep(nanoseconds: UInt64(FlipTiming.half * 1_000_000_000))
                current = face
            }
            showEval = true
            animating = false
        }
    }
}

struct BoardView: View {
    @EnvironmentObject var model: GameModel
    let tile: CGFloat
    let gap: CGFloat
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: gap) {
            ForEach(0..<6, id: \.self) { row in
                RowView(row: row, tile: tile, gap: gap, reduceMotion: reduceMotion)
            }
        }
    }
}

struct RowView: View {
    @EnvironmentObject var model: GameModel
    let row: Int
    let tile: CGFloat
    let gap: CGFloat
    let reduceMotion: Bool
    @State private var shake: CGFloat = 0

    var body: some View {
        HStack(spacing: gap) {
            ForEach(0..<5, id: \.self) { col in
                TileView(letter: model.letter(row: row, col: col), eval: model.eval(row: row, col: col),
                         revealed: model.revealed[row][col], size: tile, reduceMotion: reduceMotion,
                         winRow: model.status == .won && row == model.guesses.count - 1, column: col,
                         bounceTick: model.bounceTick, label: model.accessibilityLabel(row: row, col: col))
            }
        }
        .modifier(ShakeEffect(animatableData: shake))
        .onChange(of: model.shakeTick) { _, _ in
            guard row == model.guesses.count, !reduceMotion else { return }
            shake = 0
            withAnimation(.linear(duration: 0.55)) { shake = 1 }
        }
    }
}

struct KeyboardView: View {
    @EnvironmentObject var model: GameModel
    @Environment(\.theme) private var theme
    let width: CGFloat
    let keyHeight: CGFloat

    private let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
    private let gap: CGFloat = 6

    var body: some View {
        let keyW = (width - gap * 9) / 10
        VStack(spacing: 8) {
            row(rows[0], keyW: keyW, leading: nil, trailing: nil)
            row(rows[1], keyW: keyW, leading: nil, trailing: nil).padding(.horizontal, keyW * 0.5 + gap * 0.5)
            HStack(spacing: gap) {
                wide("ENTER", w: keyW * 1.5) { model.submit() }
                ForEach(Array(rows[2]), id: \.self) { key($0, keyW: keyW) }
                wide("⌫", w: keyW * 1.5, label: "Backspace") { model.backspace() }
            }
        }
        .frame(width: width)
    }

    private func row(_ letters: String, keyW: CGFloat, leading: String?, trailing: String?) -> some View {
        HStack(spacing: gap) { ForEach(Array(letters), id: \.self) { key($0, keyW: keyW) } }
    }

    private func key(_ c: Character, keyW: CGFloat) -> some View {
        let state = model.keyStates[c]
        let bg = state.map { theme.color(for: $0) } ?? theme.key
        let fg: Color = state == nil ? theme.keyText : theme.tileText
        let stateText = state.map { $0 == .correct ? "correct" : ($0 == .present ? "present elsewhere" : "absent") } ?? "unused"
        return Button { model.type(c) } label: {
            Text(String(c)).font(.system(size: min(20, keyW * 0.62), weight: .bold)).foregroundStyle(fg)
                .frame(width: keyW, height: keyHeight)
                .background(bg, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(c), \(stateText)")
    }

    private func wide(_ text: String, w: CGFloat, label: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: text == "⌫" ? 22 : 12, weight: .bold)).foregroundStyle(theme.keyText)
                .frame(width: w, height: keyHeight)
                .background(theme.key, in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? text.capitalized)
    }
}

struct ToastView: View {
    let text: String
    @Environment(\.theme) private var theme
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(theme.background)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(theme.text, in: RoundedRectangle(cornerRadius: 6))
            .transition(.opacity)
    }
}
