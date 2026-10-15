import SwiftUI

struct ReviewView: View {
    let store: ReviewStore

    var body: some View {
        VStack(spacing: 0) {
            header
            if let card = store.current {
                progress
                cardView(card)
                controls(card)
            } else {
                emptyState
            }
        }
        .background(Theme.bg)
        .task { await store.load() }
        .sensoryFeedback(.selection, trigger: store.index)
    }

    private var header: some View {
        HStack {
            Text("Review").font(.system(.title2, weight: .bold)).tracking(-0.4)
            Spacer()
            if store.total > 0, !store.isFinished {
                Text("\(store.index + 1) of \(store.total)").font(.subheadline).foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 48)
    }

    private var progress: some View {
        HStack(spacing: 4) {
            ForEach(0..<store.total, id: \.self) { i in
                Capsule()
                    .fill(i < store.index ? Theme.ink : (i == store.index ? Theme.accent : Theme.sep))
                    .frame(height: 3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .animation(.spring(response: 0.35, dampingFraction: 1), value: store.index)
    }

    private func cardView(_ card: Card) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(card.topic.title).font(.subheadline).foregroundStyle(Theme.muted)
            Text(card.reviewFront)
                .font(.system(.title2, weight: .bold)).tracking(-0.4)
            if store.showingAnswer {
                Divider().overlay(Theme.sep)
                Text(card.reviewBack).font(.title3).fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .offset(y: 8)))
            } else {
                Spacer()
                Text("Answer it in your head first.").font(.subheadline).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 28))
        .padding(.horizontal, 12)
        .animation(.spring(response: 0.35, dampingFraction: 1), value: store.showingAnswer)
        .id(card.id)
    }

    @ViewBuilder
    private func controls(_ card: Card) -> some View {
        Group {
            if store.showingAnswer {
                HStack(spacing: 8) {
                    ForEach(Rating.allCases, id: \.self) { rating in
                        Button { store.rate(rating) } label: {
                            VStack(spacing: 2) {
                                Text(rating.title).font(.subheadline.weight(.semibold))
                                Text(store.interval(for: rating, on: card) ?? " ")
                                    .font(.caption).opacity(rating == .good ? 0.8 : 1)
                                    .foregroundStyle(rating == .good ? Theme.onAccent : Theme.muted)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(rating == .good ? Theme.accent : Theme.fill, in: RoundedRectangle(cornerRadius: 18))
                            .foregroundStyle(rating == .good ? Theme.onAccent : Theme.ink)
                        }
                        .buttonStyle(PressStyle())
                    }
                }
            } else {
                Button { store.showingAnswer = true } label: {
                    Text("Show answer").font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Theme.onAccent)
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            if store.isLoading {
                ProgressView()
            } else if let error = store.error {
                Text(error).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Button("Try again") { Task { await store.load() } }
                    .buttonStyle(.borderedProminent).tint(Theme.accent).foregroundStyle(Theme.onAccent)
            } else {
                Text(store.isFinished ? "All caught up" : "Nothing due")
                    .font(.system(.title, weight: .bold)).tracking(-0.4)
                Text(store.isFinished
                     ? "Those cards will come back when it's time. Keep scrolling the feed to learn more."
                     : "Cards you get wrong, and flashcards you rate, show up here when they're due.")
                    .font(.body).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                Button("Check again") { Task { await store.load() } }
                    .buttonStyle(.bordered).tint(Theme.accent).padding(.top, 8)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}
