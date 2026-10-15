import SwiftUI

/// One scrolling row: All, then the sites (pick any number), then News / Lessons,
/// and a Topics menu (pick any number). Sites and topics come from the loaded cards,
/// so new ones appear without an app update.
struct FilterBar: View {
    let store: FeedStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: !store.filter.isActive) { store.filter = FeedFilter() }
                ForEach(store.sites, id: \.key) { site in
                    chip(site.name, selected: store.filter.siteKeys.contains(site.key)) { toggle(site.key) }
                }
                if !store.sites.isEmpty { divider }
                chip("News", selected: store.filter.kind == "news") { toggleKind("news") }
                chip("Lessons", selected: store.filter.kind == "lesson") { toggleKind("lesson") }
                if store.hasJapanese {
                    chip("日本語", selected: store.filter.japanese) { store.filter.japanese.toggle() }
                }
                if !store.topics.isEmpty { topicsMenu }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .sensoryFeedback(.selection, trigger: store.filter)
    }

    private var divider: some View {
        Rectangle().fill(Theme.sep).frame(width: 1, height: 20)
    }

    private func toggle(_ siteKey: String) {
        if store.filter.siteKeys.contains(siteKey) { store.filter.siteKeys.remove(siteKey) }
        else { store.filter.siteKeys.insert(siteKey) }
    }

    private func toggleKind(_ kind: String) {
        store.filter.kind = store.filter.kind == kind ? nil : kind
    }

    private var topicsMenu: some View {
        let chosen = store.filter.topics
        return Menu {
            ForEach(store.topics, id: \.self) { topic in
                Toggle(topic.title, isOn: Binding(
                    get: { store.filter.topics.contains(topic) },
                    set: { on in
                        if on { store.filter.topics.insert(topic) } else { store.filter.topics.remove(topic) }
                    }
                ))
            }
            if !chosen.isEmpty {
                Divider()
                Button("Clear topics", role: .destructive) { store.filter.topics = [] }
            }
        } label: {
            HStack(spacing: 4) {
                Text(label(for: chosen)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .modifier(ChipStyle(selected: !chosen.isEmpty))
        }
        .menuActionDismissBehavior(.disabled)
    }

    private func label(for chosen: Set<Topic>) -> String {
        switch chosen.count {
        case 0: "Topics"
        case 1: chosen.first!.title
        default: "\(chosen.count) topics"
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).lineLimit(1).modifier(ChipStyle(selected: selected)) }
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
