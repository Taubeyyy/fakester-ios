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

    var body: some View {
        ZStack {
            Buehne()

            switch spiel.lage {
            case .getrennt:
                if api.ausweis == nil { AnmeldeAnsicht() } else { DaheimAnsicht() }
            case .verbinde:
                Warten(text: "Verbinde…")
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
        .animation(.easeInOut(duration: 0.22), value: spiel.lage)
        // Der Server redet mit kurzen Hinweisen ("Game not found!"), und die
        // gehen sonst unter.
        .overlay(alignment: .top) { Durchsage() }
        .alert("Rausgeflogen", isPresented: .constant(spiel.rauswurf != nil)) {
            Button("Ok") { spiel.verlassen() }
        } message: {
            Text(rauswurfText)
        }
        .task {
            await api.profilAuffrischen()
        }
        // Schuetteln = Feedback an den Entwickler, egal wo
        .onReceive(NotificationCenter.default.publisher(for: .geschuettelt)) { _ in rueckmeldung = true }
        .sheet(isPresented: $rueckmeldung) {
            RueckmeldungsBlatt(bildschirm: "\(spiel.lage)")
        }
    }

    private var rauswurfText: String {
        guard let r = spiel.rauswurf else { return "" }
        var zeilen: [String] = []
        if r.banned { zeilen.append("Du bist gesperrt.") }
        if let g = r.reason, !g.isEmpty { zeilen.append(g) }
        if let m = r.minutesLeft { zeilen.append("Noch \(m) Minuten.") }
        return zeilen.isEmpty ? "Der Gastgeber hat dich entfernt." : zeilen.joined(separator: "\n")
    }
}

struct Warten: View {
    let text: String
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Farbe.akzent)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
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
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Farbe.schrift)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(Farbe.flaeche, in: Capsule())
                .overlay(Capsule().strokeBorder(Farbe.kante, lineWidth: 1))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(nanoseconds: 2_800_000_000)
                    withAnimation { spiel.meldung = nil }
                }
        }
    }
}
