import SwiftUI

/// Chips under the header: what kind of card, which topic, which site.
/// Topics and sites come from the cards themselves, so new ones appear without an app update.
struct FilterBar: View {
    let store: FeedStore

    var body: some View {
        @Bindable var store = store
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: !store.filter.isActive) { store.filter = FeedFilter() }
                chip("News", selected: store.filter.kind == "news") { toggleKind("news") }
                chip("Lessons", selected: store.filter.kind == "lesson") { toggleKind("lesson") }
                if store.hasJapanese {
                    chip("日本語", selected: store.filter.japanese) { store.filter.japanese.toggle() }
                }
                divider
                ForEach(store.topics, id: \.self) { topic in
                    chip(topic.title, selected: store.filter.topic == topic) {
                        store.filter.topic = store.filter.topic == topic ? nil : topic
                    }
                }
                if !store.sites.isEmpty {
                    divider
                    siteMenu
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .sensoryFeedback(.selection, trigger: store.filter)
    }

    private var divider: some View {
        Rectangle().fill(Theme.sep).frame(width: 1, height: 20)
    }

    private func toggleKind(_ kind: String) {
        store.filter.kind = store.filter.kind == kind ? nil : kind
    }

    private var siteMenu: some View {
        let selected = store.sites.first { $0.key == store.filter.siteKey }
        return Menu {
            Button("All sites") { store.filter.siteKey = nil }
            ForEach(store.sites, id: \.key) { site in
                Button(site.name) { store.filter.siteKey = site.key }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selected?.name ?? "Sites").lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .modifier(ChipStyle(selected: selected != nil))
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).modifier(ChipStyle(selected: selected)) }
            .buttonStyle(PressStyle())
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct ChipStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .foregroundStyle(selected ? Theme.onAccent : Theme.ink)
            .background(selected ? Theme.accent : Theme.fill, in: Capsule())
    }
}
