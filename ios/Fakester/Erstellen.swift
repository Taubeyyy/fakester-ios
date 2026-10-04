import SwiftUI

/// "Create Game" wie im Browser: 1 Playlist, 2 Modus, 3 Einstellungen, unten
/// "Privat erstellen" bzw. "Öffentlich erstellen".
///
/// Modus gibt es in der App nur einen - Quiz. Timeline und Higher/Lower haben
/// eigene Rundenbildschirme, die die App noch nicht kennt; sie anzubieten hiesse,
/// Spieler in eine Runde zu schicken, die sie nicht spielen koennen.
struct ErstellenAnsicht: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel
    @Environment(\.dismiss) private var schliessen

    @State private var vorgabe = SpielVorgabe()
    @State private var empfohlen: [PlaylistEintrag] = []
    @State private var link = ""
    @State private var sucht = false
    @State private var fehler: String?

    var body: some View {
        VStack(spacing: 0) {
            kopf
            ScrollView {
                VStack(spacing: 14) {
                    playlistKarte
                    modusKarte
                    einstellungsKarte
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            fuss
        }
        .background(Farbe.grund.ignoresSafeArea())
        .task { await empfohleneLaden() }
    }

    // MARK: Kopf

    private var kopf: some View {
        HStack(spacing: 10) {
            Button {
                schliessen()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Farbe.schrift)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(Farbe.flaeche))
                    .overlay(Circle().strokeBorder(Farbe.kante, lineWidth: 1))
            }
            Text("Create Game")
                .font(.marke(24, .heavy))
                .foregroundColor(Farbe.schrift)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: 1 Playlist

    private var playlistKarte: some View {
        Karte(polster: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Schritt(nummer: 1, titel: "Playlist", pflicht: true)
                Text("Add a Spotify or YouTube playlist.")
                    .font(.marke(12))
                    .foregroundColor(Farbe.leise)

                HStack(spacing: 8) {
                    Feld(text: $link, platzhalter: "Paste a Spotify or YouTube link…")
                    Button {
                        Task { await linkPruefen() }
                    } label: {
                        Text(sucht ? "…" : "Add")
                            .font(.marke(13, .heavy))
                            .foregroundColor(Farbe.aufAkzent)
                            .padding(.horizontal, 14)
                            .frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Farbe.verlauf))
                    }
                    .disabled(sucht || link.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if let f = fehler {
                    Text(f)
                        .font(.marke(12, .semibold))
                        .foregroundColor(Farbe.schlecht)
                }

                if let p = vorgabe.playlist {
                    PlaylistZeile(eintrag: p, gewaehlt: true) {
                        vorgabe.playlist = nil
                    }
                }

                let andere: [PlaylistEintrag] = empfohlen.filter { $0.id != vorgabe.playlist?.id }
                if !andere.isEmpty {
                    Text("FEATURED").etikett()
                    ForEach(andere) { e in
                        PlaylistZeile(eintrag: e, gewaehlt: false) {
                            Spuerbar.tipp()
                            vorgabe.playlist = e
                        }
                    }
                }
            }
        }
    }

    // MARK: 2 Modus

    private var modusKarte: some View {
        Karte(polster: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Schritt(nummer: 2, titel: "Mode", pflicht: false)
                HStack(spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Farbe.akzent)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Farbe.akzent.opacity(0.18)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quiz").font(.marke(14, .heavy)).foregroundColor(Farbe.schrift)
                        Text("Guess title, artist, year")
                            .font(.marke(11)).foregroundColor(Farbe.leise)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Farbe.akzent.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Farbe.akzent.opacity(0.5), lineWidth: 1))
                Text("Timeline and Higher/Lower are browser-only for now.")
                    .font(.marke(11))
                    .foregroundColor(Farbe.leise)
            }
        }
    }

    // MARK: 3 Einstellungen

    private var einstellungsKarte: some View {
        Karte(polster: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Schritt(nummer: 3, titel: "Settings", pflicht: false)
                    Spacer(minLength: 0)
                    Button("Reset") {
                        Spuerbar.tipp()
                        let p: PlaylistEintrag? = vorgabe.playlist
                        vorgabe = SpielVorgabe()
                        vorgabe.playlist = p
                    }
                    .font(.marke(11, .heavy))
                    .foregroundColor(Farbe.leise)
                }
                ZahlWahl(titel: "SONGS", werte: SpielVorgabe.songWahl, einheit: "", wahl: $vorgabe.songs)
                ZahlWahl(titel: "GUESS TIME", werte: SpielVorgabe.zeitWahl, einheit: "s", wahl: $vorgabe.rateZeit)
                rateArten
                antwortArt
                ZahlWahl(titel: "BREAK BETWEEN ROUNDS", werte: SpielVorgabe.pausenWahl, einheit: "s", wahl: $vorgabe.pause)
                Schalter(titel: "Album cover",
                         hinweis: "show the artwork while guessing",
                         an: $vorgabe.cover)
                Schalter(titel: "Speed bonus",
                         hinweis: "extra points for answering fast — only if everything was right",
                         an: $vorgabe.tempoBonus)
                Schalter(titel: "Streak bonus",
                         hinweis: "extra points for several fully correct answers in a row",
                         an: $vorgabe.serienBonus)
                Schalter(titel: "Sneaky Mode",
                         hinweis: "no right/wrong until the very end",
                         an: $vorgabe.sneaky)
            }
        }
    }

    private var rateArten: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WHAT TO GUESS?").etikett()
            HStack(spacing: 8) {
                Umschalter(text: "Title", an: $vorgabe.titel)
                Umschalter(text: "Artist", an: $vorgabe.interpret)
                Umschalter(text: "Year", an: $vorgabe.jahr)
            }
        }
    }

    private var antwortArt: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANSWER TYPE").etikett()
            HStack(spacing: 8) {
                Wahlpille(text: "Multiple choice", an: !vorgabe.freitext) { vorgabe.freitext = false }
                Wahlpille(text: "Free text", an: vorgabe.freitext) { vorgabe.freitext = true }
            }
        }
    }

    // MARK: Fuss

    private var fuss: some View {
        VStack(spacing: 8) {
            if vorgabe.playlist == nil {
                Text("Add a playlist to create a lobby")
                    .font(.marke(12, .semibold))
                    .foregroundColor(Farbe.leise)
            }
            HStack(spacing: 10) {
                Button {
                    los(oeffentlich: false)
                } label: {
                    Label("Private", systemImage: "lock.fill")
                }
                .buttonStyle(Hauptknopf(aus: vorgabe.playlist == nil))
                .disabled(vorgabe.playlist == nil)

                Button {
                    los(oeffentlich: true)
                } label: {
                    Label("Public", systemImage: "globe")
                }
                .buttonStyle(Hauptknopf(farbe: Farbe.kante, aus: vorgabe.playlist == nil))
                .disabled(vorgabe.playlist == nil)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    // MARK: Ablauf

    @MainActor
    private func los(oeffentlich: Bool) {
        var v: SpielVorgabe = vorgabe
        v.oeffentlich = oeffentlich
        guard let nutzlast = v.nutzlast(), let wer = api.ausweis else { return }
        Spuerbar.sperren()
        schliessen()
        spiel.erstellen(nutzlast, als: wer)
    }

    @MainActor
    private func empfohleneLaden() async {
        if let e: EmpfohleneListen = try? await api.holen("/playlists/featured") {
            empfohlen = e.eintraege
            if vorgabe.playlist == nil, let erste = e.eintraege.first { vorgabe.playlist = erste }
        }
    }

    @MainActor
    private func linkPruefen() async {
        let url: String = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        sucht = true
        fehler = nil
        defer { sucht = false }
        do {
            let info: PlaylistInfo = try await api.holen("/playlist/info", ["url": url])
            vorgabe.playlist = info.eintrag
            link = ""
            Spuerbar.richtig()
        } catch {
            fehler = error.localizedDescription
            Spuerbar.falsch()
        }
    }
}

// MARK: - Bausteine

/// Die nummerierte Ueberschrift einer Karte, wie im Browser.
private struct Schritt: View {
    let nummer: Int
    let titel: String
    let pflicht: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("\(nummer)")
                .font(.marke(10, .black))
                .foregroundColor(Farbe.aufAkzent)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Farbe.verlauf))
            Text(titel)
                .font(.marke(15, .heavy))
                .foregroundColor(Farbe.schrift)
            Spacer(minLength: 0)
            if pflicht {
                Text("REQUIRED")
                    .font(.marke(9, .black))
                    .foregroundColor(Farbe.schlecht)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Farbe.schlecht.opacity(0.15)))
            }
        }
    }
}

private struct PlaylistZeile: View {
    let eintrag: PlaylistEintrag
    let gewaehlt: Bool
    let aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            HStack(spacing: 10) {
                bild
                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.name)
                        .font(.marke(13, .semibold))
                        .foregroundColor(Farbe.schrift)
                        .lineLimit(1)
                    Text(eintrag.quelle == "youtube" ? "YouTube" : "Spotify")
                        .font(.marke(10))
                        .foregroundColor(Farbe.leise)
                }
                Spacer(minLength: 0)
                Image(systemName: gewaehlt ? "xmark" : "plus")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(gewaehlt ? Farbe.aufAkzent : Farbe.leise)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(gewaehlt ? Farbe.akzent : Color.white.opacity(0.08)))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(gewaehlt ? Farbe.akzent.opacity(0.10) : Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(gewaehlt ? Farbe.akzent.opacity(0.4) : Farbe.linie, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var bild: some View {
        let form = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let a = eintrag.bild, let url = URL(string: a) {
            AsyncImage(url: url) { b in
                b.resizable().scaledToFill()
            } placeholder: {
                form.fill(Farbe.grund3)
            }
            .frame(width: 34, height: 34)
            .clipShape(form)
        } else {
            Image(systemName: "music.note.list")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Farbe.gut)
                .frame(width: 34, height: 34)
                .background(form.fill(Farbe.gut.opacity(0.13)))
        }
    }
}

/// Eine Reihe fester Werte zum Antippen (SONGS 5 10 15 20).
private struct ZahlWahl: View {
    let titel: String
    let werte: [Int]
    let einheit: String
    @Binding var wahl: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titel).etikett()
            HStack(spacing: 8) {
                ForEach(werte, id: \.self) { w in
                    Wahlpille(text: "\(w)\(einheit)", an: wahl == w) { wahl = w }
                }
            }
        }
    }
}

private struct Wahlpille: View {
    let text: String
    let an: Bool
    let aktion: () -> Void

    var body: some View {
        Button {
            Spuerbar.tipp()
            aktion()
        } label: {
            Text(text)
                .font(.marke(13, .heavy))
                .foregroundColor(an ? Farbe.aufAkzent : Farbe.gedaempft)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(an ? AnyShapeStyle(Farbe.verlauf) : AnyShapeStyle(Color.white.opacity(0.04))))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(an ? Color.clear : Farbe.linie, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct Umschalter: View {
    let text: String
    @Binding var an: Bool

    var body: some View {
        Wahlpille(text: text, an: an) { an.toggle() }
    }
}

private struct Schalter: View {
    let titel: String
    let hinweis: String
    @Binding var an: Bool

    var body: some View {
        Toggle(isOn: $an) {
            VStack(alignment: .leading, spacing: 2) {
                Text(titel)
                    .font(.marke(14, .semibold))
                    .foregroundColor(Farbe.schrift)
                Text(hinweis)
                    .font(.marke(11))
                    .foregroundColor(Farbe.leise)
            }
        }
        .tint(Farbe.akzent)
    }
}
