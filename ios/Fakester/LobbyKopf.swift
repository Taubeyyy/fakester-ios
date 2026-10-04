import SwiftUI
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// Die Lobby, nachgebaut nach fakester.app im Handyformat (375×812, Oktober 2026):
/// Kopf mit rundem Zurueck-Pfeil und grossem „Lobby", die PIN-Karte (zugedeckt,
/// bis man sie aufdeckt), die Pillen-Reihe, das PLAYERS-Raster mit vier Spalten
/// und freien Plaetzen, die Chat-Karte und unten „Invite players" + „Start Game".
/// „Invite" oeffnet wie im Browser ein Blatt mit QR-Code und Link.
struct LobbyAnsicht: View {
    @EnvironmentObject private var spiel: Spiel
    @State private var pinOffen = false
    @State private var einladen = false
    /// Gastgeber mit Mitspielern muss zweimal tippen - wie im Browser.
    @State private var rausGewarnt = false

    /// Vier Spalten, Abstand 8 - wie im Browser.
    private let spalten: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)

    var body: some View {
        ZStack(alignment: .bottom) {
            hauptteil
                .blur(radius: einladen ? 3 : 0)

            if einladen {
                KopfFarbe.abdunkeln
                    .ignoresSafeArea()
                    .onTapGesture { einladungZu() }
                    .transition(.opacity)
                    .zIndex(1)
                EinladeBlatt(pin: spiel.pin, gast: binGast, schliessen: { einladungZu() })
                    .transition(.move(edge: .bottom))
                    .zIndex(2)
            }
        }
    }

    private var hauptteil: some View {
        VStack(spacing: 0) {
            LobbyKopfleiste(zurueck: { zurueck() })

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    PinKarte(pin: spiel.pin, offen: $pinOffen, einladen: { einladungAuf() })
                    if let e = spiel.einstellungen {
                        Chips(einstellungen: e, spielart: spiel.spielart)
                    }
                    spielerblock
                    LobbyChatKarte()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)

            fussleiste
        }
    }

    private var binGast: Bool {
        let ich: Spieler? = spiel.spieler.first(where: { $0.id.text == spiel.eigeneId })
        return ich?.isGuest ?? true
    }

    // MARK: Zurueck

    /// Wie im Browser: Ist man Gastgeber und sind schon andere da, schliesst
    /// Gehen die Lobby fuer alle - also erst warnen, beim zweiten Tippen gehen.
    private func zurueck() {
        if spiel.binIchHost && spiel.spieler.count > 1 && !rausGewarnt {
            rausGewarnt = true
            Spuerbar.tipp()
            spiel.meldung = "Leaving closes the lobby — tap back again"
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                rausGewarnt = false
            }
            return
        }
        spiel.verlassen()
    }

    // MARK: Spieler

    /// "PLAYERS (n)": duenner lila Strich, Personen-Symbol, 11 pt fett gesperrt.
    private var spielerblock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Capsule()
                    .fill(LinearGradient(colors: [Farbe.akzentTief, Farbe.akzentTief.opacity(0)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: 16)
                Image(systemName: "person.2")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Farbe.gedaempft)
                Text("PLAYERS (\(spiel.spieler.count))")
                    .font(.marke(11, .bold))
                    .tracking(1.1)
                    .foregroundColor(Farbe.gedaempft)
                    .lineLimit(1)
            }
            .frame(height: 17)

            LazyVGrid(columns: spalten, spacing: 8) {
                ForEach(Array(spiel.spieler.enumerated()), id: \.element.id) { nr, s in
                    SpielerKarte(spieler: s,
                                 istHost: s.id.text == spiel.hostId,
                                 binIch: s.id.text == spiel.eigeneId,
                                 hoehe: zeilenHoehe(nr))
                }
                ForEach(0..<freiePlaetze, id: \.self) { i in
                    Button {
                        einladungAuf()
                    } label: {
                        FreierPlatz(nummer: i, hoehe: zeilenHoehe(spiel.spieler.count + i))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Der Browser fuellt nur die erste Reihe mit freien Plaetzen auf
    /// (max(0, 4 - Spieler)). Kommen mehr Leute, gibt es keine Luecken.
    private var freiePlaetze: Int {
        max(0, 4 - spiel.spieler.count)
    }

    /// Im CSS-Grid ist jede Kachel so hoch wie die hoechste ihrer Reihe.
    private func zeilenHoehe(_ index: Int) -> CGFloat {
        let anzahl: Int = spiel.spieler.count + freiePlaetze
        let anfang: Int = (index / 4) * 4
        let ende: Int = min(anfang + 4, anzahl)
        var hoehe: CGFloat = 0
        var i: Int = anfang
        while i < ende {
            if i < spiel.spieler.count {
                let s: Spieler = spiel.spieler[i]
                hoehe = max(hoehe, SpielerKarte.hoehe(spieler: s, istHost: s.id.text == spiel.hostId))
            } else {
                hoehe = max(hoehe, FreierPlatz.hoehe)
            }
            i += 1
        }
        return hoehe
    }

    // MARK: Unten

    /// rgba(7,7,14,.95) mit Strich oben, Polster 12/16, Abstand 8.
    private var fussleiste: some View {
        VStack(spacing: 8) {
            einladeKnopf
            if spiel.binIchHost {
                startKnopf
            } else {
                warteZeile
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(KopfFarbe.fuss.ignoresSafeArea(edges: .bottom))
        .overlay(alignment: .top) {
            Rectangle().fill(Farbe.linie).frame(height: 1)
        }
    }

    /// "Invite players": 42 hoch, nur Rand, 13 pt fett.
    private var einladeKnopf: some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .circular)
        return Button {
            einladungAuf()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 12, weight: .medium))
                Text("Invite players")
                    .font(.marke(13, .bold))
                    .lineLimit(1)
            }
            .foregroundColor(Farbe.schrift)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
            .contentShape(form)
        }
        .buttonStyle(LobbyDruck())
    }

    private var startKnopf: some View {
        Button {
            Spuerbar.sperren()
            spiel.starten()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                Text("Start Game")
                    .lineLimit(1)
            }
        }
        .buttonStyle(LobbyStartStil())
    }

    /// Fuer Mitspieler statt des Startknopfs.
    private var warteZeile: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))
            Text("Waiting for the host to start…")
                .font(.marke(14, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(Farbe.gedaempft)
        .frame(maxWidth: .infinity)
        .frame(height: 51)
        .background(form.fill(Color.white.opacity(0.02)))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    // MARK: Einladen

    private func einladungAuf() {
        Spuerbar.tipp()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            einladen = true
        }
    }

    private func einladungZu() {
        withAnimation(.easeOut(duration: 0.2)) {
            einladen = false
        }
    }
}

// MARK: - Kopf

/// Der Kopf wie im Browser: rgba(7,7,14,.82), Strich unten, Polster 14/16.
/// Runder Zurueck-Knopf 36 (weiss 4 %, Kante 7 %, lila Pfeil 15) und
/// "Lobby" 25 pt sehr fett, eng gesetzt.
private struct LobbyKopfleiste: View {
    let zurueck: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: zurueck) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Farbe.akzent)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.04)))
                        .overlay(Circle().strokeBorder(Farbe.linie, lineWidth: 1))
                        .overlay(Lichtkante(radius: 18, staerke: 0.05))
                        .contentShape(Circle())
                }
                .buttonStyle(LobbyDruck(gedrueckt: 0.92))

                Text("Lobby")
                    .font(.marke(25, .heavy))
                    .tracking(-0.625)
                    .foregroundColor(Farbe.schrift)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle().fill(Farbe.linie).frame(height: 1)
        }
        .background(KopfFarbe.kopf.ignoresSafeArea(edges: .top))
    }
}

// MARK: - PIN

/// Die PIN-Karte: Kaestchen 46×52, zugedeckt mit "•", bis man sie aufdeckt -
/// die PIN haengt oft an einem Bildschirm, den mehr Leute sehen als mitspielen
/// sollen. Darunter "Reveal", "Copy" und das lila "Invite".
struct PinKarte: View {
    let pin: String
    @Binding var offen: Bool
    var einladen: () -> Void = {}
    @State private var kopiert = false
    @State private var huepfen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            kopf
            kaestchenReihe
            knopfReihe
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(grund)
    }

    /// rgba(24,23,39,.92), Kante lila 25 %, Schatten 0 4 24 schwarz 30 %
    /// und ein lila Schein 0 0 40.
    private var grund: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        return ZStack {
            form.fill(Farbe.karte)
            form.strokeBorder(Farbe.akzent.opacity(0.25), lineWidth: 1)
            Lichtkante(radius: 16, staerke: 0.05)
        }
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 4)
        .shadow(color: Farbe.akzentTief.opacity(0.08), radius: 20, x: 0, y: 0)
    }

    private var kopf: some View {
        HStack(spacing: 6) {
            Image(systemName: "number")
                .font(.system(size: 10, weight: .semibold))
            Text("GAME PIN")
                .font(.marke(10, .bold))
                .tracking(1)
                .lineLimit(1)
        }
        .foregroundColor(Farbe.akzent)
        .frame(height: 15)
    }

    private var kaestchenReihe: some View {
        Button {
            umschalten()
        } label: {
            HStack(spacing: 8) {
                ForEach(Array(zeichen.enumerated()), id: \.offset) { nr, c in
                    kaestchen(c, nr)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var knopfReihe: some View {
        HStack(spacing: 8) {
            kleinerKnopf(offen ? "Hide" : "Reveal",
                         offen ? "eye.slash" : "eye", gruen: false) {
                umschalten()
            }
            if !pin.isEmpty {
                kleinerKnopf(kopiert ? "Copied" : "Copy",
                             kopiert ? "checkmark" : "square.on.square", gruen: kopiert) {
                    kopieren()
                }
            }
            Button(action: einladen) {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 11, weight: .medium))
                    Text("Invite")
                        .font(.marke(11, .bold))
                        .lineLimit(1)
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 17)
                .frame(height: 35)
                .background(Capsule().fill(Farbe.akzent))
            }
            .buttonStyle(LobbyDruck())
            Spacer(minLength: 0)
        }
    }

    /// Der Server vergibt vier Stellen; sollte er je laenger werden, kommen
    /// Kaestchen dazu, statt die PIN abzuschneiden.
    private var zeichen: [Character] {
        Array(pin.isEmpty ? "----" : pin)
    }

    /// 22 pt sehr fett, Grund lila 7 %. Zugedeckt Kante weiss 9 %, aufgedeckt
    /// Kante lila 45 % mit Schein 0 0 14 lila 18 %.
    private func kaestchen(_ c: Character, _ nr: Int) -> some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .circular)
        let rand: Color = offen ? Farbe.akzent.opacity(0.45) : Color.white.opacity(0.09)
        let schein: Color = offen ? Farbe.akzent.opacity(0.18) : Color.clear
        let verzoegerung: Double = Double(nr) * 0.05
        return Text(offen ? String(c) : "•")
            .font(.marke(22, .heavy))
            .foregroundColor(Farbe.schrift)
            .frame(width: 46, height: 52)
            .background(form.fill(Farbe.akzent.opacity(0.07)))
            .overlay(form.strokeBorder(rand, lineWidth: 1))
            .shadow(color: schein, radius: 7)
            .scaleEffect(huepfen ? 1.1 : 1)
            .animation(.easeOut(duration: 0.125).delay(verzoegerung), value: huepfen)
    }

    /// "Reveal" / "Copy": 35 hoch, weiss 4 % mit Kante 8 %, Schrift #b0aed2
    /// 11 pt fett. "Copied" kurz gruen.
    private func kleinerKnopf(_ text: String, _ symbol: String, gruen: Bool,
                              _ aktion: @escaping () -> Void) -> some View {
        let schrift: Color = gruen ? Farbe.gut : KopfFarbe.knopfSchrift
        let grund: Color = gruen ? Farbe.gut.opacity(0.12) : Color.white.opacity(0.04)
        let rand: Color = gruen ? Farbe.gut.opacity(0.3) : Color.white.opacity(0.08)
        return Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .medium))
                Text(text)
                    .font(.marke(11, .bold))
                    .lineLimit(1)
            }
            .foregroundColor(schrift)
            .padding(.horizontal, 13)
            .frame(height: 35)
            .background(Capsule().fill(grund))
            .overlay(Capsule().strokeBorder(rand, lineWidth: 1))
        }
        .buttonStyle(LobbyDruck())
    }

    private func umschalten() {
        Spuerbar.tipp()
        let aufdecken: Bool = !offen
        withAnimation(.easeOut(duration: 0.2)) {
            offen = aufdecken
        }
        guard aufdecken else { return }
        // kurzes Aufhuepfen der Kaestchen nacheinander, wie im Browser
        huepfen = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 125_000_000)
            huepfen = false
        }
    }

    private func kopieren() {
        UIPasteboard.general.string = pin
        Spuerbar.richtig()
        kopiert = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            kopiert = false
        }
    }
}

// MARK: - Pillen

/// Die Einstellungen als Pillen in einer eigenen Leiste: rgba(24,23,39,.9),
/// Kante 7 %, Polster 10/12, waagrecht wischbar. Die Playlist in Lila (hoechstens
/// 45 % breit), dann ♪ Songs, ⏱ Zeit, ? Modus - und Sneaky/Speaker, wenn an.
struct Chips: View {
    let einstellungen: Einstellungen
    let spielart: String

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .circular)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                playlistPille
                pille("music.note", "\(einstellungen.songCount)")
                pille("clock", "\(einstellungen.guessTime)s")
                pille("questionmark.circle", modus)
                if einstellungen.sneakyMode {
                    pille("shield", "Sneaky")
                }
                if einstellungen.boxMode {
                    pille("speaker.wave.2", "Speaker")
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
        }
        .background(form.fill(KopfFarbe.leiste))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
        .clipShape(form)
    }

    private var playlistPille: some View {
        let name: String = (einstellungen.playlistName ?? "").isEmpty ? "Playlist" : (einstellungen.playlistName ?? "")
        return HStack(spacing: 6) {
            Image(systemName: "record.circle")
                .font(.system(size: 9, weight: .medium))
            LobbyBreitenDeckel(breite: 105) {
                Text(name)
                    .font(.marke(11, .bold))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .foregroundColor(Farbe.akzent)
        .padding(.horizontal, 11)
        .frame(height: 27)
        .overlay(Capsule().strokeBorder(Farbe.linie, lineWidth: 1))
    }

    private func pille(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .medium))
            Text(text)
                .font(.marke(11, .bold))
                .lineLimit(1)
        }
        .foregroundColor(Farbe.schrift)
        .padding(.horizontal, 9)
        .frame(height: 27)
        .overlay(Capsule().strokeBorder(Farbe.linie, lineWidth: 1))
        .fixedSize()
    }

    /// Die Namen wie im Browser; was er nicht kennt, heisst dort "Quiz".
    private var modus: String {
        switch spielart {
        case "timeline":          return "Timeline"
        case "higherlower", "hl": return "Higher / Lower"
        case "reverse":           return "Reverse"
        default:                  return "Quiz"
        }
    }
}

/// Gibt dem Inhalt hoechstens `breite` Platz - auch in einer waagrechten
/// ScrollView, wo sonst jeder Text unbegrenzt breit wird (max-w-[45%] truncate).
private struct LobbyBreitenDeckel: Layout {
    let breite: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let kind = subviews.first else { return CGSize.zero }
        let w: CGFloat = min(proposal.width ?? breite, breite)
        return kind.sizeThatFits(ProposedViewSize(width: w, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let kind = subviews.first else { return }
        kind.place(at: CGPoint(x: bounds.minX, y: bounds.midY),
                   anchor: .leading,
                   proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }
}

// MARK: - Freier Platz

/// Ein freier Platz im Raster: gestrichelte Kante weiss 10 %, Grund weiss 1,5 %,
/// pulsiert sanft (50-75 %), um das Symbol laeuft ein Ring nach aussen.
/// Antippen oeffnet die Einladung.
struct FreierPlatz: View {
    var nummer: Int = 0
    var hoehe: CGFloat = 0
    @State private var puls = false

    /// 11 + 40 + 6 + 3 × 15 + 11 - wie im Browser.
    static let hoehe: CGFloat = 113

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        let verzoegerung: Double = Double(nummer) * 0.6
        return VStack(spacing: 6) {
            symbol
            VStack(spacing: 0) {
                Text("OPEN")
                    .font(.marke(10, .bold))
                    .frame(height: 15)
                Text("SLOT")
                    .font(.marke(10, .bold))
                    .frame(height: 15)
                Text("Invite…")
                    .font(.marke(10))
                    .frame(height: 15)
            }
            .foregroundColor(Farbe.gedaempft)
            .lineLimit(1)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: hoehe, alignment: .top)
        .background(form.fill(Color.white.opacity(0.015)))
        .overlay(form.strokeBorder(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
        .contentShape(form)
        .opacity(puls ? 0.75 : 0.5)
        .animation(.easeInOut(duration: 1.25).repeatForever(autoreverses: true).delay(verzoegerung), value: puls)
        .onAppear { puls = true }
    }

    /// Kreis 40 (weiss 4 %) mit Person+, darunter ein Ring, der auf das
    /// Doppelte waechst und dabei verblasst (animate-ping, 2,4 s).
    private var symbol: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .scaleEffect(puls ? 2 : 1)
                .opacity(puls ? 0 : 1)
                .animation(.easeOut(duration: 2.4).repeatForever(autoreverses: false), value: puls)
            Circle()
                .fill(Color.white.opacity(0.04))
            Image(systemName: "person.badge.plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Farbe.gedaempft)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Chat

/// Die Chat-Karte "((•)) LOBBY": Kopf mit Strich, Verlauf (120-200 hoch,
/// scrollt mit), unten Eingabe und runder lila Sendeknopf 36.
private struct LobbyChatKarte: View {
    @EnvironmentObject private var spiel: Spiel
    @State private var nachricht: String = ""
    @State private var inhaltHoehe: CGFloat = 0
    /// Wie im Browser: hoechstens 5 Nachrichten in 4 Sekunden.
    @State private var gesendet: [Date] = []

    var body: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        return VStack(spacing: 0) {
            kopf
            Rectangle().fill(Farbe.linie).frame(height: 1)
            if spiel.chat.isEmpty {
                leer
            } else {
                verlauf
            }
            Rectangle().fill(Farbe.linie).frame(height: 1)
            eingabe
        }
        .padding(1)
        .background(form.fill(Farbe.karte))
        .clipShape(form)
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    private var kopf: some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 10, weight: .medium))
            Text("LOBBY")
                .font(.marke(11, .bold))
                .tracking(1.1)
            Spacer(minLength: 0)
        }
        .foregroundColor(Farbe.gedaempft)
        .frame(height: 17)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var leer: some View {
        VStack(spacing: 6) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(KopfFarbe.leerSymbol)
            Text("Waiting for players…")
                .font(.marke(11))
                .foregroundColor(Farbe.gedaempft)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }

    private var sichtHoehe: CGFloat {
        min(max(inhaltHoehe, 120), 200)
    }

    private var verlauf: some View {
        ScrollViewReader { leser in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(spiel.chat) { z in
                        zeile(z).id(z.id)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    GeometryReader { g in
                        Color.clear
                            .onAppear { inhaltHoehe = g.size.height }
                            .onChange(of: g.size.height) { neu in inhaltHoehe = neu }
                    }
                )
            }
            .frame(height: sichtHoehe)
            .onAppear {
                if let letzte = spiel.chat.last {
                    leser.scrollTo(letzte.id, anchor: .bottom)
                }
            }
            .onChange(of: spiel.chat.count) { _ in
                if let letzte = spiel.chat.last {
                    withAnimation(.easeOut(duration: 0.25)) {
                        leser.scrollTo(letzte.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func zeile(_ z: ChatZeile) -> some View {
        if z.system {
            // Systemzeilen: Regler-Symbol 10, 11 pt, #8d8ba4
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 9, weight: .medium))
                Text(z.text)
                    .font(.marke(11))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundColor(Farbe.gedaempft)
        } else {
            // Bild 20, "Name:" 12 pt fett lila, Text 12 pt
            HStack(alignment: .top, spacing: 8) {
                LobbyAvatar(spieler: absender(z), name: z.nickname, groesse: 20)
                Text(z.nickname + ":")
                    .font(.marke(12, .bold))
                    .foregroundColor(Farbe.akzent)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minHeight: 18)
                Text(z.text)
                    .font(.marke(12))
                    .foregroundColor(Farbe.schrift)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 18)
                Spacer(minLength: 0)
            }
        }
    }

    private func absender(_ z: ChatZeile) -> Spieler? {
        spiel.spieler.first(where: { $0.nickname == z.nickname })
    }

    private var eingabe: some View {
        HStack(spacing: 8) {
            TextField("", text: $nachricht,
                      prompt: Text("Message...").foregroundColor(Farbe.leise))
                .font(.marke(13))
                .foregroundColor(Farbe.schrift)
                .submitLabel(.send)
                .onSubmit { senden() }
                .padding(.horizontal, 8)
                .frame(height: 36)
                .onChange(of: nachricht) { neu in
                    if neu.count > 200 {
                        nachricht = String(neu.prefix(200))
                    }
                }
            Button {
                senden()
            } label: {
                Image(systemName: "paperplane")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Farbe.akzent))
            }
            .buttonStyle(LobbyDruck(gedrueckt: 0.92))
        }
        .padding(10)
    }

    private func senden() {
        let sauber: String = nachricht.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sauber.isEmpty else { return }
        let jetzt: Date = Date()
        let frisch: [Date] = gesendet.filter { jetzt.timeIntervalSince($0) < 4 }
        if frisch.count >= 5 {
            gesendet = frisch
            spiel.meldung = "Slow down a moment"
            return
        }
        gesendet = frisch + [jetzt]
        Spuerbar.tipp()
        spiel.schreiben(sauber)
        nachricht = ""
    }
}

// MARK: - Einladen

/// Das Blatt "Invite players" wie im Browser: von unten, Ecken oben 24,
/// rgba(24,23,39,.98), Kante lila 32 %. QR-Code mit dem Link zur Lobby,
/// der Link zum Kopieren (und Teilen, wie Safari es auf dem iPhone anbietet).
/// Die Freundesliste braucht einen Server-Aufruf, den die App nicht macht -
/// Gaeste sehen deshalb nur den Hinweis, den der Browser ihnen auch zeigt.
private struct EinladeBlatt: View {
    let pin: String
    let gast: Bool
    let schliessen: () -> Void
    @State private var kopiert = false
    @State private var qr: UIImage? = nil

    private var link: String {
        "https://fakester.app/?pin=" + pin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kopf
            VStack(alignment: .leading, spacing: 12) {
                scanKarte
                linkZeile
                if gast {
                    freunde
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 1)
        .padding(.top, 1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(grund)
        .onAppear {
            if qr == nil {
                qr = QRBild.machen(link)
            }
        }
    }

    /// Unten laeuft die Form ueber den Rand hinaus - so bleiben nur die
    /// oberen Ecken rund (UnevenRoundedRectangle gibt es erst ab iOS 17).
    private var grund: some View {
        let form = RoundedRectangle(cornerRadius: 24, style: .circular)
        return ZStack {
            form.fill(KopfFarbe.blatt)
            form.strokeBorder(Farbe.akzent.opacity(0.32), lineWidth: 1)
        }
        .padding(.bottom, -60)
        .ignoresSafeArea(edges: .bottom)
    }

    private var kopf: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Farbe.akzent)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Farbe.akzent.opacity(0.15)))
                VStack(alignment: .leading, spacing: 0) {
                    Text("PIN " + pin)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1)
                        .foregroundColor(Farbe.akzent)
                        .lineLimit(1)
                    Text("Invite players")
                        .font(.marke(18, .heavy))
                        .foregroundColor(Farbe.schrift)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(action: schliessen) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Farbe.gedaempft)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .contentShape(Circle())
            }
            .buttonStyle(LobbyDruck(gedrueckt: 0.92))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    /// QR-Code (92, weisse Flaeche mit Polster 8, Ecken 18) und daneben
    /// "Scan to join" mit Erklaerung.
    private var scanKarte: some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        return HStack(spacing: 12) {
            qrFeld
            VStack(alignment: .leading, spacing: 4) {
                Text("Scan to join")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Farbe.schrift)
                Text("Opens fakester.app and drops them straight into this lobby — no PIN to type.")
                    .font(.system(size: 11))
                    .foregroundColor(Farbe.gedaempft)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .background(form.fill(Color.white.opacity(0.03)))
        .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    @ViewBuilder
    private var qrBild: some View {
        if let bild = qr {
            Image(uiImage: bild)
                .interpolation(.none)
                .resizable()
                .frame(width: 92, height: 92)
        } else {
            Color.clear
                .frame(width: 92, height: 92)
        }
    }

    private var qrFeld: some View {
        qrBild
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 18, style: .circular).fill(Color.white))
    }

    private var linkZeile: some View {
        let form = RoundedRectangle(cornerRadius: 18, style: .circular)
        return HStack(spacing: 8) {
            Text(link)
                .font(.system(size: 12))
                .foregroundColor(KopfFarbe.knopfSchrift)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
                .background(form.fill(KopfFarbe.feld))
                .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))

            Button {
                kopieren()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: kopiert ? "checkmark" : "square.on.square")
                        .font(.system(size: 12, weight: .medium))
                    Text(kopiert ? "Copied" : "Copy")
                        .font(.system(size: 12, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundColor(Color.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(form.fill(Farbe.akzent))
            }
            .buttonStyle(LobbyDruck())

            teilen
        }
    }

    /// Safari auf dem iPhone kann teilen (navigator.share) - der Browser zeigt
    /// dann diesen Knopf neben "Copy".
    @ViewBuilder
    private var teilen: some View {
        if let url = URL(string: link) {
            let form = RoundedRectangle(cornerRadius: 18, style: .circular)
            ShareLink(item: url, message: Text("Join my lobby — PIN " + pin)) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Farbe.schrift)
                    .frame(width: 40, height: 40)
                    .background(form.fill(Color.white.opacity(0.04)))
                    .overlay(form.strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
            }
            .buttonStyle(LobbyDruck())
        }
    }

    private var freunde: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 9, weight: .medium))
                Text("YOUR FRIENDS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1)
                    .lineLimit(1)
            }
            .foregroundColor(Farbe.gedaempft)
            .padding(.top, 4)

            Text("No friends added yet — add someone on the Friends screen, or just send them the link above.")
                .font(.system(size: 11))
                .foregroundColor(Farbe.gedaempft)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
        }
    }

    private func kopieren() {
        UIPasteboard.general.string = link
        Spuerbar.richtig()
        kopiert = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            kopiert = false
        }
    }
}

/// Der QR-Code wie im Browser (Fehlerkorrektur M, #15151f auf weiss, ohne
/// eigene Ruhezone - die macht das weisse Polster drumherum).
private enum QRBild {
    static func machen(_ text: String) -> UIImage? {
        let erzeuger = CIFilter.qrCodeGenerator()
        erzeuger.message = Data(text.utf8)
        erzeuger.correctionLevel = "M"
        guard let roh = erzeuger.outputImage else { return nil }

        let faerben = CIFilter.falseColor()
        faerben.inputImage = roh
        faerben.color0 = CIColor(red: 0x15 / 255.0, green: 0x15 / 255.0, blue: 0x1F / 255.0)
        faerben.color1 = CIColor(red: 1, green: 1, blue: 1)
        guard let bunt = faerben.outputImage else { return nil }

        let kontext = CIContext(options: nil)
        guard let ganz = kontext.createCGImage(bunt, from: bunt.extent) else { return nil }
        let rand: Int = ruhezone(ganz)
        if rand > 0 {
            let ausschnitt = CGRect(x: rand, y: rand, width: ganz.width - 2 * rand, height: ganz.height - 2 * rand)
            if let ohneRand = ganz.cropping(to: ausschnitt) {
                return UIImage(cgImage: ohneRand)
            }
        }
        return UIImage(cgImage: ganz)
    }

    /// Wie breit der weisse Rand ist, den CoreImage mitliefert: Das erste
    /// dunkle Pixel ist die linke obere Ecke des Suchmusters.
    private static func ruhezone(_ bild: CGImage) -> Int {
        let b: Int = bild.width
        let h: Int = bild.height
        guard b > 0, h > 0,
              let ctx = CGContext(data: nil, width: b, height: h, bitsPerComponent: 8, bytesPerRow: b,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return 0 }
        ctx.draw(bild, in: CGRect(x: 0, y: 0, width: b, height: h))
        guard let daten = ctx.data else { return 0 }
        let zeile: Int = ctx.bytesPerRow
        let pixel: UnsafeMutablePointer<UInt8> = daten.bindMemory(to: UInt8.self, capacity: zeile * h)
        for y in 0..<h {
            for x in 0..<b where pixel[y * zeile + x] < 128 {
                return (x == y && x <= 8) ? x : 0
            }
        }
        return 0
    }
}

// MARK: - Bausteine nur fuer die Lobby

/// Leichtes Eindruecken wie whileTap: { scale: .97 } im Browser.
private struct LobbyDruck: ButtonStyle {
    var gedrueckt: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? gedrueckt : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// "Start Game" wie im Browser: 51 hoch, Ecken 16, flaches Lila, weisse
/// 15 pt fett, Schein 0 0 28 rgba(112,0,215,.4) ohne Versatz.
private struct LobbyStartStil: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let form = RoundedRectangle(cornerRadius: 16, style: .circular)
        return configuration.label
            .font(.marke(15, .bold))
            .foregroundColor(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 51)
            .background(form.fill(Farbe.akzent))
            .shadow(color: Farbe.akzentTief.opacity(0.4), radius: 14, x: 0, y: 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Farben, die nur in der Lobby vorkommen (aus den Messwerten im Browser).
private enum KopfFarbe {
    /// Kopf: rgba(7,7,14,.82)
    static let kopf = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.82)
    /// Fuss: rgba(7,7,14,.95)
    static let fuss = Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.95)
    /// Pillen-Leiste: rgba(24,23,39,.9)
    static let leiste = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)
    /// Blatt: rgba(24,23,39,.98)
    static let blatt = Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)
    /// Hinter dem Blatt: rgba(4,4,10,.72)
    static let abdunkeln = Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.72)
    /// Link-Feld: rgba(10,9,20,.6)
    static let feld = Color(.sRGB, red: 10 / 255, green: 9 / 255, blue: 20 / 255, opacity: 0.6)
    /// "Reveal", "Copy", der Link: #b0aed2
    static let knopfSchrift = Color(hex: 0xB0AED2)
    /// Das blasse Funk-Symbol im leeren Chat: #2a2848
    static let leerSymbol = Color(hex: 0x2A2848)
}
