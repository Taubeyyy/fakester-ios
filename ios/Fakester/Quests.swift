import SwiftUI

/// Quests wie im Browser: Reiter Daily / Weekly / Milestones, je Quest eine
/// Karte mit Fortschrittsbalken und rechts entweder die Belohnung (noch offen),
/// der Abholknopf (geschafft) oder "Abgeholt". Nur mit Konto.
struct QuestAnsicht: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var schliessen

    @State private var reiter: Int = 0
    @State private var stand: QuestStand?
    @State private var laedt = true
    @State private var fehler: String?
    @State private var holt: String?
    @State private var meldung: String?

    private let reiterNamen: [String] = ["Daily", "Weekly", "Milestones"]

    var body: some View {
        VStack(spacing: 0) {
            kopf
            reiterLeiste
            ScrollView {
                VStack(spacing: 10) {
                    Text("Complete quests to earn Spots. New goals unlock as you play.")
                        .font(.marke(13))
                        .foregroundColor(Farbe.leise)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let f = fehler {
                        Text(f)
                            .font(.marke(13, .semibold))
                            .foregroundColor(Farbe.schlecht)
                            .padding(.top, 20)
                    } else if laedt && stand == nil {
                        ProgressView().tint(Farbe.akzent).padding(.top, 40)
                    } else if liste.isEmpty {
                        Text("Nothing here right now.")
                            .font(.marke(13))
                            .foregroundColor(Farbe.leise)
                            .padding(.top, 40)
                    }
                    ForEach(liste) { q in
                        QuestKarte(quest: q, holtGerade: holt == q.id) {
                            Task { await abholen(q) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .refreshable { await laden() }
        }
        .background(Farbe.grund.ignoresSafeArea())
        .overlay(alignment: .top) {
            if let m = meldung {
                Text(m)
                    .font(.marke(14, .semibold))
                    .foregroundColor(Farbe.schrift)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Glas(radius: 999))
                    .padding(.top, 8)
                    .task(id: m) {
                        try? await Task.sleep(nanoseconds: 2_400_000_000)
                        meldung = nil
                    }
            }
        }
        .task { await laden() }
    }

    private var liste: [QuestEintrag] {
        guard let s = stand else { return [] }
        switch reiter {
        case 1: return s.woechentlich
        case 2: return s.meilensteine
        default: return s.taeglich
        }
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
            Text("Quests")
                .font(.marke(24, .heavy))
                .foregroundColor(Farbe.schrift)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var reiterLeiste: some View {
        HStack(spacing: 0) {
            ForEach(0..<reiterNamen.count, id: \.self) { i in
                let an: Bool = reiter == i
                Button {
                    Spuerbar.tipp()
                    reiter = i
                } label: {
                    VStack(spacing: 0) {
                        Text(reiterNamen[i])
                            .font(.marke(13, .semibold))
                            .foregroundColor(an ? Farbe.schrift : Farbe.leise)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                        Rectangle()
                            .fill(an ? Farbe.akzent : Color.clear)
                            .frame(height: 2)
                    }
                    .background(an ? Farbe.akzent.opacity(0.12) : Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Farbe.flaeche)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Farbe.linie, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    @MainActor
    private func laden() async {
        laedt = true
        fehler = nil
        do {
            let s: QuestStand = try await api.holen("/quests")
            stand = s
        } catch {
            fehler = error.localizedDescription
        }
        laedt = false
    }

    @MainActor
    private func abholen(_ q: QuestEintrag) async {
        guard holt == nil else { return }
        holt = q.id
        defer { holt = nil }
        do {
            let a: Abholung = try await api.senden("/quests/claim", ["questId": q.id])
            if let n = a.newSpots { api.spotsSetzen(n) }
            Spuerbar.richtig()
            meldung = "+\(a.reward) Spots"
            await laden()
        } catch {
            Spuerbar.falsch()
            meldung = error.localizedDescription
        }
    }
}

private struct QuestKarte: View {
    let quest: QuestEintrag
    let holtGerade: Bool
    let abholen: () -> Void

    var body: some View {
        let offen: Bool = quest.fertig && !quest.abgeholt
        let form = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: quest.abgeholt ? "checkmark" : "target")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Farbe.akzent)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Farbe.akzent.opacity(0.16)))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Farbe.akzent.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.marke(14, .heavy))
                        .foregroundColor(Farbe.schrift)
                        .lineLimit(2)
                    Text("\(quest.stand) / \(quest.ziel)")
                        .font(.marke(11))
                        .foregroundColor(Farbe.leise)
                }
                Spacer(minLength: 0)
                rechts
            }
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.06))
                        Capsule().fill(Farbe.verlauf)
                            .frame(width: geo.size.width * CGFloat(quest.anteil))
                    }
                }
                .frame(height: 8)
                Text("\(Int((quest.anteil * 100).rounded()))%")
                    .font(.mono(10))
                    .foregroundColor(quest.stand > 0 ? Farbe.akzent : Farbe.leise)
                    .frame(minWidth: 32, alignment: .trailing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(form.fill(offen ? Color(hex: 0x140E32) : Farbe.flaeche))
        .overlay(form.strokeBorder(offen ? Farbe.akzent.opacity(0.4) : Farbe.linie, lineWidth: 1))
        .opacity(quest.abgeholt ? 0.65 : 1)
    }

    private var name: String {
        if let n = QuestEintrag.namen.first(where: { $0.id == quest.id }) { return n.en }
        return quest.id
    }

    @ViewBuilder
    private var rechts: some View {
        if quest.abgeholt {
            Text("Claimed")
                .font(.marke(10, .bold))
                .foregroundColor(Farbe.akzent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Farbe.akzent.opacity(0.15)))
        } else if quest.fertig {
            Button(action: abholen) {
                HStack(spacing: 3) {
                    Text("+\(quest.belohnung)").font(.marke(12, .bold))
                    Image(systemName: "music.note").font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Farbe.aufAkzent)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Farbe.verlauf))
                .opacity(holtGerade ? 0.6 : 1)
            }
            .buttonStyle(BubbleDruck())
            .disabled(holtGerade)
        } else {
            HStack(spacing: 3) {
                Text("+\(quest.belohnung)").font(.marke(12, .bold))
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
struct TagesBonusBlatt: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var schliessen

    let bonus: TagesBonus
    @State private var holt = false
    @State private var ergebnis: TagesBonusAntwort?
    @State private var fehler: String?

    var body: some View {
        VStack(spacing: 18) {
            Text("DAILY REWARD").etikett()
            Text("Day \(ergebnis?.serie ?? bonus.tag)")
                .font(.marke(34, .heavy))
                .foregroundStyle(Farbe.verlaufHeld)
            HStack(spacing: 10) {
                Lohn(symbol: "music.note", wert: ergebnis?.spots ?? bonus.spots, einheit: "SPOTS", farbe: Farbe.gut)
                if (ergebnis?.xp ?? bonus.xp) > 0 {
                    Lohn(symbol: "star.fill", wert: ergebnis?.xp ?? bonus.xp, einheit: "XP", farbe: Farbe.akzent)
                }
                if (ergebnis?.gold ?? bonus.gold) > 0 {
                    Lohn(symbol: "trophy.fill", wert: ergebnis?.gold ?? bonus.gold, einheit: "GS", farbe: Farbe.gold)
                }
            }
            Text("Miss a day and the streak starts over at day 1.")
                .font(.marke(12))
                .foregroundColor(Farbe.leise)
                .multilineTextAlignment(.center)
            if let f = fehler {
                Text(f).font(.marke(12, .semibold)).foregroundColor(Farbe.schlecht)
            }
            if ergebnis == nil {
                Button {
                    Task { await abholen() }
                } label: {
                    Text(holt ? "…" : "Collect")
                }
                .buttonStyle(Hauptknopf(aus: holt))
                .disabled(holt)
            } else {
                Button("Done") { schliessen() }
                    .buttonStyle(Hauptknopf(farbe: Farbe.kante))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Farbe.grund.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    @MainActor
    private func abholen() async {
        holt = true
        defer { holt = false }
        do {
            let a: TagesBonusAntwort = try await api.senden("/daily-checkin")
            if a.abgeholt {
                ergebnis = a
                Spuerbar.richtig()
                await api.profilAuffrischen()
            } else {
                fehler = "Already collected today."
            }
        } catch {
            fehler = error.localizedDescription
        }
    }
}

private struct Lohn: View {
    let symbol: String
    let wert: Int
    let einheit: String
    let farbe: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(farbe)
            Text("+\(wert)")
                .font(.mono(16))
                .foregroundColor(Farbe.schrift)
            Text(einheit)
                .font(.marke(9, .black))
                .tracking(1)
                .foregroundColor(Farbe.leise)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Glas(radius: 14))
    }
}
