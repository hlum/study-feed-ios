import SwiftUI

struct YouView: View {
    @Environment(APIClient.self) private var api
    let store: FeedStore
    let goToFeed: () -> Void

    @State private var status: String?
    @State private var reminderOn = Reminder.isEnabled
    @State private var reminderDenied = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("You").font(.system(.title2, weight: .bold)).tracking(-0.4)
                    .frame(height: 48, alignment: .leading)

                if let s = store.stats {
                    if s.streak > 0 && !s.todayDone { riskBanner(s) }
                    streak(s)
                    level(s)
                    week(s)
                    badges(s)
                } else if let error = store.error {
                    Text(error).foregroundStyle(Theme.muted)
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }

                settings
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .refreshable { await store.reloadStats() }
        .task { await store.reloadStats() }
        .background(Theme.bg)
    }

    // MARK: Sections

    private func riskBanner(_ s: Stats) -> some View {
        HStack(spacing: 14) {
            Text("Your streak ends at midnight. One card keeps it alive.")
                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.onAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: goToFeed) {
                Text("Keep it").font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16).frame(height: 44)
                    .background(Theme.onAccent, in: Capsule()).foregroundStyle(Theme.accent)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.vertical, 12).padding(.leading, 18).padding(.trailing, 12)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 20))
    }

    private func streak(_ s: Stats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(s.streak)").font(.system(size: 88, weight: .heavy)).tracking(-4)
                    .contentTransition(.numericText(value: Double(s.streak)))
                Text(s.streak == 1 ? "day streak" : "day streak").font(.headline)
            }
            Text(s.todayDone ? "Today is done." : "Study a card and answer one quiz to count today.")
                .font(.subheadline).foregroundStyle(Theme.muted)
            Text(s.freezes > 0
                 ? "\(s.freezes) streak freeze\(s.freezes == 1 ? "" : "s") saved. One is used automatically if you miss a day."
                 : "No streak freezes yet. You earn one for every 7 days in a row.")
                .font(.subheadline).foregroundStyle(Theme.muted)
        }
    }

    private func level(_ s: Stats) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(s.level)").font(.headline)
                Spacer()
                Text("\(s.levelXp) of \(s.levelNext) XP").font(.subheadline).foregroundStyle(Theme.muted)
            }
            GeometryReader { geo in
                Capsule().fill(Theme.sep)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.accent)
                            .frame(width: geo.size.width * min(1, Double(s.levelXp) / Double(max(s.levelNext, 1))))
                    }
            }
            .frame(height: 4)
        }
    }

    private func week(_ s: Stats) -> some View {
        let delta = s.weekCards - s.lastWeekCards
        return HStack(spacing: 8) {
            tile(value: "\(s.weekCards)", label: "cards this week", accent: false)
            tile(value: delta > 0 ? "+\(delta)" : "\(delta)", label: "vs. last week", accent: delta > 0)
        }
    }

    private func tile(value: String, label: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value).font(.system(size: 32, weight: .heavy)).tracking(-1)
                .foregroundStyle(accent ? Theme.accent : Theme.ink)
            Text(label).font(.subheadline).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.fill, in: RoundedRectangle(cornerRadius: 20))
    }

    private func badges(_ s: Stats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Badges").font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(s.badges) { badge in
                    HStack(spacing: 6) {
                        if badge.earned { Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(Theme.accent) }
                        Text(badge.name).font(.subheadline)
                    }
                    .foregroundStyle(badge.earned ? Theme.ink : Theme.muted)
                    .padding(.horizontal, 14).frame(height: 36)
                    .background(badge.earned ? Theme.fill : .clear, in: Capsule())
                    .overlay(Capsule().strokeBorder(badge.earned ? .clear : Theme.sep, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                    .accessibilityLabel("\(badge.name), \(badge.earned ? "earned" : "not yet earned")")
                }
            }
        }
    }

    private var settings: some View {
        @Bindable var api = api
        return VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.headline)
            VStack(alignment: .leading, spacing: 10) {
                Text("Server").font(.subheadline).foregroundStyle(Theme.muted)
                TextField("http://100.x.y.z:8001", text: $api.baseURL)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(.horizontal, 14).frame(height: 48)
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 12))
                Button("Test connection") {
                    Task {
                        do {
                            let s = try await api.stats()
                            status = "Connected. Level \(s.level), \(s.streak) day streak."
                            await store.refresh()
                        } catch {
                            status = error.localizedDescription
                        }
                    }
                }
                .foregroundStyle(Theme.accent).frame(minHeight: 44)
                if let status { Text(status).font(.footnote).foregroundStyle(Theme.muted) }
                Text("Your phone must be on the same Tailscale network as the server.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            .padding(16).background(Theme.fill, in: RoundedRectangle(cornerRadius: 20))

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Evening streak reminder", isOn: $reminderOn)
                    .tint(Theme.accent)
                    .onChange(of: reminderOn) { _, on in
                        Task {
                            if on {
                                reminderDenied = !(await Reminder.enable())
                                reminderOn = !reminderDenied
                                if let s = store.stats { Reminder.update(with: s) }
                            } else {
                                Reminder.disable()
                            }
                        }
                    }
                Text(reminderDenied
                     ? "Notifications are off for this app. Turn them on in Settings to get reminders."
                     : "At 8pm, only if you haven't studied yet today.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            }
            .padding(16).background(Theme.fill, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

/// Wraps its children onto as many lines as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, width: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            width = max(width, x - spacing)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
