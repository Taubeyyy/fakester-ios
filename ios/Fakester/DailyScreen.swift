import SwiftUI

/// "Daily" (`wN` in the web bundle): the same five songs for everyone, one
/// try, 15 seconds each. Start card → five rounds (cover, player controls,
/// four titles) → result with the squares, "Share result", the answers and
/// today's board. Measurements from the website at 375 × 812 (k-daily).
struct DailyView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close
    @ObservedObject private var audio = AudioPlayer.instance
    @ObservedObject private var volume = ClipVolume.shared

    private enum Phase { case loading, ready, playing, done }

    @State private var today: DailyToday?
    @State private var failure: String?
    @State private var phase: Phase = .loading
    @State private var round: Int = 0
    @State private var answers: [Int] = []
    @State private var picked: Int?
    @State private var deadline = Date()
    @State private var startedAt = Date()
    @State private var finish: DailyFinish?
    @State private var submitting = false
    @State private var catalog: ItemCatalog?
    @State private var toast: CosmeticToast?

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Daily", onBack: { leave() })
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .task { await load() }
        .onDisappear { audio.stop() }
    }

    @ViewBuilder
    private var content: some View {
        if let message = failure {
            DailyNotice(title: "No round today", text: message)
        } else if let t = today {
            switch phase {
            case .loading:
                DailyLoadingCard()
            case .ready:
                startCard(t)
                DailyBoardCard(board: t.board, catalog: catalog)
            case .playing:
                playing(t)
            case .done:
                results(t)
            }
        } else {
            DailyLoadingCard()
        }
    }

    // MARK: Start

    private func startCard(_ t: DailyToday) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(spacing: 0) {
            Text("DAILY #\(t.day)")
                .font(.brand(10, .bold))
                .tracking(1)
                .foregroundColor(Palette.accent)
                .padding(.bottom, 4)
            Text("\(t.songs) songs.\nOne try.")
                .font(.brand(26, .heavy))
                .multilineTextAlignment(.center)
                .foregroundColor(Palette.foreground)
                .padding(.bottom, 8)
            Text("Everyone gets the same songs today. \(DailyRules.secondsPerSong) seconds each.")
                .font(.brand(12))
                .multilineTextAlignment(.center)
                .foregroundColor(CosmeticTone.nameDim)
                .padding(.bottom, 20)
            Button { start() } label: {
                Text("Start")
                    .font(.brand(14, .bold))
                    .foregroundColor(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                    .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(Palette.accent))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.94)))
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.26), lineWidth: 1))
    }

    // MARK: Playing

    private func playing(_ t: DailyToday) -> some View {
        let r: DailyRound? = round < t.rounds.count ? t.rounds[round] : nil
        return VStack(spacing: 16) {
            TimelineView(.periodic(from: .now, by: 0.1)) { timeline in
                timerRow(total: t.rounds.count, now: timeline.date)
            }
            DailyCover(address: r?.cover, playing: audio.isRunning)
            controls
            if let r = r {
                DailyOptions(options: r.options, picked: picked) { i in pick(i) }
            }
        }
        // Time up: the song counts as missed (-1), like in the browser.
        .onReceive(ticker) { now in
            if phase == .playing && picked == nil && now >= deadline { advance(with: -1) }
        }
    }

    /// "1 / 5", the draining bar (red under 4 s) and the seconds left.
    private func timerRow(total: Int, now: Date) -> some View {
        let left: Double = max(0, deadline.timeIntervalSince(now))
        let fraction: Double = left / Double(DailyRules.secondsPerSong)
        let urgent: Bool = left < 4
        return HStack(spacing: 8) {
            Text("\(round + 1) / \(total)")
                .font(.brand(11, .bold))
                .monospacedDigit()
                .foregroundColor(Palette.subdued)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(urgent ? Palette.bad : Palette.accent)
                        .frame(width: geo.size.width * CGFloat(fraction))
                }
            }
            .frame(height: 6)
            Text("\(Int(left.rounded(.up)))")
                .font(.brand(11, .bold))
                .monospacedDigit()
                .foregroundColor(urgent ? Palette.bad : Palette.subdued)
                .frame(width: 24, alignment: .trailing)
        }
    }

    /// Play/pause 40, mute, a 108 wide volume bar and the percentage.
    private var controls: some View {
        HStack(spacing: 8) {
            Button { audio.flip() } label: {
                LucideGlyph(icon: audio.isRunning ? .pause : .play, size: 15)
                    .foregroundColor(Palette.onAccent)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Palette.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(audio.isRunning ? "Pause" : "Play"))
            Button { volume.toggleMute() } label: {
                LucideGlyph(icon: volume.silent ? .volumeX : .volume2, size: 15)
                    .foregroundColor(volume.silent ? Palette.bad : Palette.subdued)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(volume.muted ? "Unmute" : "Mute"))
            DailyVolumeBar(level: volume.muted ? 0 : volume.level, muted: volume.muted) { v in volume.setLevel(v) }
                .frame(width: 108, height: 24)
            Text(volume.muted ? "off" : "\(Int((volume.level * 100).rounded()))%")
                .font(.brand(10, .bold))
                .monospacedDigit()
                .foregroundColor(Palette.subdued)
                .frame(minWidth: 26, alignment: .trailing)
        }
    }

    // MARK: Results

    private func results(_ t: DailyToday) -> some View {
        let correct: Int = finish?.correct ?? t.result?.correct ?? 0
        let total: Int = finish?.total ?? t.result?.total ?? t.songs
        let given: [Int] = finish != nil ? answers : (t.result?.answers ?? [])
        let solution: [DailySolution] = finish?.solution ?? t.rounds.map { DailySolution(round: $0) }
        let board: DailyBoard = finish?.board ?? t.board
        let day: Int = finish?.day ?? t.day
        let share: String = DailyRules.shareText(day: day, correct: correct, total: total,
                                                 answers: given, solution: solution.map { $0.correct })
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        return VStack(spacing: 16) {
            VStack(spacing: 0) {
                Text("DAILY #\(day)")
                    .font(.brand(10, .bold))
                    .tracking(1)
                    .foregroundColor(Palette.accent)
                    .padding(.bottom, 8)
                (Text("\(correct)").foregroundColor(Palette.foreground)
                 + Text("/\(total)").foregroundColor(Color(hex: 0x6A6889)))
                    .font(.brand(42, .heavy))
                    .padding(.bottom, 4)
                HStack(spacing: 6) {
                    ForEach(0..<solution.count, id: \.self) { i in
                        let right: Bool = i < given.count && given[i] == solution[i].correct
                        RoundedRectangle(cornerRadius: 9, style: .circular)
                            .fill(right ? Palette.good : Color.white.opacity(0.055))
                            .overlay(RoundedRectangle(cornerRadius: 9, style: .circular)
                                .strokeBorder(right ? Color.clear : Color.white.opacity(0.16), lineWidth: 1))
                            .frame(width: 28, height: 28)
                    }
                }
                .padding(.vertical, 14)
                if let f = finish {
                    Text("+\(f.rewardSpots) Spots" + (f.rewardGold > 0 ? " · +\(f.rewardGold) GoldSpots" : ""))
                        .font(.brand(11))
                        .foregroundColor(CosmeticTone.nameDim)
                        .padding(.bottom, 16)
                }
                ShareLink(item: share) {
                    HStack(spacing: 6) {
                        LucideGlyph(icon: .share2, size: 13)
                        Text("Share result")
                    }
                    .font(.brand(13, .bold))
                    .foregroundColor(Palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 16, style: .circular).fill(Palette.accent))
                }
                .buttonStyle(.plain)
                Text("Next round at midnight.")
                    .font(.brand(10))
                    .foregroundColor(Palette.subdued)
                    .padding(.top, 12)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.94)))
            .overlay(shape.strokeBorder(Palette.accent.opacity(0.26), lineWidth: 1))
            DailyListCard(icon: .listChecks, title: "The answers") {
                ForEach(0..<solution.count, id: \.self) { i in
                    DailyAnswerRow(song: solution[i], right: i < given.count && given[i] == solution[i].correct)
                }
            }
            DailyBoardCard(board: board, catalog: catalog)
        }
    }

    // MARK: Flow

    @MainActor
    private func load() async {
        async let items: ItemCatalog? = try? await api.fetchAbsolute("https://fakester.app/catalog.json")
        do {
            var t: DailyToday = try await api.fetch("/daily")
            #if DEBUG
            if let sample = ScreenshotScene.sampleDaily { t = sample }
            #endif
            today = t
            phase = t.played ? .done : .ready
        } catch {
            #if DEBUG
            if let sample = ScreenshotScene.sampleDaily {
                today = sample
                phase = .ready
                catalog = await items
                return
            }
            #endif
            let text: String = error.localizedDescription
            failure = text.isEmpty ? "Could not load today's round" : text
        }
        catalog = await items
    }

    private func start() {
        guard let t = today, !t.rounds.isEmpty else { return }
        Task { let _: Api.Ack? = try? await api.call("/daily/start") }
        answers = []
        picked = nil
        round = 0
        startedAt = Date()
        phase = .playing
        beginRound(t)
    }

    private func beginRound(_ t: DailyToday) {
        deadline = Date().addingTimeInterval(Double(DailyRules.secondsPerSong))
        picked = nil
        volume.apply()
        audio.playPreview(t.rounds[round].preview)
    }

    private func pick(_ index: Int) {
        guard picked == nil else { return }
        Haptics.lock()
        picked = index
        // As in the browser: the choice shows for a moment, then the next song.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { advance(with: index) }
    }

    private func advance(with answer: Int) {
        guard phase == .playing, let t = today, answers.count == round else { return }
        answers.append(answer)
        if answers.count >= t.rounds.count {
            audio.stop()
            Task { await submit() }
        } else {
            round += 1
            beginRound(t)
        }
    }

    @MainActor
    private func submit() async {
        guard !submitting else { return }
        submitting = true
        let elapsed: Int = Int(Date().timeIntervalSince(startedAt) * 1000)
        do {
            let f: DailyFinish = try await api.call("/daily/finish", body: ["answers": answers, "elapsedMs": elapsed])
            finish = f
            if let s = f.balanceSpots { api.setSpots(s) }
            phase = .done
            Haptics.correct()
        } catch {
            let text: String = error.localizedDescription
            if text.lowercased().contains("already"), let fresh: DailyToday = try? await api.fetch("/daily") {
                today = fresh
                phase = .done
            } else {
                withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not submit" : text, isError: true) }
                submitting = false
                return
            }
        }
        submitting = false
    }

    private func leave() {
        audio.stop()
        close()
    }
}

/// The square cover (180) with a blurred copy behind it, darkened while
/// paused, "NOW PLAYING" bottom left - or a spinning disc without a cover.
private struct DailyCover: View {
    let address: String?
    let playing: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(hex: 0x0D0020), Color(hex: 0x1A0040), Color(hex: 0x120030), Color(hex: 0x050015)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let a = address, let url = URL(string: a) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        ZStack {
                            image.resizable().scaledToFill().blur(radius: 18).brightness(-0.25).scaleEffect(1.15)
                            image.resizable().scaledToFit()
                                .saturation(playing ? 1 : 0.6)
                                .brightness(playing ? 0 : -0.15)
                                .animation(.easeOut(duration: 0.4), value: playing)
                        }
                    } else {
                        Color.clear
                    }
                }
                LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                       .init(color: Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.75), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                HStack(spacing: 6) {
                    BoardLoadingBars(tint: Color.white.opacity(0.85)).scaleEffect(0.8, anchor: .bottomLeading).frame(width: 40, height: 16, alignment: .bottomLeading)
                    Text("NOW PLAYING")
                        .font(.brand(10, .bold))
                        .tracking(1)
                        .foregroundColor(Color.white.opacity(0.75))
                }
                .padding(12)
            } else {
                // No cover: a soft glow, a record that spins while the clip plays,
                // and "NO COVER" underneath.
                Circle()
                    .fill(RadialGradient(colors: [Palette.accentDeep.opacity(0.4), Palette.accentDeep.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: 52))
                    .frame(width: 160, height: 160)
                    .blur(radius: 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 12) {
                    TimelineView(.animation(paused: !playing)) { timeline in
                        let angle: Double = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4) / 4 * 360
                        Circle()
                            .fill(AngularGradient(colors: [Color(hex: 0x1A0040), Color(hex: 0x2D1B69), Color(hex: 0x1A0040),
                                                           Color(hex: 0x3B0764), Color(hex: 0x1A0040)], center: .center))
                            .overlay(Circle().fill(RadialGradient(colors: [Palette.accent, Palette.accentDeep], center: .center,
                                                                  startRadius: 0, endRadius: 14))
                                .frame(width: 28, height: 28))
                            .rotationEffect(.degrees(angle))
                    }
                    .frame(width: 96, height: 96)
                    .shadow(color: Palette.accentDeep.opacity(0.5), radius: 16)
                    Text("NO COVER")
                        .font(.brand(11, .bold))
                        .tracking(1)
                        .foregroundColor(Color.white.opacity(0.35))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 180, height: 180)
        .clipShape(shape)
        .frame(maxWidth: .infinity)
    }
}

/// The four titles (`X1`): label "TITLE" (+ tick once chosen) and a 2-column
/// grid; the choice lights up, the rest fade.
private struct DailyOptions: View {
    let options: [String]
    let picked: Int?
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("TITLE").font(.brand(10, .bold)).tracking(1).foregroundColor(Palette.subdued)
                if picked != nil {
                    LucideGlyph(icon: .check, size: 10).foregroundColor(Palette.accent)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(0..<options.count, id: \.self) { i in
                    option(i)
                }
            }
        }
    }

    private func option(_ i: Int) -> some View {
        let on: Bool = picked == i
        let locked: Bool = picked != nil
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button { if !locked { onPick(i) } } label: {
            Text(options[i])
                .font(.brand(12, .semibold))
                .foregroundColor(on ? CosmeticTone.accentPale : CosmeticTone.nameDim)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(shape.fill(on ? Palette.accentDeep.opacity(0.28) : Color.white.opacity(0.04)))
                .overlay(shape.strokeBorder(on ? Palette.accent.opacity(0.65) : Color.white.opacity(0.08), lineWidth: 1))
                .shadow(color: on ? Palette.accentDeep.opacity(0.25) : Color.clear, radius: 8)
                .opacity(locked && !on ? 0.45 : 1)
        }
        .buttonStyle(.plain)
    }
}

/// The 108 pt volume bar: 4 tall, white 9 % track, white 26 % fill, 8 pt knob.
private struct DailyVolumeBar: View {
    let level: Double
    let muted: Bool
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w: CGFloat = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.09)).frame(height: 4)
                Capsule().fill(muted ? Color(hex: 0x6A6889) : Color.white.opacity(0.26))
                    .frame(width: w * CGFloat(level), height: 4)
                Circle().fill(muted ? Palette.subdued : Color(hex: 0x9D9CBB))
                    .frame(width: 8, height: 8)
                    .offset(x: w * CGFloat(level) - 4)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                onChange(Double(max(0, min(1, g.location.x / max(1, w)))))
            })
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Volume"))
        .accessibilityValue(Text("\(Int((level * 100).rounded())) percent"))
    }
}

/// A card with a header row (`it`): icon + uppercase label in the accent.
private struct DailyListCard<Rows: View>: View {
    let icon: LucideIcon
    let title: String
    @ViewBuilder let rows: () -> Rows

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                LucideGlyph(icon: icon, size: 14)
                Text(title.uppercased()).font(.brand(12, .bold)).tracking(1.2)
                Spacer(minLength: 0)
            }
            .foregroundColor(Palette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.02))
            Rectangle().fill(Palette.border).frame(height: 1)
            VStack(spacing: 4) { rows() }
                .padding(8)
        }
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}

private struct DailyAnswerRow: View {
    let song: DailySolution
    let right: Bool

    var body: some View {
        HStack(spacing: 10) {
            Group {
                if let a = song.cover, let url = URL(string: a) {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() } else { Color.white.opacity(0.05) }
                    }
                } else {
                    Color.white.opacity(0.05)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .circular))
            .shadow(color: Color.black.opacity(0.45), radius: 4, x: 0, y: 2)
            LucideGlyph(icon: right ? .circleCheck : .circleAlert, size: 13)
                .foregroundColor(right ? Palette.good : Palette.bad)
            VStack(alignment: .leading, spacing: 0) {
                Text(song.title).font(.brand(13, .semibold)).foregroundColor(Palette.foreground).lineLimit(1)
                Text(song.artist).font(.brand(11)).foregroundColor(Palette.subdued).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color.white.opacity(0.03)))
    }
}

/// Today's board (`p0`): "Today · n played", the top rows, your rank.
private struct DailyBoardCard: View {
    let board: DailyBoard
    let catalog: ItemCatalog?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                LucideGlyph(icon: .trophy, size: 14)
                Text("TODAY · \(board.players) PLAYED").font(.brand(12, .bold)).tracking(1.2)
                Spacer(minLength: 0)
            }
            .foregroundColor(Palette.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.02))
            Rectangle().fill(Palette.border).frame(height: 1)
            if board.top.isEmpty {
                Text("Nobody has played yet today. Be first.")
                    .font(.brand(12))
                    .foregroundColor(Palette.subdued)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 4) {
                    ForEach(0..<board.top.count, id: \.self) { i in
                        row(board.top[i], place: i + 1)
                    }
                }
                .padding(8)
            }
            if let rank = board.rank {
                Rectangle().fill(Palette.border).frame(height: 1)
                (Text("You are ") + Text("#\(rank)").bold().foregroundColor(Palette.accent) + Text(" of \(board.players) today."))
                    .font(.brand(11))
                    .foregroundColor(CosmeticTone.nameDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }

    private func row(_ e: DailyBoardEntry, place: Int) -> some View {
        HStack(spacing: 10) {
            Text("#\(place)")
                .font(.brand(11, .bold))
                .monospacedDigit()
                .foregroundColor(place <= 3 ? Palette.accent : Palette.subdued)
                .frame(width: 24, alignment: .leading)
            PlayerAvatar(size: 22, picture: e.avatarURL, icon: catalog?.item("icon", id: e.iconID))
            Text(e.username).font(.brand(13, .semibold)).foregroundColor(Palette.foreground).lineLimit(1)
            Spacer(minLength: 0)
            Text("\(e.correct)/\(e.total)").font(.brand(12, .bold)).monospacedDigit().foregroundColor(Palette.foreground)
            Text(String(format: "%.1fs", Double(e.elapsedMs) / 1000))
                .font(.brand(10))
                .monospacedDigit()
                .foregroundColor(Palette.subdued)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color.white.opacity(0.03)))
    }
}

/// While `/daily` loads: a light sweep over the card, the loader and
/// "Cueing up today's round".
private struct DailyLoadingCard: View {
    @State private var sweep = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        VStack(spacing: 16) {
            BoardLoadingBars()
            VStack(spacing: 4) {
                Text("Cueing up today’s round").font(.brand(14, .bold)).foregroundColor(Palette.foreground)
                Text("Same five songs for everyone.").font(.brand(11)).foregroundColor(Palette.subdued)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .background(
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.94))
                    LinearGradient(colors: [.clear, Palette.accent.opacity(0.13), .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: geo.size.width / 3)
                        .offset(x: sweep ? geo.size.width * 1.1 : -geo.size.width * 0.4)
                }
                .clipShape(shape)
            }
        )
        .overlay(shape.strokeBorder(Palette.accent.opacity(0.22), lineWidth: 1))
        .onAppear {
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) { sweep = true }
        }
    }
}

private struct DailyNotice: View {
    let title: String
    let text: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 4) {
            LucideGlyph(icon: .triangleAlert, size: 20).foregroundColor(Palette.bad).padding(.bottom, 4)
            Text(title).font(.brand(14, .semibold)).foregroundColor(Palette.foreground)
            Text(text).font(.brand(12)).foregroundColor(Palette.subdued).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
    }
}
