import SwiftUI

/// Quests wie im Browser: Reiter Daily / Weekly / Milestones, je Quest eine
/// Karte mit Fortschrittsbalken und rechts entweder die Belohnung (noch offen),
/// der Abholknopf (geschafft) oder "Abgeholt". Nur mit Konto.
struct QuestsView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var tab: Int = 0
    @State private var tally: QuestOverview?
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var claiming: String?
    @State private var notice: String?

    private let tabNames: [String] = ["Daily", "Weekly", "Milestones"]

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            ScrollView {
                VStack(spacing: 10) {
                    Text("Complete quests to earn Spots. New goals unlock as you play.")
                        .font(.brand(13))
                        .foregroundColor(Palette.faint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let f = errorMessage {
                        Text(f)
                            .font(.brand(13, .semibold))
                            .foregroundColor(Palette.bad)
                            .padding(.top, 20)
                    } else if loading && tally == nil {
                        ProgressView().tint(Palette.accent).padding(.top, 40)
                    } else if items.isEmpty {
                        Text("Nothing here right now.")
                            .font(.brand(13))
                            .foregroundColor(Palette.faint)
                            .padding(.top, 40)
                    }
                    ForEach(items) { q in
                        QuestCard(quest: q, isClaiming: claiming == q.id) {
                            Task { await claim(q) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable { await load() }
        }
        .background(Palette.base.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let m = notice {
                Text(m)
                    .font(.brand(14, .semibold))
                    .foregroundColor(Palette.foreground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(GlassPanel(radius: 999))
                    .padding(.top, 8)
                    .task(id: m) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        notice = nil
                    }
            }
        }
        .task { await load() }
    }

    private var items: [QuestItem] {
        guard let s = tally else { return [] }
        switch tab {
        case 1: return s.weeklyQuests
        case 2: return s.milestones
        default: return s.dailyQuests
        }
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
            Text("Quests")
                .font(.brand(24, .heavy))
                .foregroundColor(Palette.foreground)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabNames.count, id: \.self) { i in
                let on: Bool = tab == i
                Button {
                    Haptics.tap()
                    tab = i
                } label: {
                    VStack(spacing: 0) {
                        Text(tabNames[i])
                            .font(.brand(13, .semibold))
                            .foregroundColor(on ? Palette.foreground : Palette.faint)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                        Rectangle()
                            .fill(on ? Palette.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .background(on ? Palette.accent.opacity(0.12) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    @MainActor
    private func load() async {
        loading = true
        errorMessage = nil
        do {
            let s: QuestOverview = try await api.fetch("/quests")
            tally = s
        } catch {
            errorMessage = error.localizedDescription
        }
        loading = false
    }

    @MainActor
    private func claim(_ q: QuestItem) async {
        guard claiming == nil else { return }
        claiming = q.id
        defer { claiming = nil }
        do {
            let a: ClaimResult = try await api.transmit("/quests/claim", ["questId": q.id])
            if let n = a.newSpots { api.setSpots(n) }
            Haptics.correct()
            notice = "+\(a.reward) Spots"
            await load()
        } catch {
            Haptics.wrong()
            notice = error.localizedDescription
        }
    }
}

private struct QuestCard: View {
    let quest: QuestItem
    let isClaiming: Bool
    let claim: () -> Void

    var body: some View {
        let isOpen: Bool = quest.finished && !quest.isClaimed
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: quest.isClaimed ? "checkmark" : "target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.accent.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.brand(14, .heavy))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(2)
                    Text("\(quest.tally) / \(quest.goal)")
                        .font(.brand(11))
                        .foregroundColor(Palette.faint)
                }
                Spacer(minLength: 0)
                rightSide
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(Palette.gradient)
                            .frame(width: geo.size.width * CGFloat(quest.fraction))
                    }
                }
                .frame(height: 8)
                Text("\(Int((quest.fraction * 100).rounded()))%")
                    .font(.mono(10))
                    .foregroundColor(quest.tally > 0 ? Palette.accent : Palette.faint)
                    .frame(minWidth: 32, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(shape.fill(isOpen ? Color(hex: 0x140E32) : Palette.surface))
        .overlay(shape.strokeBorder(isOpen ? Palette.accent.opacity(0.4) : Palette.border, lineWidth: 1))
        .opacity(quest.isClaimed ? 0.65 : 1)
    }

    private var name: String {
        if let n = QuestItem.names.first(where: { $0.id == quest.id }) { return n.en }
        return quest.id
    }

    @ViewBuilder
    private var rightSide: some View {
        if quest.isClaimed {
            Text("Claimed")
                .font(.brand(10, .bold))
                .foregroundColor(Palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.accent.opacity(0.15)))
        } else if quest.finished {
            Button(action: claim) {
                HStack(spacing: 3) {
                    Text("+\(quest.prize)").font(.brand(12, .bold))
                    Image(systemName: "music.note").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Palette.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.gradient))
                .opacity(isClaiming ? 0.6 : 1)
            }
            .buttonStyle(BubblePressStyle())
            .disabled(isClaiming)
        } else {
            HStack(spacing: 3) {
                Text("+\(quest.prize)").font(.brand(12, .bold))
                Image(systemName: "music.note").font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(Color(hex: 0xF59E0B))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color(hex: 0xF59E0B).opacity(0.1)))
            .overlay(Capsule().strokeBorder(Color(hex: 0xF59E0B).opacity(0.3), lineWidth: 1))
        }
    }
}

// MARK: - Taegliche Belohnung

/// Erscheint beim Oeffnen, wenn es heute etwas abzuholen gibt - wie im Browser.
struct DailyBonusSheet: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    let bonus: DailyBonus
    @State private var claiming = false
    @State private var outcome: DailyBonusClaim?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 18) {
            Text("DAILY REWARD").eyebrow()
            Text("Day \(outcome?.streakDay ?? bonus.dayNumber)")
                .font(.brand(34, .heavy))
                .foregroundStyle(Palette.gradientHero)
            HStack(spacing: 10) {
                RewardTile(symbol: "music.note", amount: outcome?.spots ?? bonus.spots, unit: "SPOTS", hue: Palette.good)
                if (outcome?.xp ?? bonus.xp) > 0 {
                    RewardTile(symbol: "star.fill", amount: outcome?.xp ?? bonus.xp, unit: "XP", hue: Palette.accent)
                }
                if (outcome?.gold ?? bonus.gold) > 0 {
                    RewardTile(symbol: "trophy.fill", amount: outcome?.gold ?? bonus.gold, unit: "GS", hue: Palette.gold)
                }
            }
            Text("Miss a day and the streak starts over at day 1.")
                .font(.brand(12))
                .foregroundColor(Palette.faint)
                .multilineTextAlignment(.center)
            if let f = errorMessage {
                Text(f).font(.brand(12, .semibold)).foregroundColor(Palette.bad)
            }
            if outcome == nil {
                Button {
                    Task { await claim() }
                } label: {
                    Text(claiming ? "…" : "Collect")
                }
                .buttonStyle(PrimaryButtonStyle(dimmed: claiming))
                .disabled(claiming)
            } else {
                Button("Done") { close() }
                    .buttonStyle(PrimaryButtonStyle(hue: Palette.rim))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Palette.base.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    @MainActor
    private func claim() async {
        claiming = true
        defer { claiming = false }
        do {
            let a: DailyBonusClaim = try await api.transmit("/daily-checkin")
            if a.isClaimed {
                outcome = a
                Haptics.correct()
                await api.refreshProfile()
            } else {
                errorMessage = "Already collected today."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct RewardTile: View {
    let symbol: String
    let amount: Int
    let unit: String
    let hue: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(hue)
            Text("+\(amount)")
                .font(.mono(16))
                .foregroundColor(Palette.foreground)
            Text(unit)
                .font(.brand(9, .black))
                .tracking(1)
                .foregroundColor(Palette.faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(GlassPanel(radius: 14))
    }
}
