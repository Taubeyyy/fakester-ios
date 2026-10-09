import SwiftUI

/// Quests as in the browser (`_3`): a line of intro, the Daily / Weekly /
/// Milestones / Awards tabs, the reset countdown, then one card per quest -
/// or per award with its tier dots. Pull down to refresh. Account only.
/// Measurements from the website at 375 × 812 (k-quests, k-quests-awards).
struct QuestsView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    /// "Daily", "Weekly", "Milestones" or "Awards".
    var initialTab: String = "Daily"

    @State private var tab: String = ""
    @State private var overview: QuestOverview?
    @State private var awards: AchievementBoard?
    @State private var loading = true
    @State private var claiming: String?
    @State private var toast: CosmeticToast?

    private static let tabs: [(name: String, icon: LucideIcon)] = [
        ("Daily", .settings), ("Weekly", .bell), ("Milestones", .flame), ("Awards", .trophy)
    ]

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Quests", onBack: { close() })
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Complete quests to earn Spots. New goals unlock as you play.")
                            .font(.brand(13))
                            .foregroundColor(Palette.subdued)
                            .fixedSize(horizontal: false, vertical: true)
                        tabBar
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
                .refreshable { await load() }
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .onAppear { if tab.isEmpty { tab = initialTab } }
        .task { await load() }
    }

    private var current: String { tab.isEmpty ? initialTab : tab }

    // MARK: Tabs

    /// One bar, corners 16, glass rgba(24,23,39,.9); the active tab tinted
    /// with the accent and underlined 2 pt.
    private var tabBar: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 0) {
            ForEach(0..<QuestsView.tabs.count, id: \.self) { i in
                tabButton(QuestsView.tabs[i].name, icon: QuestsView.tabs[i].icon)
            }
        }
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private func tabButton(_ name: String, icon: LucideIcon) -> some View {
        let on: Bool = current == name
        return Button {
            Haptics.tap()
            tab = name
        } label: {
            HStack(spacing: 6) {
                LucideGlyph(icon: icon, size: 12)
                Text(name)
                    .font(.brand(13, .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(on ? Palette.foreground : Palette.subdued)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(on ? Palette.accent.opacity(0.12) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(on ? Palette.accent : Color.clear).frame(height: 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if current == "Daily" || current == "Weekly" {
            HStack(spacing: 6) {
                LucideGlyph(icon: .clock, size: 12)
                Text(QuestReset.text(weekly: current == "Weekly"))
                    .font(.brand(12, .semibold))
            }
            .foregroundColor(Color(hex: 0xF59E0B))
        }
        if loading && overview == nil {
            CosmeticNotice(text: "Loading your quests…", loading: true)
        }
        if current == "Awards" {
            awardsList
        } else {
            let list: [QuestItem] = quests
            VStack(spacing: 16) {
                ForEach(list) { q in
                    QuestCard(quest: q, claiming: claiming == q.id) {
                        Task { await claim(q) }
                    }
                }
            }
        }
    }

    private var quests: [QuestItem] {
        guard let o = overview else { return [] }
        switch current {
        case "Weekly": return o.weeklyQuests
        case "Milestones": return o.milestones
        default: return o.dailyQuests
        }
    }

    @ViewBuilder
    private var awardsList: some View {
        if let board = awards, !board.achievements.isEmpty {
            HStack(spacing: 8) {
                LucideGlyph(icon: .trophy, size: 12)
                Text("\(board.unlocked) of \(board.total) tiers unlocked")
                    .font(.brand(12, .semibold))
            }
            .foregroundColor(Palette.gold)
            .padding(.top, -4)
            VStack(spacing: 16) {
                ForEach(board.achievements) { a in
                    AwardCard(award: a, claiming: claiming == "\(a.id)#\(a.nextClaim?.index ?? -1)") {
                        Task { await claimAward(a) }
                    }
                }
            }
        } else if !loading {
            VStack(spacing: 8) {
                LucideGlyph(icon: .trophy, size: 20).foregroundColor(Color(hex: 0x2A2848))
                Text("No awards to show right now.")
                    .font(.brand(12))
                    .foregroundColor(Palette.subdued)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }

    // MARK: Data

    @MainActor
    private func load() async {
        loading = true
        async let q: QuestOverview? = try? await api.fetch("/quests")
        async let a: AchievementBoard? = try? await api.fetch("/achievements")
        var quests: QuestOverview? = await q
        var board: AchievementBoard? = await a
        #if DEBUG
        if quests == nil { quests = ScreenshotScene.sampleQuests }
        if board == nil { board = ScreenshotScene.sampleAwards }
        #endif
        if let quests = quests {
            overview = quests
        } else {
            withAnimation { toast = CosmeticToast(text: "Could not load your quests", isError: true) }
        }
        awards = board
        loading = false
    }

    @MainActor
    private func claim(_ q: QuestItem) async {
        guard claiming == nil else { return }
        claiming = q.id
        do {
            let answer: ClaimResult = try await api.call("/quests/claim", body: ["questId": q.id])
            if let n = answer.newSpots { api.setSpots(n) }
            Haptics.correct()
            withAnimation { toast = CosmeticToast(text: "+\(answer.reward) Spots", isError: false) }
            await load()
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not claim that quest" : text, isError: true) }
        }
        claiming = nil
    }

    @MainActor
    private func claimAward(_ a: Achievement) async {
        guard claiming == nil, let next = a.nextClaim else { return }
        claiming = "\(a.id)#\(next.index)"
        do {
            let answer: ClaimResult = try await api.call("/achievements/claim", body: ["id": a.id, "tier": next.index])
            if let n = answer.newSpots { api.setSpots(n) }
            Haptics.correct()
            withAnimation { toast = CosmeticToast(text: "+\(answer.reward) Spots", isError: false) }
            await load()
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not claim that award" : text, isError: true) }
        }
        claiming = nil
    }
}

/// One quest: icon box 40 (accent, a tick once claimed), name + "0 / 3", the
/// reward on the right (amber while open, an accent button once done,
/// "Claimed" after), then the bar with the percentage.
private struct QuestCard: View {
    let quest: QuestItem
    let claiming: Bool
    let onClaim: () -> Void

    var body: some View {
        let ready: Bool = quest.finished && !quest.isClaimed
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let percent: Int = Int((quest.fraction * 100).rounded())
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                LucideGlyph(icon: quest.isClaimed ? .check : QuestCard.icon(quest.id), size: 17)
                    .foregroundColor(Palette.accent)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Palette.accentDeep.opacity(0.18)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .circular).strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1))
                    .shadow(color: Palette.accentDeep.opacity(0.2), radius: 6)
                VStack(alignment: .leading, spacing: 0) {
                    Text(QuestCard.name(quest.id))
                        .font(.brand(14, .bold))
                        .foregroundColor(Palette.foreground)
                    Text("\(quest.tally) / \(quest.goal)")
                        .font(.brand(11))
                        .foregroundColor(Palette.subdued)
                }
                Spacer(minLength: 0)
                trailing
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(Palette.accent)
                            .frame(width: geo.size.width * CGFloat(quest.fraction))
                            .shadow(color: Palette.accentDeep.opacity(0.4), radius: 4)
                    }
                }
                .frame(height: 8)
                Text("\(percent)%")
                    .font(.brand(10, .bold))
                    .monospacedDigit()
                    .foregroundColor(quest.tally > 0 ? Palette.accent : Palette.subdued)
                    .frame(minWidth: 28, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(shape.fill(ready ? Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 50 / 255, opacity: 0.95)
                                     : Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)))
        .overlay(shape.strokeBorder(ready ? Palette.accent.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1))
        .opacity(quest.isClaimed ? 0.65 : 1)
    }

    @ViewBuilder
    private var trailing: some View {
        if quest.isClaimed {
            Text("Claimed")
                .font(.brand(10, .bold))
                .foregroundColor(Palette.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.accent.opacity(0.15)))
        } else if quest.finished {
            Button(action: onClaim) {
                HStack(spacing: 4) {
                    Text("+\(quest.prize)")
                    LucideGlyph(icon: .music2, size: 10)
                }
                .font(.brand(12, .bold))
                .foregroundColor(Palette.onAccent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Palette.accent))
                .opacity(claiming ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(claiming)
        } else {
            AmberReward(amount: quest.prize, fill: 0.1, edge: 0.3)
        }
    }

    /// `g3`: names and icons by quest ID.
    static func name(_ id: String) -> String {
        QuestItem.names.first { $0.id == id }?.en ?? id
    }

    static func icon(_ id: String) -> LucideIcon {
        switch id {
        case "first_icon": return .smile
        case "first_title": return .type
        case "first_bg": return .image
        case "play_5", "play_25", "d_play3", "w_play20": return .gamepad2
        case "win_1", "d_win1": return .trophy
        case "win_10", "w_win5": return .crown
        case "correct_50", "d_correct10": return .check
        case "streak_3": return .flame
        case "collector_10": return .layers
        case "w_correct100": return .target
        default: return .star
        }
    }
}

/// "+60 ♪" in amber: the reward while it is still open.
private struct AmberReward: View {
    let amount: Int
    let fill: Double
    let edge: Double

    var body: some View {
        let amber = Color(hex: 0xF59E0B)
        HStack(spacing: 4) {
            Text("+\(amount)").font(.brand(12, .bold))
            LucideGlyph(icon: .music2, size: 10)
        }
        .foregroundColor(amber)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(amber.opacity(fill)))
        .overlay(Capsule().strokeBorder(amber.opacity(edge), lineWidth: 1))
    }
}

/// One award: the Font Awesome icon in gold, "value / goal · tier n/total",
/// the reward (a gold gradient button when a tier waits), a gold bar and one
/// dot per tier (gold claimed, amber reached, grey ahead).
private struct AwardCard: View {
    let award: Achievement
    let claiming: Bool
    let onClaim: () -> Void

    var body: some View {
        let waiting: Bool = award.nextClaim != nil
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                CosmeticGlyph(iconClass: award.icon, size: 16, tint: Palette.gold)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color(hex: 0xF59E0B).opacity(0.14)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .circular).strokeBorder(Color(hex: 0xF59E0B).opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 0) {
                    Text(award.name)
                        .font(.brand(14, .bold))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                    (Text(award.maxed ? "Maxed — \(groupedNumber(award.value))"
                          : "\(groupedNumber(award.value)) / \(groupedNumber(award.nextGoal))")
                     + Text("  · tier \(award.level)/\(award.total)"))
                        .font(.brand(11))
                        .foregroundColor(Palette.subdued)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                trailing
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(LinearGradient(colors: [Color(hex: 0xB45309), Palette.gold], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(min(100, max(0, award.progress)) / 100))
                    }
                }
                .frame(height: 8)
                HStack(spacing: 4) {
                    ForEach(0..<award.tiers.count, id: \.self) { i in
                        Circle()
                            .fill(award.tiers[i].claimed ? Palette.gold
                                  : (award.tiers[i].reached ? Color(hex: 0xF59E0B).opacity(0.55) : Color.white.opacity(0.14)))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(shape.fill(waiting ? Color(.sRGB, red: 30 / 255, green: 22 / 255, blue: 6 / 255, opacity: 0.95)
                                       : Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.92)))
        .overlay(shape.strokeBorder(waiting ? Color(hex: 0xF59E0B).opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1))
        .opacity(award.maxed && !waiting ? 0.7 : 1)
    }

    @ViewBuilder
    private var trailing: some View {
        if let next = award.nextClaim {
            Button(action: onClaim) {
                HStack(spacing: 4) {
                    Text("+\(next.reward)")
                    LucideGlyph(icon: .music2, size: 10)
                }
                .font(.brand(12, .bold))
                .foregroundColor(Palette.base)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(LinearGradient(colors: [Color(hex: 0xB45309), Palette.gold],
                                                          startPoint: .topLeading, endPoint: .bottomTrailing)))
                .opacity(claiming ? 0.6 : 1)
            }
            .buttonStyle(.plain)
            .disabled(claiming)
        } else if award.maxed {
            Text("Complete")
                .font(.brand(10, .bold))
                .foregroundColor(Palette.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: 0xF59E0B).opacity(0.15)))
        } else {
            AmberReward(amount: award.nextReward, fill: 0.08, edge: 0.25)
        }
    }
}

// MARK: - Daily reward

/// Shown on launch when there is something to collect today - as in the browser.
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
