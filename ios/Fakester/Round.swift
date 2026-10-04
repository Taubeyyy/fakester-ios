import SwiftUI

/// Die Rateansicht, nach dem Browser nachgebaut: oben Rundenzaehler, Uhr-Pille
/// und Verlassen, darunter ein feiner Fortschrittsstrich, dann das Cover mit
/// "NOW PLAYING", die Abspielkarte und die Antworten in zwei Spalten.
///
/// Der Knopf unten ist bewusst nicht endgueltig: der Server erlaubt beliebig oft
/// umzuwaehlen, weil der Schnelligkeitsbonus am Sperrzeitpunkt haengt und ein
/// spaeteres Umwaehlen sich dadurch von selbst bezahlt macht.
struct RoundView: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(spacing: 0) {
            header
            ProgressBar(fraction: fraction, hue: clockColor, frameHeight: 3)
                .animation(.linear(duration: 0.25), value: fraction)

            ScrollView {
                VStack(spacing: 14) {
                    myChip
                    LargeCover()
                    PlaybackCard()
                    ForEach(game.guessKinds, id: \.self) { kind in
                        AnswerBlock(kind: kind)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottomTrailing) { ReactionCloud() }

            ReactionBar()
            lockButton
        }
    }

    // MARK: Kopf

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Text("ROUND")
                    .font(.brand(13, .heavy)).tracking(0.8)
                    .foregroundColor(Palette.accent)
                Text("\(game.activeRound?.round ?? 0)")
                    .font(.brand(13, .black))
                    .foregroundColor(Palette.foreground)
                Text("/ \(game.activeRound?.totalRounds ?? 0)")
                    .font(.brand(13, .heavy))
                    .foregroundColor(Palette.faint)
            }

            HStack(spacing: 5) {
                Image(systemName: "clock").font(.system(size: 11, weight: .bold))
                Text("\(game.secondsLeft)s").font(.mono(12))
            }
            .foregroundColor(clockColor)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(Capsule().fill(clockColor.opacity(0.10)))
            .overlay(Capsule().strokeBorder(clockColor.opacity(0.26), lineWidth: 1))

            Spacer(minLength: 0)
            LeaveButton { game.leave() }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    /// Unter zehn Sekunden wechselt die Uhr im Browser auf Orange. Das ist der
    /// einzige Moment, in dem die Seite laut wird - also hier auch.
    private var clockColor: Color {
        if game.secondsLeft <= 5 { return Palette.bad }
        if game.secondsLeft <= 10 { return Color(hex: 0xFB923C) }
        return Palette.accent
    }

    private var fraction: Double {
        let fullTime: Int = game.lobbySettings?.guessTime ?? 30
        guard fullTime > 0 else { return 0 }
        return min(1, max(0, Double(game.secondsLeft) / Double(fullTime)))
    }

    private var myChip: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "person.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Palette.accent)
                Text(game.me?.nickname ?? "")
                    .font(.brand(13, .heavy))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                Text("\(game.me?.score ?? 0)")
                    .font(.mono(13))
                    .foregroundColor(Palette.faint)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(Palette.accent.opacity(0.10)))
            .overlay(Capsule().strokeBorder(Palette.accent.opacity(0.24), lineWidth: 1))
            Spacer(minLength: 0)
        }
    }

    // MARK: Sperrknopf

    /// Der Browser schreibt auf den Knopf, was noch fehlt, statt ihn nur grau zu
    /// lassen. Das ist der Unterschied zwischen "geht nicht" und "mach noch das".
    private var lockButton: some View {
        let missing: [String] = game.guessKinds.filter { kind in
            game.answer[kind].trimmingCharacters(in: .whitespaces).isEmpty
        }
        return Button {
            if game.lockedIn {
                Haptics.tap()
                game.reconsider()
            } else {
                Haptics.lock()
                game.lockIn()
            }
        } label: {
            Label(buttonTitle(missing), systemImage: game.lockedIn ? "arrow.uturn.backward" : "checkmark")
        }
        .buttonStyle(PrimaryButtonStyle(hue: game.lockedIn ? Palette.rim : Palette.accent,
                                dimmed: !game.lockedIn && !missing.isEmpty))
        .disabled(!game.lockedIn && !missing.isEmpty)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func buttonTitle(_ missing: [String]) -> String {
        if game.lockedIn { return "Change answer" }
        if missing.isEmpty { return "Lock in answer" }
        let words: [String] = missing.map { DisplayName.guessKind($0).lowercased() }
        return "Pick \(items(words))"
    }

    private func items(_ w: [String]) -> String {
        guard w.count > 1 else { return w.first ?? "" }
        let ampersand: String = " & "
        return w.dropLast().joined(separator: ", ") + ampersand + (w.last ?? "")
    }
}

// MARK: - Cover

/// Das Cover mit dem "NOW PLAYING"-Streifen. Im Reverse-Modus und wenn der
/// Gastgeber Cover abgeschaltet hat, kommt keins - dann steht hier die Welle.
struct LargeCover: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.muted)

            if let address = game.activeRound?.albumArt, let url = URL(string: address) {
                AsyncImage(url: url) { picture in
                    picture.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "music.note")
                        .font(.system(size: 34))
                        .foregroundColor(Palette.faint)
                }
            } else {
                Image(systemName: "waveform")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(Palette.accent)
            }

            HStack(spacing: 8) {
                WaveBars()
                Text("NOW PLAYING")
                    .font(.brand(11, .black)).tracking(1.1)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(colors: [.black.opacity(0.75), .clear],
                               startPoint: .bottom, endPoint: .top)
            )
        }
        .frame(height: 180)
        .frame(maxWidth: 180)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.border, lineWidth: 1)
        )
        .shadow(color: Palette.accent.opacity(0.22), radius: 22, y: 8)
    }
}

/// Die wippenden Balken auf dem Cover und in der Auflösung.
struct WaveBars: View {
    var hue: Color = .white
    @State private var on = false
    private let heights: [CGFloat] = [4, 8, 12, 6, 10]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                Capsule()
                    .fill(hue.opacity(0.9))
                    .frame(width: 2.5, height: on ? h : h * 0.4)
                    .animation(.easeInOut(duration: 0.5 + Double(i % 3) * 0.2)
                        .repeatForever(autoreverses: true), value: on)
            }
        }
        .frame(height: 12)
        .onAppear { on = true }
    }
}

// MARK: - Abspielkarte

/// Zeigt, dass und wie weit der Schnipsel laeuft, und laesst ihn anhalten.
/// Im Browser steht hier dieselbe Karte; sie ist der Beweis, dass Ton kommt -
/// ohne sie sitzt man bei einem stummen Geraet ratlos da.
struct PlaybackCard: View {
    @EnvironmentObject private var game: Game
    @ObservedObject private var tone = AudioPlayer.instance

    var body: some View {
        Card(inset: 14) {
            VStack(spacing: 12) {
                HStack {
                    Text("Now playing")
                        .font(.brand(12, .heavy))
                        .foregroundColor(Palette.accent)
                    Spacer()
                    Text("\(clockText(tone.elapsed)) / \(clockText(tone.length))")
                        .font(.mono(11, isBold: false))
                        .foregroundColor(Palette.faint)
                }

                HStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        tone.flip()
                    } label: {
                        ZStack {
                            Circle().fill(Palette.gradient)
                            Image(systemName: tone.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundColor(Palette.onAccent)
                        }
                        .frame(width: 40, height: 40)
                        .shadow(color: Palette.accent.opacity(0.4), radius: 8)
                    }
                    .buttonStyle(BubblePressStyle())

                    ProgressBar(fraction: tone.fraction, hue: Palette.accent, frameHeight: 6)
                }
            }
        }
    }

    private func clockText(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let g = Int(s)
        return String(format: "%d:%02d", g / 60, g % 60)
    }
}

// MARK: - Antworten

/// Eine Rateart mit ihren Moeglichkeiten. Im Browser stehen sie zu zweit
/// nebeneinander, und das Etikett bekommt ein Haekchen, sobald etwas gewaehlt
/// ist - so sieht man beim Runterscrollen, was noch offen ist.
struct AnswerBlock: View {
    @EnvironmentObject private var game: Game
    let kind: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(DisplayName.guessKind(kind).uppercased()).eyebrow()
                if !game.answer[kind].trimmingCharacters(in: .whitespaces).isEmpty {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Palette.accent)
                }
            }

            if game.lobbySettings?.isMultipleChoice ?? true {
                choices
            } else {
                InputField(text: Binding(get: { game.answer[kind] },
                                   set: { game.answer[kind] = $0 }),
                     placeholderText: DisplayName.guessKind(kind),
                     digitsOnly: kind == "year")
            }
        }
    }

    private var choices: some View {
        let possible: [LooseValue] = game.activeRound?.mcOptions[kind] ?? []
        let gridColumns: [GridItem] = [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)]
        return LazyVGrid(columns: gridColumns, spacing: 9) {
            ForEach(possible, id: \.self) { m in
                ChoiceButton(text: m.text, selected: game.answer[kind] == m.text) {
                    Haptics.tap()
                    game.answer[kind] = game.answer[kind] == m.text ? "" : m.text
                }
            }
        }
    }
}

struct ChoiceButton: View {
    let text: String
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(text)
                    .font(.brand(14, selected ? .heavy : .medium))
                    .foregroundColor(Palette.foreground)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(base)
            .shadow(color: selected ? Palette.accent.opacity(0.3) : .clear, radius: 10)
            .animation(.easeOut(duration: 0.14), value: selected)
        }
        .buttonStyle(BubblePressStyle())
    }

    private var base: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            shape.fill(selected ? Palette.accent.opacity(0.22) : Palette.surface)
            shape.strokeBorder(selected ? Palette.accent : Palette.border, lineWidth: selected ? 1.5 : 1)
        }
    }
}

// MARK: - Reaktionen

/// Die fuenf runden Emoji-Knoepfe wie im Browser. Was man drueckt, sehen alle -
/// der Server schickt es als `player-reacted` an jeden zurueck, auch an einen
/// selbst, deshalb zeigt die App hier nichts vorab an.
struct ReactionBar: View {
    @EnvironmentObject private var game: Game
    @State private var previous = Date.distantPast

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Reaction.choices, id: \.self) { e in
                Button {
                    // Kleine Bremse, damit Dauerdruecken die Lobby nicht flutet.
                    guard Date().timeIntervalSince(previous) > 0.6 else { return }
                    previous = Date()
                    Haptics.tap()
                    game.react(e)
                } label: {
                    Text(e)
                        .font(.system(size: 20))
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(Palette.surface))
                        .overlay(Circle().strokeBorder(Palette.rim, lineWidth: 1))
                }
                .buttonStyle(BubblePressStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Palette.base.opacity(0.85)))
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
        .padding(.top, 6)
        .padding(.bottom, 8)
    }
}

/// Die Emojis, die gerade jemand geschickt hat - steigen rechts auf und gehen.
struct ReactionCloud: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ForEach(game.reactions) { r in
                HStack(spacing: 6) {
                    Text(r.nickname)
                        .font(.brand(11, .bold))
                        .foregroundColor(Palette.subdued)
                        .lineLimit(1)
                    Text(r.reaction).font(.system(size: 22))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Palette.surface.opacity(0.92)))
                .overlay(Capsule().strokeBorder(Palette.rim, lineWidth: 1))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: game.reactions)
        .padding(.trailing, 16)
        .padding(.bottom, 8)
        .allowsHitTesting(false)
    }
}
