import SwiftUI

/// "Board" vom Startbildschirm: die Bestenliste wie im Browser, mit Reitern
/// fuer XP, Siege, Highscore, Spiele und richtige Antworten. Oeffentlich -
/// Gaeste sehen sie genauso.
struct RanglistenAnsicht: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var schliessen

    @State private var sortierung: String = "xp"
    @State private var eintraege: [Bestenliste.Eintrag] = []
    @State private var laedt = true
    @State private var fehler: String?

    var body: some View {
        VStack(spacing: 0) {
            kopf
            reiter
            ScrollView {
                LazyVStack(spacing: 8) {
                    if let f = fehler {
                        Text(f)
                            .font(.marke(13, .semibold))
                            .foregroundColor(Farbe.schlecht)
                            .padding(.top, 30)
                    } else if laedt && eintraege.isEmpty {
                        ProgressView().tint(Farbe.akzent).padding(.top, 40)
                    } else if eintraege.isEmpty {
                        Text(L("Noch niemand auf der Liste.", "Nobody on the board yet."))
                            .font(.marke(13))
                            .foregroundColor(Farbe.leise)
                            .padding(.top, 40)
                    }
                    ForEach(eintraege) { e in
                        RanglistenZeile(eintrag: e, einheit: einheit, binIch: e.id == api.ich?.id.text)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .refreshable { await laden() }
        }
        .background(Farbe.grund.ignoresSafeArea())
        .task(id: sortierung) { await laden() }
    }

    private var einheit: String {
        Bestenliste.sortierungen.first { $0.id == sortierung }?.einheit ?? ""
    }

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
            Text(L("Rangliste", "Leaderboard"))
                .font(.marke(24, .heavy))
                .foregroundColor(Farbe.schrift)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var reiter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Bestenliste.sortierungen) { s in
                    let an: Bool = s.id == sortierung
                    Button {
                        Spuerbar.tipp()
                        sortierung = s.id
                    } label: {
                        Text(s.name)
                            .font(.marke(12, .semibold))
                            .foregroundColor(an ? Farbe.aufAkzent : Farbe.leise)
                            .padding(.horizontal, 16)
                            .frame(height: 34)
                            .background(Capsule().fill(an ? AnyShapeStyle(Farbe.verlauf) : AnyShapeStyle(Farbe.flaeche)))
                            .overlay(Capsule().strokeBorder(an ? Color.clear : Farbe.linie, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 4)
    }

    @MainActor
    private func laden() async {
        laedt = true
        fehler = nil
        do {
            let b: Bestenliste = try await api.holen("/leaderboard", ["sort": sortierung, "limit": "100"])
            eintraege = b.eintraege
        } catch {
            fehler = error.localizedDescription
            eintraege = []
        }
        laedt = false
    }
}

private struct RanglistenZeile: View {
    let eintrag: Bestenliste.Eintrag
    let einheit: String
    let binIch: Bool

    var body: some View {
        HStack(spacing: 12) {
            platz
            Text(eintrag.name)
                .font(.marke(14, .heavy))
                .foregroundColor(binIch ? Farbe.akzent : Farbe.schrift)
                .lineLimit(1)
            if eintrag.pro {
                Text("PRO")
                    .font(.marke(9, .black))
                    .foregroundColor(Farbe.aufGold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Farbe.verlaufGold))
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(eintrag.wert)")
                    .font(.mono(14))
                    .foregroundColor(eintrag.rang <= 3 ? Farbe.gold : Farbe.schrift)
                Text(einheit)
                    .font(.marke(10, .bold))
                    .foregroundColor(Farbe.leise)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(Glas(radius: 14, kante: binIch ? Farbe.akzent.opacity(0.6) : (eintrag.rang == 1 ? Farbe.gold.opacity(0.5) : Farbe.kante)))
    }

    private var platz: some View {
        let oben: Bool = eintrag.rang <= 3
        return Text("\(eintrag.rang)")
            .font(.mono(13))
            .foregroundColor(oben ? Farbe.aufGold : Farbe.gedaempft)
            .frame(width: 30, height: 30)
            .background(Circle().fill(oben ? AnyShapeStyle(Farbe.verlaufGold) : AnyShapeStyle(Color.white.opacity(0.06))))
    }
}
