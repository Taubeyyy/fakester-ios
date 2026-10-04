import SwiftUI
import UIKit

/// Die Lobby, nach dem Browser nachgebaut: PIN in vier Kaestchen, die
/// Einstellungen als Pillen, das Spielerraster mit freien Plaetzen und ein
/// Chat, in den man jetzt auch schreiben kann.
struct LobbyAnsicht: View {
    @EnvironmentObject private var spiel: Spiel
    @State private var pinOffen = false
    @State private var nachricht = ""

    /// Vier Spalten wie im Browser. Da passen auch die freien Plaetze hin, und
    /// die sagen mehr als eine Zahl: man sieht, dass noch jemand fehlt.
    private let spalten: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            Kopfzeile(titel: "Lobby", unterzeile: untertitel) { spiel.verlassen() }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PinKarte(pin: spiel.pin, offen: $pinOffen)
                    if let e = spiel.einstellungen {
                        Chips(einstellungen: e, spielart: spiel.spielart)
                    }
                    spielerblock
                    chatkarte
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            startleiste
        }
    }

    private var untertitel: String? {
        spiel.binIchHost ? L("Du bist Gastgeber", "You're the host") : nil
    }

    // MARK: Spieler

    private var spielerblock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("SPIELER (\(spiel.spieler.count))", "PLAYERS (\(spiel.spieler.count))")).etikett()
            LazyVGrid(columns: spalten, spacing: 8) {
                ForEach(spiel.spieler) { s in
                    SpielerKarte(spieler: s,
                                 istHost: s.id.text == spiel.hostId,
                                 binIch: s.id.text == spiel.eigeneId)
                }
                ForEach(0..<freiePlaetze, id: \.self) { _ in FreierPlatz() }
            }
        }
    }

    /// Bis zu acht Plaetze zeigt der Browser. Kommen mehr Leute, verschwinden
    /// die Luecken einfach - niemand soll aus dem Raster fallen.
    private var freiePlaetze: Int {
        max(0, 8 - spiel.spieler.count)
    }

    // MARK: Chat

    private var chatkarte: some View {
        Karte(polster: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Farbe.akzent)
                    Text("LOBBY").etikett()
                }

                if spiel.chat.isEmpty {
                    Text(L("Noch nichts gesagt.", "Nothing said yet."))
                        .font(.marke(13, .medium))
                        .foregroundColor(Farbe.leise)
                } else {
                    ForEach(spiel.chat.suffix(6)) { z in
                        chatzeile(z)
                    }
                }

                // Senden konnte die App laengst - es gab nur kein Feld dafuer.
                HStack(spacing: 8) {
                    Feld(text: $nachricht, platzhalter: L("Nachricht…", "Message…"))
                    sendeknopf
                }
            }
        }
    }

    private var sendeknopf: some View {
        let leer: Bool = nachricht.trimmingCharacters(in: .whitespaces).isEmpty
        return Button {
            senden()
        } label: {
            ZStack {
                Circle().fill(leer ? AnyShapeStyle(Farbe.grund3) : AnyShapeStyle(Farbe.verlauf))
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(leer ? Farbe.leise : Farbe.aufAkzent)
            }
            .frame(width: 46, height: 46)
        }
        .buttonStyle(BubbleDruck())
        .disabled(leer)
    }

    @ViewBuilder
    private func chatzeile(_ z: ChatZeile) -> some View {
        if z.system {
            HStack(spacing: 6) {
                Image(systemName: "arrow.right.circle")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Farbe.leise)
                Text(z.text)
                    .font(.marke(12, .medium))
                    .foregroundColor(Farbe.leise)
                Spacer(minLength: 0)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(z.nickname)
                    .font(.marke(13, .heavy))
                    .foregroundColor(Farbe.akzent)
                Text(z.text)
                    .font(.marke(13, .medium))
                    .foregroundColor(Farbe.schrift)
                Spacer(minLength: 0)
            }
        }
    }

    private func senden() {
        let sauber: String = nachricht.trimmingCharacters(in: .whitespaces)
        guard !sauber.isEmpty else { return }
        Spuerbar.tipp()
        spiel.schreiben(sauber)
        nachricht = ""
    }

    // MARK: Starten

    private var startleiste: some View {
        VStack(spacing: 10) {
            if spiel.binIchHost {
                Button {
                    Spuerbar.sperren()
                    spiel.starten()
                } label: {
                    Label(L("Spiel starten", "Start Game"), systemImage: "play.fill")
                }
                .buttonStyle(Hauptknopf())
            } else {
                Text(L("Warten auf den Gastgeber…", "Waiting for the host…"))
                    .font(.marke(14, .semibold))
                    .foregroundColor(Farbe.gedaempft)
                    .frame(height: 54)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// Die PIN als Kaestchen, zugedeckt bis man sie aufdeckt - genau wie im
/// Browser. Das ist keine Spielerei: die PIN haengt oft an einem Bildschirm,
/// den mehr Leute sehen als mitspielen sollen.
struct PinKarte: View {
    let pin: String
    @Binding var offen: Bool
    @State private var kopiert = false

    var body: some View {
        Karte(polster: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "number")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(Farbe.akzent)
                    Text(L("SPIEL-PIN", "GAME PIN")).etikett()
                }

                HStack(spacing: 8) {
                    ForEach(Array(zeichen.enumerated()), id: \.offset) { _, c in
                        kaestchen(c)
                    }
                }

                HStack(spacing: 8) {
                    kleinerKnopf(offen ? L("Verstecken", "Hide") : L("Aufdecken", "Reveal"),
                                 offen ? "eye.slash" : "eye") {
                        Spuerbar.tipp()
                        withAnimation(.easeOut(duration: 0.18)) { offen.toggle() }
                    }
                    kleinerKnopf(kopiert ? L("Kopiert", "Copied") : L("Kopieren", "Copy"),
                                 kopiert ? "checkmark" : "doc.on.doc") {
                        UIPasteboard.general.string = pin
                        Spuerbar.richtig()
                        kopiert = true
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    /// Der Server vergibt vier Stellen; sollte er je laenger werden, wachsen
    /// die Kaestchen mit, statt die PIN abzuschneiden.
    private var zeichen: [Character] {
        Array(pin.isEmpty ? "----" : pin)
    }

    @ViewBuilder
    private func kaestchen(_ c: Character) -> some View {
        let form = RoundedRectangle(cornerRadius: 12, style: .continuous)
        Text(offen ? String(c) : "●")
            .font(.mono(offen ? 22 : 14))
            .foregroundColor(offen ? Farbe.schrift : Farbe.leise)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(form.fill(Farbe.grund3))
            .overlay(form.strokeBorder(Farbe.linie, lineWidth: 1))
    }

    @ViewBuilder
    private func kleinerKnopf(_ text: String, _ symbol: String, _ aktion: @escaping () -> Void) -> some View {
        Button(action: aktion) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11, weight: .bold))
                Text(text).font(.marke(12, .bold)).lineLimit(1)
            }
            .foregroundColor(Farbe.gedaempft)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(Farbe.grund3))
            .overlay(Capsule().strokeBorder(Farbe.linie, lineWidth: 1))
        }
        .buttonStyle(BubbleDruck())
    }
}

/// Die Einstellungen als kleine Pillen statt als ein langer Satz - im Browser
/// liest man sie so mit einem Blick ab.
struct Chips: View {
    let einstellungen: Einstellungen
    let spielart: String

    var body: some View {
        let spalten: [GridItem] = [GridItem(.adaptive(minimum: 80, maximum: 230), spacing: 7)]
        LazyVGrid(columns: spalten, alignment: .leading, spacing: 7) {
            ForEach(Array(teile.enumerated()), id: \.offset) { _, t in
                HStack(spacing: 5) {
                    Image(systemName: t.0).font(.system(size: 10, weight: .bold))
                    Text(t.1).font(.marke(12, .bold)).lineLimit(1).minimumScaleFactor(0.8)
                }
                .foregroundColor(Farbe.gedaempft)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(Capsule().fill(Farbe.flaeche))
                .overlay(Capsule().strokeBorder(Farbe.linie, lineWidth: 1))
            }
        }
    }

    private var teile: [(String, String)] {
        var raus: [(String, String)] = []
        if let p = einstellungen.playlistName, !p.isEmpty { raus.append(("music.note.list", p)) }
        raus.append(("music.note", "\(einstellungen.songCount)"))
        raus.append(("clock", "\(einstellungen.guessTime)s"))
        raus.append(("questionmark.circle", Benennung.spielart(spielart)))
        if !einstellungen.istMC { raus.append(("keyboard", L("Eintippen", "Type in"))) }
        return raus
    }
}

/// Ein freier Platz im Spielerraster.
struct FreierPlatz: View {
    var body: some View {
        let form = RoundedRectangle(cornerRadius: 14, style: .continuous)
        VStack(spacing: 6) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 15))
                .foregroundColor(Farbe.leise.opacity(0.6))
            Text(L("FREI", "OPEN"))
                .font(.marke(9, .heavy)).tracking(0.6)
                .foregroundColor(Farbe.leise.opacity(0.7))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(form.fill(Color.white.opacity(0.02)))
        .overlay(form.strokeBorder(Farbe.linie, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }
}
