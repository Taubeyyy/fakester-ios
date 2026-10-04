import SwiftUI

@main
struct FakesterApp: App {
    @StateObject private var api = Api.shared
    @StateObject private var spiel = Spiel()

    var body: some Scene {
        WindowGroup {
            Wurzel()
                .environmentObject(api)
                .environmentObject(spiel)
                .preferredColorScheme(.dark)
                .tint(Farbe.akzent)
        }
    }
}

/// Entscheidet, welcher Bildschirm dran ist. Die Lage kommt vom Server - die
/// App haelt keine eigene Meinung darueber, in welchem Teil des Spiels man ist.
struct Wurzel: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var spiel: Spiel
    @State private var rueckmeldung = false
    @AppStorage(Sprache.schluessel) private var sprache: String = ""

    var body: some View {
        ZStack {
            Buehne()
            // .id: nach dem Sprachwechsel alles neu bauen, sonst bleiben
            // Ansichten mit den alten Texten stehen.
            bildschirm.id(sprache)
        }
        .animation(.easeInOut(duration: 0.22), value: spiel.lage)
        // Der Server redet mit kurzen Hinweisen ("Game not found!"), und die
        // gehen sonst unter.
        .overlay(alignment: .top) { Durchsage() }
        .alert(L("Rausgeflogen", "Kicked"), isPresented: .constant(spiel.rauswurf != nil)) {
            Button("Ok") { spiel.verlassen() }
        } message: {
            Text(rauswurfText)
        }
        .task {
            #if DEBUG
            Vorschau.abspielen(spiel)
            #endif
            await api.profilAuffrischen()
            await Aktualisierung.shared.pruefen()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await Aktualisierung.shared.pruefen() }
        }
        // Schuetteln = Feedback an den Entwickler, egal wo
        .onReceive(NotificationCenter.default.publisher(for: .geschuettelt)) { _ in rueckmeldung = true }
        .sheet(isPresented: $rueckmeldung) {
            RueckmeldungsBlatt(bildschirm: "\(spiel.lage)")
        }
    }

    @ViewBuilder
    private var bildschirm: some View {
        #if DEBUG
        if Vorschau.szene == "erstellen" {
            ErstellenAnsicht()
        } else if Vorschau.szene == "rangliste" {
            RanglistenAnsicht()
        } else {
            spielBildschirm
        }
        #else
        spielBildschirm
        #endif
    }

    @ViewBuilder
    private var spielBildschirm: some View {
        switch spiel.lage {
        case .getrennt:
            if api.ausweis == nil { AnmeldeAnsicht() } else { DaheimAnsicht() }
        case .verbinde:
            Warten(text: L("Verbinde…", "Connecting…"))
        case .lobby:
            LobbyAnsicht()
        case .laedt:
            LadeAnsicht()
        case .runde:
            RundenAnsicht()
        case .aufloesung:
            AufloesungAnsicht()
        case .ende:
            EndeAnsicht()
        }
    }

    private var rauswurfText: String {
        guard let r = spiel.rauswurf else { return "" }
        var zeilen: [String] = []
        if r.banned { zeilen.append(L("Du bist gesperrt.", "You are banned.")) }
        if let g = r.reason, !g.isEmpty { zeilen.append(g) }
        if let m = r.minutesLeft { zeilen.append(L("Noch \(m) Minuten.", "\(m) minutes left.")) }
        return zeilen.isEmpty ? L("Der Gastgeber hat dich entfernt.", "The host removed you.") : zeilen.joined(separator: "\n")
    }
}

struct Warten: View {
    let text: String
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Farbe.akzent)
            Text(text)
                .font(.marke(15, .medium))
                .foregroundColor(Farbe.gedaempft)
        }
    }
}

/// Kurzer Hinweis oben, der von selbst wieder geht.
struct Durchsage: View {
    @EnvironmentObject private var spiel: Spiel

    var body: some View {
        if let text = spiel.meldung {
            Text(text)
                .font(.marke(14, .semibold))
                .foregroundColor(Farbe.schrift)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Glas(radius: 999))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(nanoseconds: 2_800_000_000)
                    withAnimation { spiel.meldung = nil }
                }
        }
    }
}
