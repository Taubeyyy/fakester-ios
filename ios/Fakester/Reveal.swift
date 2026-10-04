import SwiftUI

// MARK: - Reveal

/// The round reveal, rebuilt from the browser (measured at 375×812): a sheet
/// slides up over the round, which stays behind it dimmed (rgba(4,4,10,.72))
/// and blurred (10 px). Inside: a header "ROUND n / 5 · Results" with Leave,
/// the "NOW REVEALED" card, one card per player (the first one opened, with
/// "your answer → the right one" per guess type) and a footer with the
/// equalizer and "Next round coming up…".
///
/// The sheet is a portal to `document.body` in the browser, outside the app's
/// DM Sans root - so everything in it without an explicit font is `system-ui`
/// (San Francisco, `.system`). Only title, names and totals ask for Bricolage
/// and therefore end up as Helvetica (`Font.brand`).
///
/// In sneaky mode the browser shows no sheet but a centred "Locked in" notice.
struct RevealView: View {
    @EnvironmentObject private var game: Game
    /// The open player card. The browser opens the first one (the leader) and
    /// keeps at most one open; tapping a card toggles it.
    @State private var openIndex: Int = 0
    @State private var shown: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RevealRoundGhost()
                    .blur(radius: isSneaky ? 14 : 10)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                if isSneaky {
                    RevealSneakyNotice(round: roundNumber, total: totalRounds)
                        .opacity(shown ? 1 : 0)
                        .animation(.easeOut(duration: 0.25), value: shown)
                } else {
                    RevealPalette.dim
                        .ignoresSafeArea()
                        .opacity(shown ? 1 : 0)
                        .animation(.easeOut(duration: 0.25), value: shown)
                    RevealSheet(openIndex: $openIndex, shown: shown)
                        .frame(maxHeight: sheetCap(geo), alignment: .bottom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        .onAppear {
            shown = true
            if isSneaky { return }
            let pointsEarned: Int = game.me?.lastPointsBreakdown?.total ?? 0
            if pointsEarned > 0 { Haptics.correct() } else { Haptics.wrong() }
        }
    }

    private var isSneaky: Bool { game.outcome?.sneaky == true }
    private var roundNumber: Int { game.activeRound?.round ?? 1 }
    private var totalRounds: Int { game.activeRound?.totalRounds ?? 0 }

    /// max-height: min(88dvh, 760px) minus the bottom safe area, like the browser.
    private func sheetCap(_ geo: GeometryProxy) -> CGFloat {
        let full: CGFloat = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
        let cap: CGFloat = min(full * 0.88, 760) - geo.safeAreaInsets.bottom
        return max(220, cap)
    }
}

/// The sheet itself: rgba(11,10,22,.98), border in the accent colour at 22 %,
/// top corners 24, shadows 0 -8 60 black 60 % and 0 0 60 accent-deep 12 %.
/// It hugs its content and only scrolls once it hits the height cap.
private struct RevealSheet: View {
    @EnvironmentObject private var game: Game
    @Binding var openIndex: Int
    let shown: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ViewThatFits(in: .vertical) {
                content
                ScrollView(.vertical, showsIndicators: false) {
                    content
                }
            }
            footer
        }
        .background(RevealSheetSurface().ignoresSafeArea(edges: .bottom))
        .opacity(shown ? 1 : 0)
        .scaleEffect(shown ? 1 : 0.98, anchor: .bottom)
        .offset(y: shown ? 0 : 40)
        .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.42), value: shown)
    }

    // MARK: Header

    /// px-4 py-3 plus the 1 pt sheet border, then border-b.
    private var header: some View {
        HStack(spacing: 8) {
            headline
            Spacer(minLength: 8)
            RevealLeaveButton { game.leave() }
        }
        .padding(.horizontal, 17)
        .padding(.top, 13)
        .padding(.bottom, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    /// "ROUND 2" in the accent colour, " / 5 · Results" in #8d8ba4, 12 pt bold.
    /// One Text, so the whole line is a single label ("Results" is what the
    /// UI test waits for).
    private var headline: Text {
        let round: Int = game.activeRound?.round ?? 1
        let total: Int = game.activeRound?.totalRounds ?? 0
        let tail: String = (total > 0 ? " / \(total)" : "") + " · Results"
        let lead: Text = Text("ROUND \(round)").foregroundColor(Palette.accent)
        let rest: Text = Text(tail).foregroundColor(Palette.subdued)
        return (lead + rest).font(.system(size: 12, weight: .bold))
    }

    // MARK: Content

    /// px-4 pt-4 pb-5, gap 14 below the song card, gap 10 between players.
    private var content: some View {
        VStack(spacing: 14) {
            if let track = game.outcome?.correctTrack {
                RevealedTrackCard(heading: track)
                    .opacity(shown ? 1 : 0)
                    .offset(y: shown ? 0 : 20)
                    .blur(radius: shown ? 0 : 6)
                    .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5).delay(0.08), value: shown)
            }
            VStack(spacing: 10) {
                ForEach(entries) { entry in
                    RevealPlayerCard(entry: entry, isOpen: openIndex == entry.rank - 1) {
                        toggle(entry.rank - 1)
                    }
                    .modifier(RevealRise(shown: shown, dy: 10,
                                         delay: 0.18 + Double(entry.rank - 1) * 0.08, duration: 0.4))
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    /// The browser takes the order of the round result (`scores`), not the
    /// lobby list - a lobby-update during the reveal must not reshuffle it.
    private var entries: [RevealEntry] {
        let fromResult: [Player] = game.outcome?.scores ?? []
        let players: [Player] = fromResult.isEmpty ? game.player : fromResult
        return RevealEntry.build(players: players, ownId: game.ownId, track: game.outcome?.correctTrack)
    }

    private func toggle(_ index: Int) {
        Haptics.tap()
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.25)) {
            openIndex = openIndex == index ? -1 : index
        }
    }

    // MARK: Footer

    /// px-4 py-3.5, border-t, rgba(7,7,14,.95): equalizer (size .8) and the
    /// line 13 pt semibold #8d8ba4. After the last round it says the final
    /// scores are being counted.
    private var footer: some View {
        HStack(spacing: 10) {
            RevealEqualizer(scale: 0.8)
            Text(isLastRound ? "Counting up the final scores…" : "Next round coming up…")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Palette.subdued)
                .frame(minHeight: 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(RevealPalette.footer)
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }

    private var isLastRound: Bool {
        let total: Int = game.activeRound?.totalRounds ?? 0
        let round: Int = game.activeRound?.round ?? 1
        return total > 0 && round >= total
    }
}

/// Background of the sheet. The browser rounds only the top corners - here the
/// bottom ones simply hang below the screen edge.
private struct RevealSheetSurface: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return ZStack {
            shape.fill(RevealPalette.sheet)
                .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: -8)
                .shadow(color: Palette.accentDeep.opacity(0.12), radius: 30)
            shape.strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1)
        }
        .padding(.bottom, -40)
    }
}

/// "× Leave" inside the sheet: the same red pill as on the round screen, but in
/// San Francisco (system-ui) like everything in the sheet - 80 wide instead of 74.
private struct RevealLeaveButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .accessibilityHidden(true)
                Text("Leave")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(Palette.bad)
            .padding(.horizontal, 12)
            .frame(height: 31)
            .background(Capsule().fill(RevealPalette.red.opacity(0.1)))
            .overlay(Capsule().strokeBorder(RevealPalette.red.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(RevealPressStyle(pressedScale: 0.95))
    }
}

// MARK: - Song card

/// "NOW REVEALED": rgba(15,10,40,.95), border accent 30 %, glow 0 0 40
/// accent-deep 20 %, padding 20/16, a soft accent-deep glow in the top right
/// corner. Cover 72 (corners 16) with the year pill hanging off its bottom
/// right corner, next to it the label, the title (22 pt extra bold) and the
/// artist (13 pt semibold #b0aed2).
struct RevealedTrackCard: View {
    let heading: Track

    var body: some View {
        HStack(spacing: 16) {
            RevealCoverArt(address: heading.albumArt, year: heading.year)
            textColumn
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 21)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RevealTrackSurface())
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("NOW REVEALED")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.5)
                .foregroundColor(Palette.subdued)
                .frame(minHeight: 15)
            Text(heading.title)
                .font(.brand(22, .heavy))
                .lineSpacing(2)
                .foregroundColor(Palette.foreground)
                .shadow(color: Palette.accent.opacity(0.3), radius: 10)
                .fixedSize(horizontal: false, vertical: true)
            Text(heading.artist)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(RevealPalette.lavender)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 20)
        }
    }
}

private struct RevealTrackSurface: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return shape
            .fill(RevealPalette.trackCard)
            .overlay(alignment: .topTrailing) {
                // -right-10 -top-10, 160 × 160, radial accent-deep 25 % → transparent 70 %, blur 20
                Circle()
                    .fill(RadialGradient(colors: [Palette.accentDeep.opacity(0.25), Palette.accentDeep.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 79))
                    .frame(width: 160, height: 160)
                    .blur(radius: 10)
                    .offset(x: 40, y: -40)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.accent.opacity(0.3), lineWidth: 1))
            .overlay(EdgeHighlight(radius: 16, intensity: 0.05))
            .shadow(color: Palette.accentDeep.opacity(0.2), radius: 20)
    }
}

/// The cover on a dark purple gradient (shown while it loads or when there is
/// none), glow 0 0 20 accent-deep 35 %, year pill -bottom-1 -right-1.
private struct RevealCoverArt: View {
    let address: String?
    let year: Int?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack(alignment: .bottomTrailing) {
            ZStack {
                LinearGradient(colors: [Color(hex: 0x1A0533), Color(hex: 0x3B0764), Color(hex: 0x0D0019)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                picture
            }
            .frame(width: 72, height: 72)
            .clipShape(shape)
            .shadow(color: Palette.accentDeep.opacity(0.35), radius: 10)

            if let year {
                Text(String(year))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Palette.onAccent)
                    .frame(height: 15)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.accent))
                    .offset(x: 4, y: 4)
            }
        }
    }

    @ViewBuilder
    private var picture: some View {
        if let address, let url = URL(string: address) {
            AsyncImage(url: url) { phase in
                if let loaded = phase.image {
                    loaded.resizable().scaledToFill()
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        Image(systemName: "music.note")
            .font(.system(size: 24))
            .foregroundColor(Palette.accent.opacity(0.8))
    }
}

// MARK: - Player cards

/// One guess type of one player, as the browser derives it from
/// `lastPointsBreakdown`: right when it scored, plus what was answered and
/// what was correct.
private struct RevealField: Identifiable {
    let kind: String
    let correct: Bool
    /// nil = nothing answered ("NO ANSWER" pill).
    let guessed: String?
    let answer: String

    var id: String { kind }
    /// The browser capitalises the key: "title" → "Title".
    var label: String { kind.prefix(1).uppercased() + String(kind.dropFirst()) }
}

private struct RevealEntry: Identifiable {
    let id: String
    let rank: Int
    let player: Player
    let isYou: Bool
    /// nil when the server sent no breakdown - the browser shows "·" then.
    let roundPoints: Int?
    let speedBonus: Int
    let fields: [RevealField]

    /// Only these become chips and rows; speed and streak are bonuses.
    static let fieldKinds: [String] = ["title", "artist", "year", "pick"]

    static func build(players: [Player], ownId: String, track: Track?) -> [RevealEntry] {
        var list: [RevealEntry] = []
        for (index, p) in players.enumerated() {
            let sheet: PointsBreakdown? = p.lastPointsBreakdown
            var fields: [RevealField] = []
            if let sheet {
                for item in BreakdownOrder.ordered(sheet.breakdown) where fieldKinds.contains(item.category) {
                    let guessedText: String = sheet.ownAnswer?[item.category]?.text ?? ""
                    let field = RevealField(kind: item.category,
                                            correct: item.amount.points > 0,
                                            guessed: guessedText.isEmpty ? nil : guessedText,
                                            answer: correctAnswer(item.category, track))
                    fields.append(field)
                }
            }
            let speed: Int = sheet?.breakdown["speed"]?.points ?? 0
            let entry = RevealEntry(id: "\(index)-\(p.id.text)",
                                    rank: index + 1,
                                    player: p,
                                    isYou: p.id.text == ownId,
                                    roundPoints: sheet?.total,
                                    speedBonus: speed,
                                    fields: fields)
            list.append(entry)
        }
        return list
    }

    private static func correctAnswer(_ kind: String, _ track: Track?) -> String {
        guard let track else { return "" }
        switch kind {
        case "title":  return track.title
        case "artist": return track.artist
        case "year":   return track.year.map { String($0) } ?? ""
        default:       return ""      // "pick" (higher/lower) is not decoded by the app
        }
    }
}

/// A player card: rank circle (gold/silver/bronze for the podium), a tick or
/// cross (anything right?), avatar 26, name, "+points" in green and the total.
/// Below the chips Title / Artist / Year in green or red, and when open one row
/// per guess type. Your own card is purple (rgba(20,10,50,.95), border accent
/// 55 %, ring 1 pt accent 18 %, glow 0 4 24 accent-deep 15 %), the others are
/// the plain card colour.
private struct RevealPlayerCard: View {
    let entry: RevealEntry
    let isOpen: Bool
    let onTap: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 0) {
            topRow
            chipRow
            if isOpen && !entry.fields.isEmpty {
                fieldList
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(entry.isYou ? RevealPalette.youCard : RevealPalette.otherCard))
        .clipShape(shape)
        .overlay(shape.strokeBorder(entry.isYou ? Palette.accent.opacity(0.55) : Color.white.opacity(0.08), lineWidth: 1))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(Palette.accent.opacity(entry.isYou ? 0.18 : 0), lineWidth: 1)
                .padding(-1)
        )
        .shadow(color: entry.isYou ? Palette.accentDeep.opacity(0.15) : Color.clear, radius: 12, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    /// px-3 py-3 (plus the border), gap 12.
    private var topRow: some View {
        let pointsText: String = entry.roundPoints.map { "+\($0)" } ?? "·"
        return HStack(spacing: 12) {
            RevealRankBadge(rank: entry.rank, size: 28, numberFont: .system(size: 12, weight: .heavy), bigGlow: false)
            statusDot
            RevealAvatar(player: entry.player, size: 26, ringed: false)
            Text(entry.player.nickname)
                .font(.brand(14, .bold))
                .foregroundColor(RevealPalette.nameColor(entry.player, fallback: Palette.foreground))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(pointsText)
                .font(.system(size: 13, weight: .bold).monospacedDigit())
                .foregroundColor(Palette.good)
            Text("\(entry.player.score)")
                .font(.brand(15, .heavy))
                .foregroundColor(entry.isYou ? Palette.accent : Palette.foreground)
        }
        .padding(.horizontal, 13)
        .padding(.top, 13)
        .padding(.bottom, 12)
    }

    /// 20 pt circle: green 20 % with a tick when anything was right, red 15 %
    /// with a cross otherwise.
    private var statusDot: some View {
        let anyRight: Bool = entry.fields.contains { $0.correct }
        return ZStack {
            Circle().fill(anyRight ? Palette.good.opacity(0.2) : RevealPalette.red.opacity(0.15))
            Image(systemName: anyRight ? "checkmark" : "xmark")
                .font(.system(size: 7, weight: .heavy))
                .foregroundColor(anyRight ? Palette.good : Palette.bad)
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }

    /// px-3 pb-2.5, gap 6. The speed bonus gets its own accent chip.
    private var chipRow: some View {
        HStack(spacing: 6) {
            ForEach(entry.fields) { field in
                RevealChip(label: field.label, correct: field.correct)
            }
            if entry.speedBonus > 0 {
                speedChip
            }
        }
        .padding(.horizontal, 13)
        .padding(.bottom, 10)
    }

    private var speedChip: some View {
        HStack(spacing: 4) {
            Text("Speed +\(entry.speedBonus)")
                .font(.system(size: 10, weight: .bold))
            Image(systemName: "bolt")
                .font(.system(size: 6.5, weight: .bold))
        }
        .foregroundColor(Palette.accent)
        .padding(.horizontal, 8)
        .frame(height: 21)
        .background(Capsule().fill(Palette.accent.opacity(0.1)))
        .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.35), lineWidth: 1))
    }

    /// border-t, then one row per guess type, separated by border-b.
    private var fieldList: some View {
        VStack(spacing: 0) {
            ForEach(Array(entry.fields.enumerated()), id: \.element.id) { index, field in
                RevealFieldRow(field: field)
                    .overlay(alignment: .bottom) {
                        if index < entry.fields.count - 1 {
                            Rectangle().fill(Palette.border).frame(height: 1)
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}

/// "Title ✓" - 10 pt bold, padding 2/8, green 8 % / border 35 % or red 8 % / 30 %.
private struct RevealChip: View {
    let label: String
    let correct: Bool

    var body: some View {
        let base: Color = correct ? Palette.good : RevealPalette.red
        return HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
            Image(systemName: correct ? "checkmark" : "xmark")
                .font(.system(size: 6, weight: .heavy))
                .accessibilityHidden(true)
        }
        .foregroundColor(correct ? Palette.good : Palette.bad)
        .padding(.horizontal, 8)
        .frame(height: 21)
        .background(Capsule().fill(base.opacity(0.08)))
        .overlay(Capsule().strokeBorder(base.opacity(correct ? 0.35 : 0.3), lineWidth: 1))
    }
}

/// One row of an open card: square 20 (corners 4) with tick/cross, the label
/// (11 pt bold, 40 wide), then the answer in 12 pt semibold. Right: the answer
/// in white. Wrong: your answer in red (or the "NO ANSWER" pill), "→" and the
/// right one in green - wrapping like flex-wrap.
private struct RevealFieldRow: View {
    let field: RevealField

    var body: some View {
        let base: Color = field.correct ? Palette.good : RevealPalette.red
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(base.opacity(0.2))
                Image(systemName: field.correct ? "checkmark" : "xmark")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(field.correct ? Palette.good : Palette.bad)
            }
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)

            Text(field.label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(Palette.subdued)
                .frame(width: 40, alignment: .leading)

            answer
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(base.opacity(0.04))
    }

    @ViewBuilder
    private var answer: some View {
        if field.correct {
            answerText(field.answer, Palette.foreground)
        } else {
            RevealFlow(spacing: 6) {
                if let guessed = field.guessed {
                    answerText(guessed, Palette.bad)
                } else {
                    RevealNoAnswerPill()
                }
                answerText("→", Palette.subdued)
                answerText(field.answer, Palette.good)
            }
        }
    }

    /// 12 pt semibold in an 18 pt line, like the browser.
    private func answerText(_ text: String, _ hue: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .lineSpacing(3)
            .foregroundColor(hue)
            .frame(minHeight: 18)
    }
}

/// "– NO ANSWER": 10 pt bold, uppercase, tracking .25, white 5 %, corners 4.
private struct RevealNoAnswerPill: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "minus")
                .font(.system(size: 7, weight: .heavy))
                .accessibilityHidden(true)
            Text("NO ANSWER")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.25)
        }
        .foregroundColor(Palette.subdued)
        .frame(height: 15)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.white.opacity(0.05)))
    }
}

/// flex-wrap with gap: children side by side, a child that no longer fits
/// starts a new line; within a line they are centred vertically. A child wider
/// than the whole line (a long title) wraps inside itself.
private struct RevealFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let limit: CGFloat = proposal.width ?? CGFloat.infinity
        let rows: [[RevealFlowItem]] = arrange(subviews, limit: limit)
        var widest: CGFloat = 0
        var height: CGFloat = 0
        for (number, row) in rows.enumerated() {
            widest = max(widest, rowWidth(row))
            height += rowHeight(row) + (number > 0 ? spacing : 0)
        }
        var width: CGFloat = widest
        if let offered = proposal.width, offered.isFinite {
            width = max(widest, offered)
        }
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows: [[RevealFlowItem]] = arrange(subviews, limit: bounds.width)
        var y: CGFloat = bounds.minY
        for row in rows {
            let lineHeight: CGFloat = rowHeight(row)
            var x: CGFloat = bounds.minX
            for item in row {
                let top: CGFloat = y + (lineHeight - item.size.height) / 2
                subviews[item.index].place(at: CGPoint(x: x, y: top),
                                           anchor: .topLeading,
                                           proposal: ProposedViewSize(width: item.size.width, height: item.size.height))
                x += item.size.width + spacing
            }
            y += lineHeight + spacing
        }
    }

    private func arrange(_ subviews: Subviews, limit: CGFloat) -> [[RevealFlowItem]] {
        var rows: [[RevealFlowItem]] = []
        var row: [RevealFlowItem] = []
        var x: CGFloat = 0
        for index in subviews.indices {
            let ideal: CGSize = subviews[index].sizeThatFits(ProposedViewSize.unspecified)
            var size: CGSize = ideal
            if ideal.width > limit {
                size = subviews[index].sizeThatFits(ProposedViewSize(width: limit, height: nil))
            }
            if !row.isEmpty && x + spacing + size.width > limit {
                rows.append(row)
                row = []
                x = 0
            }
            x = row.isEmpty ? size.width : x + spacing + size.width
            row.append(RevealFlowItem(index: index, size: size))
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    private func rowWidth(_ row: [RevealFlowItem]) -> CGFloat {
        var total: CGFloat = 0
        for item in row { total += item.size.width }
        return total + spacing * CGFloat(max(0, row.count - 1))
    }

    private func rowHeight(_ row: [RevealFlowItem]) -> CGFloat {
        var tallest: CGFloat = 0
        for item in row { tallest = max(tallest, item.size.height) }
        return tallest
    }
}

private struct RevealFlowItem {
    let index: Int
    let size: CGSize
}

// MARK: - Sneaky mode

/// Sneaky mode hides song, answers and scores until the end. The browser then
/// shows no sheet but a centred notice over the round (rgba(4,4,10,.86), blur 14):
/// eye-off 40 in the accent colour at 70 %, "Locked in" 26 pt extra bold white,
/// the explanation 14 pt bold #8d8ba4 (at most 34ch wide) and how many rounds
/// are left, 17 pt extra bold in the accent colour.
private struct RevealSneakyNotice: View {
    let round: Int
    let total: Int

    var body: some View {
        ZStack {
            RevealPalette.sneakyDim
                .ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "eye.slash")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundColor(Palette.accent.opacity(0.7))
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                Text("Locked in")
                    .font(.brand(26, .heavy))
                    .foregroundColor(Color.white)
                Text("Sneaky Mode — nobody finds out the song, the answers or the scores until the game is over.")
                    .font(.brand(14, .bold))
                    .foregroundColor(Palette.subdued)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 264)
                Text(progressText)
                    .font(.brand(17, .heavy))
                    .foregroundColor(Palette.accent)
            }
            .frame(maxWidth: 460)
            .padding(24)
        }
    }

    private var progressText: String {
        guard total > 0 else { return "Round \(round) done" }
        return round >= total ? "That was the last one" : "\(total - round) to go"
    }
}

// MARK: - The round behind the sheet

/// What the browser shows blurred behind the sheet: the round screen keeps
/// running underneath. The app has already left the round view, so this is a
/// light copy of its top part (header, progress line, own chip, cover, player
/// card, answer tiles) - under 10 pt of blur and 72 % dimming nothing more is
/// visible anyway, and the real round view must not start anything again.
private struct RevealRoundGhost: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 4)
            VStack(alignment: .leading, spacing: 12) {
                chip
                cover
                    .frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.card)
                    .frame(height: 112)
                answerTiles
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        let round: Int = game.activeRound?.round ?? 1
        let total: Int = game.activeRound?.totalRounds ?? 0
        let tail: String = total > 0 ? " / \(total)" : ""
        let lead: Text = Text("ROUND \(round)").foregroundColor(Palette.accent)
        let rest: Text = Text(tail).foregroundColor(Palette.subdued)
        return HStack(spacing: 10) {
            (lead + rest).font(.brand(12, .bold))
            Capsule()
                .fill(Palette.bad.opacity(0.12))
                .frame(width: 54, height: 28)
            Spacer(minLength: 0)
            Capsule()
                .fill(RevealPalette.red.opacity(0.1))
                .frame(width: 74, height: 31)
        }
        .padding(.horizontal, 16)
        .frame(height: 51)
    }

    private var chip: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 20, height: 20)
            Text(game.me?.nickname ?? "")
                .font(.brand(11, .bold))
                .foregroundColor(Palette.accent)
                .lineLimit(1)
            Text("\(game.me?.score ?? 0)")
                .font(.brand(10))
                .foregroundColor(Palette.subdued)
        }
        .padding(.leading, 5)
        .padding(.trailing, 10)
        .frame(height: 30)
        .background(Capsule().fill(Palette.accentDeep.opacity(0.18)))
        .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.4), lineWidth: 1))
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return ZStack {
            shape.fill(Palette.muted)
            if let address = coverAddress, let url = URL(string: address) {
                AsyncImage(url: url) { phase in
                    if let loaded = phase.image {
                        loaded.resizable().scaledToFill()
                    } else {
                        Color.clear
                    }
                }
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(shape)
    }

    private var coverAddress: String? {
        guard game.lobbySettings?.showCover ?? true else { return nil }
        return game.activeRound?.albumArt
    }

    private var answerTiles: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: 6) {
                    tile
                    tile
                }
            }
        }
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(Color.white.opacity(0.04))
            .overlay(shape.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            .frame(height: 48)
    }
}

// MARK: - Game over

/// The final screen, rebuilt from the browser: one scrolling page (px-5, py-8,
/// gap 24, at most 448 wide, centred when it is shorter than the screen) on
/// #07070e with a purple glow at the top and a faint green one at the bottom.
/// Top to bottom: GAME OVER letter by letter, "You finished #1 with 375 pts",
/// the final standings, WHAT WAS PLAYING, the amber guest card, the three
/// reward tiles and the buttons "Rematch — same crew" / "Back to lobby" /
/// "Share result" / "Main menu". Confetti falls for the first 4.5 s.
struct GameOverView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool = false
    @State private var confettiOver: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Palette.base
                    .ignoresSafeArea()
                ScrollView(.vertical, showsIndicators: false) {
                    page(width: geo.size.width)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geo.size.height)
                        .background(alignment: .top) { FinalTopGlow() }
                        .background(alignment: .bottom) { FinalBottomGlow() }
                }
                if !reduceMotion && !confettiOver {
                    FinalConfetti()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
        .onAppear { shown = true }
        .task {
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            confettiOver = true
        }
    }

    private func page(width: CGFloat) -> some View {
        VStack(spacing: 24) {
            headline(width: width)
            standings
            if !songs.isEmpty {
                SongList(tracks: songs)
                    .modifier(RevealRise(shown: shown, dy: 14, delay: 0.7))
            }
            if isGuest {
                guestCard
                    .modifier(RevealRise(shown: shown, dy: 12, delay: 0.78))
            }
            RewardTiles(prize: myReward, dimmed: isGuest)
                .modifier(RevealRise(shown: shown, dy: 12, delay: 0.82))
            buttons
                .modifier(RevealRise(shown: shown, dy: 12, delay: 1.0))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 32)
        .frame(maxWidth: 448)
    }

    // MARK: Data

    /// The browser reads `finalScores` (the order of the game-over message).
    private var finalPlayers: [Player] {
        let fromEnd: [Player] = game.finalStandings?.scores ?? []
        return fromEnd.isEmpty ? game.player : fromEnd
    }

    private var songs: [Track] { game.finalStandings?.songs ?? [] }

    private var myIndex: Int? {
        let own: String = game.ownId
        return finalPlayers.firstIndex { $0.id.text == own }
    }

    /// 0 = not in the list; the browser then writes "Final scores".
    private var myRank: Int { (myIndex ?? -1) + 1 }

    private var myScore: Int {
        guard let i = myIndex else { return 0 }
        return finalPlayers[i].score
    }

    private var myReward: Reward? {
        guard let i = myIndex else { return nil }
        return finalPlayers[i].rewards
    }

    private var isGuest: Bool { api.identity?.isGuest ?? true }

    // MARK: Headline

    /// clamp(44px, 12vw, 72px), weight 800, letter spacing -0.02em, each letter
    /// its own span with 2 pt gap, 16 pt between the words, glow 0 0 40 accent
    /// 60 % and 0 0 80 accent-deep 30 %. The letters drop in one after another.
    private func headline(width: CGFloat) -> some View {
        let size: CGFloat = min(max(44, width * 0.12), 72)
        return VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 16) {
                letters(["G", "A", "M", "E"], word: 0, size: size)
                letters(["O", "V", "E", "R"], word: 1, size: size)
            }
            .frame(height: size)
            .shadow(color: Palette.accent.opacity(0.6), radius: 20)
            .shadow(color: Palette.accentDeep.opacity(0.3), radius: 40)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Game over"))

            subtitle
                .opacity(shown ? 1 : 0)
                .animation(.easeOut(duration: 0.5).delay(0.72), value: shown)
        }
    }

    private func letters(_ characters: [String], word: Int, size: CGFloat) -> some View {
        HStack(spacing: 2 - 0.02 * size) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                Text(character)
                    .font(.brand(size, .heavy))
                    .foregroundColor(Palette.accent)
                    .opacity(shown ? 1 : 0)
                    .scaleEffect(shown ? 1 : 0.7)
                    .offset(y: shown ? 0 : 28)
                    .blur(radius: shown ? 0 : 8)
                    .animation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.5)
                        .delay(0.1 + Double(word * 4 + index) * 0.06), value: shown)
            }
        }
    }

    /// 13 pt medium #8d8ba4; "#1" bold #eef, "375 pts" bold in the accent colour.
    private var subtitle: some View {
        Group {
            if myRank > 0 {
                finishedLine
            } else {
                Text("Final scores")
                    .foregroundColor(Palette.subdued)
            }
        }
        .font(.brand(13, .medium))
        .frame(minHeight: 20)
    }

    private var finishedLine: Text {
        let lead: Text = Text("You finished ").foregroundColor(Palette.subdued)
        let place: Text = Text("#\(myRank)").font(.brand(13, .bold)).foregroundColor(Palette.foreground)
        let middle: Text = Text(" with ").foregroundColor(Palette.subdued)
        let points: Text = Text(myScore.formatted() + " pts").font(.brand(13, .bold)).foregroundColor(Palette.accent)
        return lead + place + middle + points
    }

    // MARK: Standings

    private var standings: some View {
        VStack(spacing: 8) {
            ForEach(Array(finalPlayers.enumerated()), id: \.offset) { index, player in
                FinalStandingRow(rank: index + 1, player: player, isYou: player.id.text == game.ownId)
                    .modifier(RevealRise(shown: shown, dx: -16, dy: 0,
                                         delay: 0.6 + Double(min(index, 8)) * 0.08, duration: 0.4))
            }
        }
        .modifier(RevealRise(shown: shown, dy: 14, delay: 0.55))
    }

    // MARK: Guest card

    /// rgba(245,158,11,.08), border .28: person icon in amber, the text 12 pt
    /// #fcd34d, and the amber button. In the browser it opens fakester.app; the
    /// app has its own sign-up, so it leaves the game and goes to the login
    /// screen - the same way as "Yes" in the guest notice on the home screen.
    private var guestCard: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "person")
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(Palette.gold)
                .frame(width: 15, height: 15)
                .padding(.top, 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text("You are playing as a guest, so this round was not saved. With an account it would have been worth what you see below.")
                    .font(.brand(12))
                    .lineSpacing(5)
                    .foregroundColor(RevealPalette.amberText)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    createAccount()
                } label: {
                    Text("Create an account — keeps your name")
                        .font(.brand(11, .bold))
                        .foregroundColor(Palette.gold)
                        .frame(height: 17)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(RevealPalette.amber.opacity(0.18)))
                }
                .buttonStyle(RevealPressStyle(pressedScale: 0.97))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
        .background(shape.fill(RevealPalette.amber.opacity(0.08)))
        .overlay(shape.strokeBorder(RevealPalette.amber.opacity(0.28), lineWidth: 1))
    }

    private func createAccount() {
        Haptics.tap()
        game.leave()
        api.logOut()
    }

    // MARK: Buttons

    /// "Rematch" purple (15 pt bold, glow 0 0 32 accent-deep 50 %), the other
    /// three quiet: rgba(24,23,39,.8), border white 7 %, 14 pt semibold #b0aed2,
    /// icon 14 #8d8ba4. All 51 high, corners 16, gap 10.
    private var buttons: some View {
        VStack(spacing: 10) {
            Button {
                rematch()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Rematch — same crew")
                        .font(.brand(15, .bold))
                }
                .foregroundColor(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 51)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Palette.accent))
                .shadow(color: Palette.accentDeep.opacity(0.5), radius: 16)
            }
            .buttonStyle(RevealPressStyle(pressedScale: 0.97))
            .accessibilityLabel(Text("Rematch — same crew"))

            FinalQuietButton(title: "Back to lobby", symbol: "arrow.counterclockwise") {
                Haptics.tap()
                game.returnToLobby()
            }

            ShareLink(item: shareText) {
                FinalQuietLabel(title: "Share result", symbol: "square.and.arrow.up")
            }
            .buttonStyle(RevealPressStyle(pressedScale: 0.98))
            .accessibilityLabel(Text("Share result"))

            FinalQuietButton(title: "Main menu", symbol: "house") {
                Haptics.tap()
                game.leave()
            }
        }
    }

    /// Like the browser: back to the lobby and, 0.9 s later, start again with
    /// the same settings. Starting only works for the host (`startGame` checks
    /// that itself); everyone else simply lands in the lobby.
    private func rematch() {
        Haptics.tap()
        let current: Game = game
        current.returnToLobby()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            current.startGame()
        }
    }

    /// The browser's share text. (It also renders a picture; the app shares the text.)
    private var shareText: String {
        let players: [Player] = finalPlayers
        if myRank > 0 {
            var line: String = "Fakester: I finished #\(myRank) of \(players.count) with \(myScore.formatted()) points"
            if let playlist = game.lobbySettings?.playlistName, !playlist.isEmpty {
                line += " on \"\(playlist)\""
            }
            return line + ". Beat that: https://fakester.app"
        }
        let top: [String] = players.prefix(3).enumerated().map { pair in
            "\(pair.offset + 1). \(pair.element.nickname) \(pair.element.score)"
        }
        return "Fakester — final scores: " + top.joined(separator: " · ") + " https://fakester.app"
    }
}

/// A row of the final standings: px-4 py-3, rank circle 32 (13 pt extra bold),
/// avatar 32 (yours with a 2 pt accent ring and glow), name 14 pt bold, total
/// 18 pt extra bold. Yours: rgba(20,10,50,.9), amber border 60 %, amber ring
/// 20 %, amber glow 0 4 28 10 %, total in gold; the others rgba(24,23,39,.88).
private struct FinalStandingRow: View {
    let rank: Int
    let player: Player
    let isYou: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 12) {
            RevealRankBadge(rank: rank, size: 32, numberFont: .brand(13, .heavy), bigGlow: true)
            RevealAvatar(player: player, size: 32, ringed: isYou)
            Text(player.nickname)
                .font(.brand(14, .bold))
                .foregroundColor(RevealPalette.nameColor(player, fallback: isYou ? Palette.gold : Palette.foreground))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(player.score.formatted())
                .font(.brand(18, .heavy))
                .foregroundColor(isYou ? Palette.gold : RevealPalette.lavender)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 13)
        .background(shape.fill(isYou ? RevealPalette.youRow : RevealPalette.otherRow))
        .overlay(shape.strokeBorder(isYou ? RevealPalette.amber.opacity(0.6) : Palette.border, lineWidth: 1))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(RevealPalette.amber.opacity(isYou ? 0.2 : 0), lineWidth: 1)
                .padding(-1)
        )
        .shadow(color: isYou ? RevealPalette.amber.opacity(0.1) : Color.clear, radius: 14, x: 0, y: 4)
    }
}

/// The three tiles XP / SPOTS / GS: rgba(24,23,39,.95), corners 16, icon 18,
/// "+n" 20 pt extra bold, label 10 pt bold uppercase. The numbers count up
/// (0.9 s delay, 1.1 s, ease-out cubic). For guests the tiles are faded to
/// 55 % and lose their glow - the browser shows them anyway, as "what it would
/// have been worth"; without rewards they show +0.
struct RewardTiles: View {
    let prize: Reward?
    var dimmed: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            FinalRewardTile(amount: prize?.xp ?? 0, word: "XP", symbol: "star",
                            hue: Palette.accent, glow: Palette.accent.opacity(0.25), dimmed: dimmed)
            FinalRewardTile(amount: prize?.spots ?? 0, word: "SPOTS", symbol: "music.note",
                            hue: Palette.good, glow: Palette.good.opacity(0.2), dimmed: dimmed)
            FinalRewardTile(amount: prize?.goldSpots ?? 0, word: "GS", symbol: "trophy",
                            hue: RevealPalette.amber, glow: RevealPalette.amber.opacity(0.25), dimmed: dimmed)
        }
    }
}

private struct FinalRewardTile: View {
    let amount: Int
    let word: String
    let symbol: String
    let hue: Color
    let glow: Color
    let dimmed: Bool
    @State private var counted: Int = 0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(hue)
                .frame(height: 18)
                .accessibilityHidden(true)
            Text("+\(counted)")
                .font(.brand(20, .heavy))
                .foregroundColor(hue)
                .frame(height: 20)
            Text(word)
                .font(.brand(10, .bold))
                .tracking(1)
                .foregroundColor(Palette.subdued)
                .frame(height: 15)
        }
        .padding(.vertical, 17)
        .frame(maxWidth: .infinity)
        .background(shape.fill(RevealPalette.tile))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
        .overlay(EdgeHighlight(radius: 16, intensity: dimmed ? 0 : 0.05))
        .shadow(color: dimmed ? Color.clear : glow, radius: 12)
        .opacity(dimmed ? 0.55 : 1)
        .task(id: amount) { await countUp() }
    }

    private func countUp() async {
        counted = 0
        try? await Task.sleep(nanoseconds: 900_000_000)
        let start: Date = Date()
        while !Task.isCancelled {
            let progress: Double = min(Date().timeIntervalSince(start) / 1.1, 1)
            let rest: Double = 1 - progress
            let eased: Double = 1 - rest * rest * rest
            counted = Int((Double(amount) * eased).rounded())
            if progress >= 1 { return }
            try? await Task.sleep(nanoseconds: 16_000_000)
        }
    }
}

/// WHAT WAS PLAYING: rgba(24,23,39,.9), border accent 24 %, padding 16. Header
/// eye 13 + label 10 pt bold, tracking 1, in the accent colour. Rows gap 8:
/// number (10 pt bold, 16 wide), cover 32 (corners 14), title 12 pt bold,
/// artist 11 pt, year 11 pt bold - all grey but the title.
struct SongList: View {
    let tracks: [Track]

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "eye")
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
                Text("WHAT WAS PLAYING")
                    .font(.brand(10, .bold))
                    .tracking(1)
            }
            .foregroundColor(Palette.accent)
            .frame(height: 15)
            .padding(.bottom, 4)

            ForEach(Array(tracks.enumerated()), id: \.offset) { index, track in
                FinalSongLine(number: index + 1, track: track)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(RevealPalette.songsCard))
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.24), lineWidth: 1))
    }
}

private struct FinalSongLine: View {
    let number: Int
    let track: Track

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.brand(10, .bold))
                .foregroundColor(Palette.subdued)
                .frame(minWidth: 16, alignment: .leading)
            Cover(address: track.albumArt, rim: 32, corner: 14, edged: false, fillColor: RevealPalette.songCover)
            VStack(alignment: .leading, spacing: 0) {
                Text(track.title)
                    .font(.brand(12, .bold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                    .frame(minHeight: 18)
                Text(track.artist)
                    .font(.brand(11))
                    .foregroundColor(Palette.subdued)
                    .lineLimit(1)
                    .frame(minHeight: 17)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let year = track.year {
                Text(String(year))
                    .font(.brand(11, .bold))
                    .foregroundColor(Palette.subdued)
            }
        }
    }
}

/// The purple glow at the top of the final page: 700 × 500, elliptical,
/// accent-deep 45 % → transparent 70 %, blur 40. It scrolls with the page.
private struct FinalTopGlow: View {
    var body: some View {
        Rectangle()
            .fill(RadialGradient(colors: [Palette.accentDeep.opacity(0.45), Palette.accentDeep.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: 346))
            .frame(width: 700, height: 700)
            .scaleEffect(x: 1, y: 500.0 / 700.0)
            .frame(width: 700, height: 500)
            .blur(radius: 20)
            .allowsHitTesting(false)
    }
}

/// The faint green glow at the bottom: 500 × 300, rgba(52,211,153,.08), blur 60.
private struct FinalBottomGlow: View {
    var body: some View {
        Rectangle()
            .fill(RadialGradient(colors: [Palette.good.opacity(0.08), Palette.good.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: 247))
            .frame(width: 500, height: 500)
            .scaleEffect(x: 1, y: 300.0 / 500.0)
            .frame(width: 500, height: 300)
            .blur(radius: 30)
            .allowsHitTesting(false)
    }
}

/// 14 pieces of confetti falling once (1.8-3 s each, staggered), with the same
/// positions, colours, sizes and drift as the browser.
private struct FinalConfetti: View {
    @State private var falling: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0..<14, id: \.self) { seed in
                    FinalConfettiPiece(seed: seed, area: geo.size, falling: falling)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .ignoresSafeArea()
        .onAppear { falling = true }
    }
}

private struct FinalConfettiPiece: View {
    let seed: Int
    let area: CGSize
    let falling: Bool

    private static let colors: [Color] = [Palette.accent, Palette.accentDeep, Palette.good,
                                          Color(hex: 0xF59E0B), Palette.bad, Color(hex: 0x60A5FA), Palette.gold]

    var body: some View {
        let s: Double = Double(seed)
        let left: CGFloat = area.width * CGFloat((5 + (s * 7.3).truncatingRemainder(dividingBy: 90)) / 100)
        let delay: Double = (s * 0.13).truncatingRemainder(dividingBy: 1.4)
        let duration: Double = 1.8 + (s * 0.17).truncatingRemainder(dividingBy: 1.2)
        let side: CGFloat = CGFloat(4 + (s * 1.3).truncatingRemainder(dividingBy: 6))
        let drift: CGFloat = CGFloat(-20 + (s * 8.3).truncatingRemainder(dividingBy: 40))
        let hue: Color = FinalConfettiPiece.colors[seed % FinalConfettiPiece.colors.count]
        return Capsule()
            .fill(hue)
            .frame(width: side, height: side * 0.55)
            .rotationEffect(.degrees(falling ? 360 : 0))
            .offset(x: left + (falling ? drift : 0), y: falling ? area.height * 1.1 : -10)
            .animation(.linear(duration: duration).delay(delay), value: falling)
            // opacity 1 → 1 → 0: it only fades in the second half of the fall
            .opacity(falling ? 0 : 1)
            .animation(.linear(duration: duration / 2).delay(delay + duration / 2), value: falling)
    }
}

/// The quiet button of the final page (see `GameOverView.buttons`).
private struct FinalQuietLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Palette.subdued)
                .accessibilityHidden(true)
            Text(title)
                .font(.brand(14, .semibold))
                .foregroundColor(RevealPalette.lavender)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 51)
        .background(shape.fill(RevealPalette.quietButton))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
        .contentShape(shape)
    }
}

private struct FinalQuietButton: View {
    let title: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            FinalQuietLabel(title: title, symbol: symbol)
        }
        .buttonStyle(RevealPressStyle(pressedScale: 0.98))
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Shared pieces

/// Round place badge: gold, silver and bronze gradients (135°) with their glow
/// for the podium, white 7 % with grey digits below it. The final page uses a
/// stronger glow than the reveal.
private struct RevealRankBadge: View {
    let rank: Int
    let size: CGFloat
    let numberFont: Font
    let bigGlow: Bool

    var body: some View {
        let medal: RevealMedal? = RevealMedal.forRank(rank)
        return Text("\(rank)")
            .font(numberFont)
            .foregroundColor(medal == nil ? Palette.subdued : Palette.base)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(badgeFill(medal))
                    .shadow(color: glowColor(medal), radius: glowRadius)
            )
    }

    private func badgeFill(_ medal: RevealMedal?) -> AnyShapeStyle {
        guard let medal else { return AnyShapeStyle(Color.white.opacity(0.07)) }
        return AnyShapeStyle(LinearGradient(colors: medal.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func glowColor(_ medal: RevealMedal?) -> Color {
        guard let medal else { return Color.clear }
        let strength: Double = rank == 1 ? (bigGlow ? 0.7 : 0.55) : (bigGlow ? 0.4 : 0.3)
        return medal.glow.opacity(strength)
    }

    /// CSS blur 16 / 12 for gold, 8 / 6 for silver and bronze.
    private var glowRadius: CGFloat {
        if rank == 1 { return bigGlow ? 8 : 6 }
        return bigGlow ? 4 : 3
    }
}

private struct RevealMedal {
    let colors: [Color]
    let glow: Color

    static func forRank(_ rank: Int) -> RevealMedal? {
        switch rank {
        case 1: return RevealMedal(colors: [Color(hex: 0xF59E0B), Color(hex: 0xFBBF24)], glow: Color(hex: 0xF59E0B))
        case 2: return RevealMedal(colors: [Color(hex: 0x9CA3AF), Color(hex: 0xD1D5DB)], glow: Color(hex: 0x9CA3AF))
        case 3: return RevealMedal(colors: [Color(hex: 0xB45309), Color(hex: 0xD97706)], glow: Color(hex: 0xB45309))
        default: return nil
        }
    }
}

/// Round player picture: white 7 % with the profile picture, otherwise the
/// person symbol in pale accent (#cc95ff). `ringed` adds the 2 pt accent ring
/// (70 %) with a glow, as the final page does for your own row.
private struct RevealAvatar: View {
    let player: Player
    let size: CGFloat
    let ringed: Bool

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            if let url = pictureURL {
                AsyncImage(url: url) { phase in
                    if let loaded = phase.image {
                        loaded.resizable().scaledToFill()
                    } else {
                        symbol
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                symbol
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(Palette.accent.opacity(ringed ? 0.7 : 0), lineWidth: 2))
        .shadow(color: ringed ? Palette.accent.opacity(0.3) : Color.clear, radius: 5)
        .accessibilityHidden(true)
    }

    private var symbol: some View {
        Image(systemName: "person.fill")
            .font(.system(size: size * 0.42))
            .foregroundColor(RevealPalette.avatarPale)
    }

    private var pictureURL: URL? {
        guard let address = player.avatarUrl, address.hasPrefix("http") else { return nil }
        return URL(string: address)
    }
}

/// Small cover for lists. `corner` defaults to 17 % of the edge; `edged` draws
/// the fine border, `fillColor` shows while loading or when there is no art.
struct Cover: View {
    let address: String?
    var rim: CGFloat = 72
    var corner: CGFloat? = nil
    var edged: Bool = true
    var fillColor: Color = Palette.muted

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: corner ?? rim * 0.17, style: .continuous)
        return Group {
            if let address, let url = URL(string: address) {
                AsyncImage(url: url) { picture in
                    picture.resizable().scaledToFill()
                } placeholder: {
                    fillColor
                }
            } else {
                ZStack {
                    fillColor
                    Image(systemName: "music.note")
                        .font(.system(size: rim * 0.4))
                        .foregroundColor(Palette.subdued)
                }
            }
        }
        .frame(width: rim, height: rim)
        .clipShape(shape)
        .overlay(shape.strokeBorder(edged ? Palette.border : Color.clear, lineWidth: 1))
    }
}

/// Fade and slide in like the browser's motion.div (ease [.16, 1, .3, 1]).
private struct RevealRise: ViewModifier {
    let shown: Bool
    var dx: CGFloat = 0
    var dy: CGFloat = 12
    var delay: Double = 0
    var duration: Double = 0.5

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : dx, y: shown ? 0 : dy)
            .animation(.timingCurve(0.16, 1, 0.3, 1, duration: duration).delay(delay), value: shown)
    }
}

/// Scale a little on press (whileTap).
private struct RevealPressStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// The browser's equalizer (`Ft`): nine bars 3 wide with 3 gap in a 20 high
/// box, accent at 55 %, each bobbing between full and 22 % height with its
/// own duration and delay. `scale` is the browser's `size` (the reveal uses .8).
private struct RevealEqualizer: View {
    var scale: CGFloat = 1
    @State private var bobbing: Bool = false

    private static let heights: [CGFloat] = [8, 14, 10, 18, 12, 16, 9, 13, 11]
    private static let durations: [Double] = [0.55, 0.40, 0.70, 0.45, 0.60, 0.50, 0.65, 0.42, 0.58]
    private static let delays: [Double] = [0.00, 0.08, 0.04, 0.12, 0.06, 0.10, 0.02, 0.14, 0.07]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<RevealEqualizer.heights.count, id: \.self) { i in
                Capsule()
                    .fill(Palette.accent.opacity(0.55))
                    .frame(width: 3 * scale, height: RevealEqualizer.heights[i] * scale)
                    .scaleEffect(x: 1, y: bobbing ? 0.22 : 1, anchor: .bottom)
                    .animation(.easeInOut(duration: RevealEqualizer.durations[i] / 2)
                        .repeatForever(autoreverses: true)
                        .delay(RevealEqualizer.delays[i]), value: bobbing)
            }
        }
        .frame(height: 20 * scale, alignment: .bottom)
        .accessibilityHidden(true)
        .onAppear { bobbing = true }
    }
}

/// Colours that only occur on these two screens; the numbers are the browser's
/// rgba values.
private enum RevealPalette {
    static func rgba(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> Color {
        Color(.sRGB, red: red / 255, green: green / 255, blue: blue / 255, opacity: alpha)
    }

    static let dim: Color = rgba(4, 4, 10, 0.72)
    static let sneakyDim: Color = rgba(4, 4, 10, 0.86)
    static let sheet: Color = rgba(11, 10, 22, 0.98)
    static let footer: Color = rgba(7, 7, 14, 0.95)
    static let trackCard: Color = rgba(15, 10, 40, 0.95)
    static let youCard: Color = rgba(20, 10, 50, 0.95)
    static let otherCard: Color = rgba(24, 23, 39, 0.95)
    static let youRow: Color = rgba(20, 10, 50, 0.9)
    static let otherRow: Color = rgba(24, 23, 39, 0.88)
    static let songsCard: Color = rgba(24, 23, 39, 0.9)
    static let tile: Color = rgba(24, 23, 39, 0.95)
    static let quietButton: Color = rgba(24, 23, 39, 0.8)
    /// #ef4444 - the base of all red tints (the red text itself is #f87171).
    static let red: Color = Color(hex: 0xEF4444)
    /// #b0aed2 - artist, quiet button text, other players' totals.
    static let lavender: Color = Color(hex: 0xB0AED2)
    /// #cc95ff (--acc-pale) - the person symbol in avatars.
    static let avatarPale: Color = Color(hex: 0xCC95FF)
    /// #f59e0b - your row, the guest card, GS.
    static let amber: Color = Color(hex: 0xF59E0B)
    /// #fcd34d - the guest card text.
    static let amberText: Color = Color(hex: 0xFCD34D)
    /// #15141f - empty cover in the song list.
    static let songCover: Color = Color(hex: 0x15141F)

    /// The browser colours names with the player's accent colour
    /// (`accentColorId`, default #b15cff). The app does not decode that field,
    /// so every human gets the default accent; bots have none.
    static func nameColor(_ player: Player, fallback: Color) -> Color {
        player.isBot ? fallback : Palette.accent
    }
}

/// The breakdown arrives as a dictionary - without a fixed order it would
/// jump around every round.
enum BreakdownOrder {
    struct Entry { let category: String; let amount: ScoreItem }

    private static let order = ["title", "artist", "year", "speed", "streak"]

    static func ordered(_ bd: [String: ScoreItem]) -> [Entry] {
        bd.map { Entry(category: $0.key, amount: $0.value) }
          .sorted { a, b in
              let ia = order.firstIndex(of: a.category) ?? order.count
              let ib = order.firstIndex(of: b.category) ?? order.count
              return ia == ib ? a.category < b.category : ia < ib
          }
    }
}
