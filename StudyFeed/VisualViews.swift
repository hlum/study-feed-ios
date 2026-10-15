import SwiftUI

/// Native renderers for the three visual kinds the server actually produces.
struct VisualView: View {
    let visual: Visual

    var body: some View {
        switch visual {
        case .terminal(let v): TerminalView(visual: v)
        case .code(let v): CodeView(visual: v)
        case .steps(let v): StepsView(visual: v)
        case .unsupported: EmptyView()
        }
    }
}

struct TerminalView: View {
    let visual: TerminalVisual

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("$ \(visual.command)").foregroundStyle(Theme.muted)
                ForEach(Array(visual.lines.enumerated()), id: \.offset) { _, line in
                    Text(line).foregroundStyle(Theme.ink)
                }
            }
            .font(.mono(.footnote))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14))

            if let legend = visual.legend, !legend.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(legend, id: \.token) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(item.token).font(.mono(.footnote)).foregroundStyle(Theme.accent)
                            Text(item.meaning).font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }
}

struct CodeView: View {
    let visual: CodeVisual

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visual.lines.enumerated()), id: \.offset) { i, line in
                        let note = visual.notes?.first { $0.line == i + 1 }
                        HStack(spacing: 10) {
                            Text("\(i + 1)").foregroundStyle(Theme.muted).frame(width: 16, alignment: .trailing)
                            Text(line).foregroundStyle(Theme.ink).fixedSize()
                            Spacer(minLength: 12)
                            Text(note?.mark ?? " ").foregroundStyle(Theme.accent)
                        }
                        .font(.mono(.footnote))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 3)
                        .frame(minWidth: 320, alignment: .leading)
                        .background(note != nil ? Theme.accent.opacity(0.10) : .clear)
                    }
                }
                .padding(.vertical, 12)
            }
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14))

            if let notes = visual.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(notes, id: \.mark) { note in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(note.mark).font(.mono(.footnote)).foregroundStyle(Theme.accent)
                            Text(note.text).font(.subheadline).foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }
}

/// Step-through of an exchange between actors, one message at a time.
struct StepsView: View {
    let visual: StepsVisual
    @State private var shown = 1

    private let rowHeight: CGFloat = 64
    private let headHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                let n = max(visual.actors.count, 1)
                let xs = (0..<n).map { geo.size.width * (CGFloat($0) + 0.5) / CGFloat(n) }
                ZStack(alignment: .topLeading) {
                    ForEach(0..<n, id: \.self) { i in
                        Path { p in
                            p.move(to: CGPoint(x: xs[i], y: headHeight - 6))
                            p.addLine(to: CGPoint(x: xs[i], y: geo.size.height))
                        }
                        .stroke(Theme.sep, lineWidth: 1)
                        Text(visual.actors[i])
                            .font(.mono(.caption))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 10)
                            .frame(height: 32)
                            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 10))
                            .position(x: xs[i], y: 16)
                    }
                    ForEach(Array(visual.steps.enumerated()), id: \.offset) { i, step in
                        let y = headHeight + rowHeight * (CGFloat(i) + 0.5)
                        let from = xs[min(step.from, n - 1)]
                        let to = xs[min(step.to, n - 1)]
                        let current = i == shown - 1
                        ArrowLine(from: from, to: to, y: y)
                            .stroke(current ? Theme.accent : Theme.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .opacity(i < shown ? 1 : 0.12)
                        Text(step.label)
                            .font(.mono(.caption2))
                            .foregroundStyle(current ? Theme.accent : Theme.ink)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .frame(width: max(abs(to - from) - 12, 60), height: 34, alignment: .bottom)
                            .position(x: (from + to) / 2, y: y - 6 - 17)
                            .opacity(i < shown ? 1 : 0.12)
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 1), value: shown)
            }
            .frame(height: headHeight + rowHeight * CGFloat(visual.steps.count))

            if let caption = visual.steps[safe: shown - 1]?.caption {
                Text(caption).font(.subheadline).foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button("Back") { shown = max(1, shown - 1) }
                    .buttonStyle(.bordered).tint(Theme.muted).disabled(shown == 1)
                Button(shown == visual.steps.count ? "Replay" : "Next message") {
                    shown = shown == visual.steps.count ? 1 : shown + 1
                }
                .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.onAccent)
            }
            .controlSize(.regular)
            .sensoryFeedback(.selection, trigger: shown)
        }
    }
}

private struct ArrowLine: Shape {
    let from: CGFloat, to: CGFloat, y: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let dir: CGFloat = to >= from ? 1 : -1
        let start = from + dir * 3
        let end = to - dir * 3
        p.move(to: CGPoint(x: start, y: y))
        p.addLine(to: CGPoint(x: end, y: y))
        p.move(to: CGPoint(x: end - dir * 8, y: y - 5))
        p.addLine(to: CGPoint(x: end, y: y))
        p.addLine(to: CGPoint(x: end - dir * 8, y: y + 5))
        return p
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
