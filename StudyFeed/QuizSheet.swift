import SwiftUI

/// One question, four options. The pick shows instantly (the card carries the right answer),
/// then the server's verdict arrives with the XP and level, which is the reward moment.
struct QuizSheet: View {
    @Environment(APIClient.self) private var api
    @Environment(\.dismiss) private var dismiss

    let card: Card
    let onAnswered: () -> Void

    @State private var picked: Int?
    @State private var result: AnswerResult?
    @State private var failed = false
    @State private var shownXP = 0
    @State private var barFraction = 0.0
    @State private var successTick = 0
    @State private var errorTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            if let quiz = card.quiz {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(quiz.question)
                            .font(.system(.title2, weight: .bold)).tracking(card.tracking(-0.4))
                        VStack(spacing: 8) {
                            ForEach(Array(quiz.options.enumerated()), id: \.offset) { i, text in
                                option(i, text, quiz: quiz)
                            }
                        }
                    }
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
                }
            } else {
                Text("This card has no quiz.").foregroundStyle(Theme.muted).padding(20)
            }
            Spacer(minLength: 0)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let quiz = card.quiz, let picked { panel(quiz: quiz, right: picked == quiz.answer) }
        }
        .background(Theme.bg)
        .presentationBackground(Theme.bg)
        .environment(\.locale, card.locale)
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: successTick)
        .sensoryFeedback(.error, trigger: errorTick)
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Text("\(card.topic.title) quiz").font(.subheadline).foregroundStyle(Theme.muted)
            Spacer()
            if card.isRare {
                Text("2× XP").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
    }

    private func option(_ i: Int, _ text: String, quiz: Quiz) -> some View {
        let answered = picked != nil
        let isRight = answered && i == quiz.answer
        let isWrongPick = answered && i == picked && i != quiz.answer
        let color: Color = isRight ? Theme.accent : Theme.wrong
        let mark = isRight ? "Correct" : (isWrongPick ? "Your pick" : "")

        return Button { choose(i, quiz: quiz) } label: {
            HStack(alignment: .top, spacing: 14) {
                Text(["A", "B", "C", "D"][safe: i] ?? "").font(.mono(.subheadline)).foregroundStyle(Theme.muted)
                Text(text).font(.body).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(mark).font(.footnote.weight(.semibold)).foregroundStyle(color)
            }
            .padding(16)
            .frame(minHeight: 58)
            .background(Theme.fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isRight || isWrongPick ? color : .clear, lineWidth: 1.5))
        }
        .buttonStyle(PressStyle())
        .allowsHitTesting(!answered)
        .accessibilityLabel("\(["A", "B", "C", "D"][safe: i] ?? ""). \(text). \(mark)")
    }

    @ViewBuilder
    private func panel(quiz: Quiz, right: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if right {
                if card.isRare || result?.rareBonus == true {
                    Text("Rare card. Double XP.").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                }
                if let r = result {
                    if r.xp > 0 {
                        Text("+\(shownXP) XP")
                            .font(.system(size: 56, weight: .heavy)).tracking(-2)
                            .contentTransition(.numericText(value: Double(shownXP)))
                    } else {
                        Text("Correct. No XP this time, you answered this card before.")
                            .font(.headline)
                    }
                    levelBar(r)
                } else if failed {
                    Text("Correct").font(.system(.title2, weight: .bold))
                    Text("Couldn't reach the server, so no XP was counted.").font(.footnote).foregroundStyle(Theme.muted)
                } else {
                    Text("Correct").font(.system(.title2, weight: .bold))
                    ProgressView().tint(Theme.accent)
                }
            } else {
                Text("Not quite").font(.system(.title, weight: .bold)).tracking(-0.4)
            }

            if let explanation = quiz.explanation {
                Text(explanation).font(.callout).foregroundStyle(Theme.muted)
            }
            if !right {
                Text("This card comes back in your review tomorrow.").font(.callout)
            }
            Button { dismiss() } label: {
                Text("Next card").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(right ? Theme.accent : Theme.ink, in: Capsule())
                    .foregroundStyle(right ? Theme.onAccent : Theme.bg)
            }
            .buttonStyle(PressStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 12)
        .background(Color(hex: 0x1C1C1F), in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func levelBar(_ r: AnswerResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(r.leveledUp == true ? "Level up! Level \(r.level ?? 0)" : "Level \(r.level ?? 0)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let xp = r.levelXp, let next = r.levelNext {
                    Text("\(xp) of \(next)").font(.subheadline).foregroundStyle(Theme.muted)
                }
            }
            GeometryReader { geo in
                Capsule().fill(Theme.sep)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.accent).frame(width: geo.size.width * barFraction)
                    }
            }
            .frame(height: 4)
        }
    }

    // MARK: Actions

    private func choose(_ i: Int, quiz: Quiz) {
        guard picked == nil else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 1)) { picked = i }
        if i == quiz.answer { successTick += 1 } else { errorTick += 1 }
        Task {
            do {
                let r = try await api.answer(card.id, choice: i)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    result = r
                    shownXP = r.xp
                }
                if let xp = r.levelXp, let next = r.levelNext, next > 0 {
                    withAnimation(.easeOut(duration: 0.8).delay(0.15)) { barFraction = min(1, Double(xp) / Double(next)) }
                }
                onAnswered()
            } catch {
                failed = true
            }
        }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}
