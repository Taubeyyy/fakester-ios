import SwiftUI

/// "Board" vom Startbildschirm: die Bestenliste wie im Browser, mit Reitern
/// fuer XP, Siege, Highscore, Spiele und richtige Antworten. Oeffentlich -
/// Gaeste sehen sie genauso.
struct LeaderboardView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var sortKey: String = "xp"
    @State private var entries: [Leaderboard.Entry] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            tab
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let f = errorMessage {
                        Text(f)
                            .font(.brand(13, .semibold))
                            .foregroundColor(Palette.bad)
                            .padding(.top, 30)
                    } else if loading && entries.isEmpty {
                        ProgressView().tint(Palette.accent).padding(.top, 40)
                    } else if entries.isEmpty {
                        Text("Nobody on the board yet.")
                            .font(.brand(13))
                            .foregroundColor(Palette.faint)
                            .padding(.top, 40)
                    }
                    ForEach(entries) { e in
                        LeaderboardRow(entry: e, unit: unit, isMe: e.id == api.me?.id.text)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .refreshable { await load() }
        }
        .background(Palette.base.ignoresSafeArea())
        .task(id: sortKey) { await load() }
    }

    private var unit: String {
        Leaderboard.sortOptions.first { $0.id == sortKey }?.unit ?? ""
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Palette.foreground)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Palette.surface))
                    .overlay(Circle().strokeBorder(Palette.rim, lineWidth: 1))
            }
            Text("Leaderboard")
                .font(.brand(24, .heavy))
                .foregroundColor(Palette.foreground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var tab: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Leaderboard.sortOptions) { s in
                    let on: Bool = s.id == sortKey
                    Button {
                        Haptics.tap()
                        sortKey = s.id
                    } label: {
                        Text(s.name)
                            .font(.brand(12, .semibold))
                            .foregroundColor(on ? Palette.onAccent : Palette.faint)
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(Capsule().fill(on ? AnyShapeStyle(Palette.gradient) : AnyShapeStyle(Palette.surface)))
                            .overlay(Capsule().strokeBorder(on ? Color.clear : Palette.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
    }

    @MainActor
    private func load() async {
        loading = true
        errorMessage = nil
        do {
            let b: Leaderboard = try await api.fetch("/leaderboard", ["sort": sortKey, "limit": "100"])
            entries = b.entries
        } catch {
            errorMessage = error.localizedDescription
            entries = []
        }
        loading = false
    }
}

private struct LeaderboardRow: View {
    let entry: Leaderboard.Entry
    let unit: String
    let isMe: Bool

    var body: some View {
        HStack(spacing: 12) {
            standing
            Text(entry.name)
                .font(.brand(14, .heavy))
                .foregroundColor(isMe ? Palette.accent : Palette.foreground)
                .lineLimit(1)
            if entry.pro {
                Text("PRO")
                    .font(.brand(9, .black))
                    .foregroundColor(Palette.onGold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.gradientGold))
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(entry.amount)")
                    .font(.mono(14))
                    .foregroundColor(entry.rankNumber <= 3 ? Palette.gold : Palette.foreground)
                Text(unit)
                    .font(.brand(10, .bold))
                    .foregroundColor(Palette.faint)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(GlassPanel(radius: 14, rim: isMe ? Palette.accent.opacity(0.6) : (entry.rankNumber == 1 ? Palette.gold.opacity(0.5) : Palette.rim)))
    }

    private var standing: some View {
        let isTopThree: Bool = entry.rankNumber <= 3
        return Text("\(entry.rankNumber)")
            .font(.mono(13))
            .foregroundColor(isTopThree ? Palette.onGold : Palette.subdued)
            .frame(width: 30, height: 30)
            .background(Circle().fill(isTopThree ? AnyShapeStyle(Palette.gradientGold) : AnyShapeStyle(Color.white.opacity(0.06))))
    }
}
