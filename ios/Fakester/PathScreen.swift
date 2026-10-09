import SwiftUI

/// "Level Path" - what every level unlocks (`oN` in the web bundle): a hero
/// card with level, XP and the next level's rewards, then a timeline of every
/// level that gives something. Milestone bonuses are claimed here.
/// Measurements from the website at 375 × 812 (k-path).
struct PathView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var catalog: ItemCatalog?
    @State private var claimed: [Int] = []
    @State private var claiming: Int?
    @State private var toast: CosmeticToast?
    @State private var scrolled: CGFloat = 0
    @State private var barShown = false

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Level Path", onBack: { close() }) { spotsPill }
                scroller
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .task { await load() }
    }

    private var xp: Int { api.me?.xp ?? 0 }
    private var progress: LevelProgress { LevelProgress(xp: xp) }
    private var steps: [PathStep] { catalog.map { LevelPath.steps($0) } ?? [] }

    /// Spots in the accent here (the shop's pill is lilac): padding 6/12.
    private var spotsPill: some View {
        HStack(spacing: 6) {
            LucideGlyph(icon: .music2, size: 11)
            Text(groupedNumber(api.me?.spots ?? 0)).monospacedDigit()
        }
        .font(.brand(11, .bold))
        .foregroundColor(Palette.accent)
        .padding(.horizontal, 12)
        .frame(height: 31)
        .background(Capsule().fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
    }

    // MARK: Content

    private var scroller: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    hero
                    if catalog == nil {
                        BoardLoadingBars().padding(.vertical, 40)
                    }
                    timeline
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 48)
                .id("top")
                .background(GeometryReader { g in
                    Color.clear.preference(key: ScrollOffsetKey.self, value: -g.frame(in: .named("path")).minY)
                })
            }
            .coordinateSpace(name: "path")
            .onPreferenceChange(ScrollOffsetKey.self) { scrolled = $0 }
            .overlay(alignment: .bottomTrailing) {
                if scrolled > 320 {
                    BackToTopButton { withAnimation(.easeOut(duration: 0.35)) { reader.scrollTo("top", anchor: .top) } }
                        .padding(16)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: scrolled > 320)
            .onChange(of: catalog != nil) { loaded in
                guard loaded, let target = LevelPath.anchor(steps, level: progress.level) else { return }
                // As in the browser: after 0.4 s, the reached level slides to the middle.
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    withAnimation(.easeInOut(duration: 0.5)) { reader.scrollTo(target, anchor: .center) }
                }
            }
        }
    }

    // MARK: Hero

    /// Corners 24, accent border 30 %, a diagonal deep-purple wash and a
    /// blurred glow top left; level box 62, XP, NEXT, bar, next rewards.
    private var hero: some View {
        let p: LevelProgress = progress
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        let nextRewards: [PathReward] = steps.first { $0.level == p.level + 1 }?.rewards ?? []
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                VStack(spacing: 0) {
                    Text("LEVEL").font(.brand(10, .bold)).foregroundColor(Color.white.opacity(0.7))
                    Text("\(p.level)").font(.brand(24, .heavy)).foregroundColor(.white)
                }
                .frame(width: 62, height: 62)
                .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(Palette.accent))
                .shadow(color: Palette.accentDeep.opacity(0.5), radius: 13)
                VStack(alignment: .leading, spacing: 0) {
                    (Text(groupedNumber(p.xp) + " ").font(.brand(20, .heavy)).foregroundColor(Palette.foreground)
                        + Text("/ \(groupedNumber(p.ceiling)) XP").font(.brand(14, .semibold)).foregroundColor(Palette.subdued))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(groupedNumber(p.toNext)) XP to Level \(p.level + 1)")
                        .font(.brand(11, .medium))
                        .foregroundColor(Palette.subdued)
                }
                Spacer(minLength: 0)
                VStack(spacing: 0) {
                    Text("NEXT").font(.brand(10, .bold)).foregroundColor(Palette.subdued)
                    Text("\(p.level + 1)").font(.brand(18, .heavy)).foregroundColor(Palette.accent)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.35))
                    Capsule().fill(Palette.accent)
                        .frame(width: geo.size.width * CGFloat((barShown ? p.percent : 0) / 100))
                        .shadow(color: Palette.accentDeep.opacity(0.5), radius: 6)
                }
            }
            .frame(height: 10)
            .padding(.top, 16)
            .onAppear {
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.1)) { barShown = true }
            }
            HStack {
                Text(String(format: "%.1f%%", p.percent))
                    .font(.brand(11, .semibold))
                    .monospacedDigit()
                    .foregroundColor(Palette.accent)
                Spacer(minLength: 0)
                Text("Next reward at Level \(p.level + 1)")
                    .font(.brand(11, .medium))
                    .foregroundColor(Palette.subdued)
            }
            .padding(.top, 6)
            if !nextRewards.isEmpty {
                ChipFlow(spacing: 6) {
                    ForEach(0..<nextRewards.count, id: \.self) { i in
                        RewardChip(reward: nextRewards[i])
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(20)
        .background(
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: [
                    .init(color: Palette.accentDeep.opacity(0.35), location: 0),
                    .init(color: Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.95), location: 0.6)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle()
                    .fill(RadialGradient(colors: [Palette.accentDeep.opacity(0.4), Palette.accentDeep.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 67))
                    .frame(width: 192, height: 192)
                    .blur(radius: 30)
                    .offset(x: -58, y: -77)
            }
            .clipShape(shape)
        )
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1))
        .overlay(alignment: .top) {
            shape.stroke(Color.white.opacity(0.07), lineWidth: 1).mask(
                VStack { Rectangle().frame(height: 2); Spacer(minLength: 0) }
            )
        }
        .shadow(color: Palette.accentDeep.opacity(0.25), radius: 20)
    }

    // MARK: Timeline

    private var timeline: some View {
        let list: [PathStep] = steps
        let level: Int = progress.level
        return VStack(spacing: 0) {
            ForEach(0..<list.count, id: \.self) { i in
                PathRow(step: list[i], level: level, isLast: i == list.count - 1,
                        canClaim: LevelPath.canClaim(list[i], level: level, claimed: claimed),
                        claiming: claiming == list[i].level,
                        onClaim: { Task { await claim(list[i].level) } })
                    .id(list[i].level)
            }
        }
    }

    // MARK: Data

    @MainActor
    private func load() async {
        async let items: ItemCatalog? = try? await api.fetchAbsolute("https://fakester.app/catalog.json")
        async let rewards: LevelRewards? = try? await api.fetch("/level/rewards")
        catalog = await items
        claimed = (await rewards)?.claimed ?? []
    }

    @MainActor
    private func claim(_ level: Int) async {
        guard claiming == nil else { return }
        claiming = level
        do {
            let answer: LevelClaim = try await api.call("/level/claim", body: ["level": level])
            Haptics.correct()
            withAnimation { toast = CosmeticToast(text: "+\(answer.reward) Spots from Level \(level)", isError: false) }
            claimed.append(level)
            await api.refreshProfile()
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not claim that reward" : text, isError: true) }
        }
        claiming = nil
    }
}

/// One timeline row: the node column (36 wide, node + connector) and the card.
private struct PathRow: View {
    let step: PathStep
    let level: Int
    let isLast: Bool
    let canClaim: Bool
    let claiming: Bool
    let onClaim: () -> Void

    private var done: Bool { step.level < level }
    private var current: Bool { step.level == level }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                PathNode(done: done, current: current, level: step.level, milestone: step.milestone)
                    .frame(width: current ? 36 : (step.milestone ? 34 : 30), height: current ? 36 : (step.milestone ? 34 : 30))
                if !isLast {
                    connector
                        .frame(width: 2)
                        .frame(minHeight: 12, maxHeight: .infinity)
                        .padding(.bottom, 4)
                }
            }
            .frame(width: 36)
            PathCard(step: step, done: done, current: current, canClaim: canClaim, claiming: claiming, onClaim: onClaim)
                .padding(.bottom, 10)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var connector: some View {
        if done {
            Capsule().fill(LinearGradient(colors: [Palette.accentDeep.opacity(0.6), Palette.accentDeep.opacity(0.4)],
                                          startPoint: .top, endPoint: .bottom))
        } else if current {
            Capsule().fill(LinearGradient(colors: [Palette.accentDeep.opacity(0.4), Color.white.opacity(0.06)],
                                          startPoint: .top, endPoint: .bottom))
        } else {
            Capsule().fill(Color.white.opacity(0.06))
        }
    }
}

/// The node (`lN`): pulsing accent disc with the number where you are, a
/// tick in purple (gold for milestones) behind you, a quiet number or a
/// faint gold star ahead.
private struct PathNode: View {
    let done: Bool
    let current: Bool
    let level: Int
    let milestone: Bool

    @State private var ping = false

    var body: some View {
        if current {
            ZStack {
                Circle()
                    .fill(Palette.accentDeep.opacity(0.28))
                    .scaleEffect(ping ? 2 : 1)
                    .opacity(ping ? 0 : 1)
                    .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: ping)
                Circle()
                    .fill(Palette.accent)
                    .shadow(color: Palette.accentDeep.opacity(0.7), radius: 11)
                Text("\(level)").font(.brand(12, .heavy)).foregroundColor(.white)
            }
            .frame(width: 36, height: 36)
            .onAppear { ping = true }
        } else if done {
            let side: CGFloat = milestone ? 34 : 30
            ZStack {
                Circle().fill(LinearGradient(
                    colors: milestone ? [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)] : [Color(hex: 0x5B21B6), Palette.accentDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                LucideGlyph(icon: .check, size: milestone ? 14 : 12, weight: 3)
                    .foregroundColor(.white)
            }
            .frame(width: side, height: side)
            .shadow(color: milestone ? Color(hex: 0xF59E0B).opacity(0.35) : Palette.accentDeep.opacity(0.3), radius: milestone ? 5 : 4)
        } else {
            let side: CGFloat = milestone ? 34 : 28
            ZStack {
                Circle().fill(milestone ? Color(hex: 0xF59E0B).opacity(0.07) : Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.8))
                Circle().strokeBorder(milestone ? Color(hex: 0xF59E0B).opacity(0.25) : Color.white.opacity(0.08), lineWidth: 1)
                if milestone {
                    LucideGlyph(icon: .star, size: 13)
                        .foregroundColor(Color(hex: 0xF59E0B))
                        .opacity(0.6)
                } else {
                    Text("\(level)").font(.brand(10, .bold)).foregroundColor(Palette.subdued)
                }
            }
            .frame(width: side, height: side)
        }
    }
}

/// The card next to a node (`iN`): "Level n" with YOU ARE HERE or MILESTONE,
/// CLAIM when a bonus waits, then the reward chips.
private struct PathCard: View {
    let step: PathStep
    let done: Bool
    let current: Bool
    let canClaim: Bool
    let claiming: Bool
    let onClaim: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let edge: Color = current ? Palette.accent.opacity(0.5)
            : (step.milestone ? Color(hex: 0xF59E0B).opacity(0.28) : Palette.border)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Level \(step.level)")
                    .font(.brand(13, .bold))
                    .foregroundColor(Palette.foreground)
                if current {
                    badge("YOU ARE HERE", ink: Palette.accent, fill: Palette.accent.opacity(0.2))
                } else if step.milestone {
                    badge("MILESTONE", ink: Color(hex: 0xFBBF24), fill: Color(hex: 0xF59E0B).opacity(0.15))
                }
                Spacer(minLength: 0)
                if canClaim {
                    Button(action: onClaim) {
                        Text(claiming ? "…" : "CLAIM")
                            .font(.brand(10, .bold))
                            .foregroundColor(Palette.onAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 8, style: .circular).fill(Palette.accent))
                            .opacity(claiming ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(claiming)
                }
            }
            ChipFlow(spacing: 6) {
                ForEach(0..<step.rewards.count, id: \.self) { i in
                    RewardChip(reward: step.rewards[i])
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(current ? Color(.sRGB, red: 20 / 255, green: 14 / 255, blue: 50 / 255, opacity: 0.95)
                                       : Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9))
            .shadow(color: current ? Palette.accentDeep.opacity(0.2) : Color.clear, radius: 12))
        .overlay(shape.strokeBorder(edge, lineWidth: 1))
        .opacity(done || current ? 1 : 0.72)
    }

    private func badge(_ text: String, ink: Color, fill: Color) -> some View {
        Text(text)
            .font(.brand(9, .bold))
            .foregroundColor(ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(fill))
    }
}

/// A reward chip (`ty`): 10 pt bold, padding 4/8, icon 9 - title purple,
/// icon indigo, background teal, colours gold, spots amber.
struct RewardChip: View {
    let reward: PathReward

    var body: some View {
        let look = RewardChip.look(reward)
        HStack(spacing: 4) {
            LucideGlyph(icon: look.icon, size: 9)
            Text(reward.label).font(.brand(10, .bold)).lineLimit(1)
        }
        .foregroundColor(look.ink)
        // padding 4/8 plus the 1 px border, line height 15: 25 tall as measured.
        .padding(.horizontal, 9)
        .frame(height: 25)
        .background(Capsule().fill(look.fill))
        .overlay(Capsule().strokeBorder(look.edge, lineWidth: 1))
    }

    private static func look(_ r: PathReward) -> (icon: LucideIcon, ink: Color, fill: Color, edge: Color) {
        switch r {
        case .spots:
            let amber = Color(hex: 0xF59E0B)
            return (.music2, amber, amber.opacity(0.13), amber.opacity(0.35))
        case .item(let type, _):
            switch type {
            case "title":
                return (.type, Palette.accent, Palette.accent.opacity(0.13), Palette.accent.opacity(0.35))
            case "icon":
                let indigo = Color(hex: 0x818CF8)
                return (.smile, indigo, indigo.opacity(0.13), indigo.opacity(0.35))
            case "background":
                let teal = Color(hex: 0x2DD4BF)
                return (.image, teal, teal.opacity(0.11), teal.opacity(0.35))
            default:
                let gold = Color(hex: 0xFBBF24)
                return (.palette, gold, gold.opacity(0.11), gold.opacity(0.3))
            }
        }
    }
}

/// Left-to-right rows that wrap, `spacing` apart both ways (`flex flex-wrap`).
struct ChipFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width: CGFloat = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for view in subviews {
            let size: CGSize = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for view in subviews {
            let size: CGSize = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
