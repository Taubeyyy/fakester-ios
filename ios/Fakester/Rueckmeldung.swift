import SwiftUI
import UIKit

// Rueckmeldung: Handy schuetteln (oder "Feedback" auf dem Startbildschirm) -> kurzer Text an den
// Server des Entwicklers. Dort landet er in einer Liste; was davon umgesetzt wird, entscheidet der
// Entwickler. Kein Konto noetig, der Server drosselt (5 pro Stunde).

extension Notification.Name {
    static let geschuettelt = Notification.Name("geschuettelt")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .geschuettelt, object: nil)
        }
    }
}

enum Rueckmeldung {
    static let ziel = URL(string: "https://dopa.taubey.com/api/hub/feedback/fakester")!

    struct Fehler: LocalizedError {
        let text: String
        var errorDescription: String? { text }
    }

    static func senden(text: String, bildschirm: String) async throws {
        struct Koerper: Encodable { let text: String; let screen: String; let build: String; let device: String }
        struct Antwort: Decodable { let error: String? }
        var anfrage = URLRequest(url: ziel)
        anfrage.httpMethod = "POST"
        anfrage.timeoutInterval = 20
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let geraet = "\(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)"
        anfrage.httpBody = try JSONEncoder().encode(Koerper(text: text, screen: bildschirm, build: build, device: geraet))
        let (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        let status = (antwort as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let fehler = try? JSONDecoder().decode(Antwort.self, from: daten)
            throw Fehler(text: fehler?.error ?? L("Ging gerade nicht (\(status)).", "Didn't work right now (\(status))."))
        }
    }
}

/// Das Fenster zum Schreiben.
struct RueckmeldungsBlatt: View {
    let bildschirm: String
    @Environment(\.dismiss) private var schliessen
    @State private var text = ""
    @State private var sendet = false
    @State private var fehler: String?
    @State private var fertig = false
    @FocusState private var fokus: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text(L("Was ist kaputt, was fehlt, was nervt? Kurz reicht.",
                       "What's broken, what's missing, what's annoying? Short is fine."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(Farbe.gedaempft)

                TextEditor(text: $text)
                    .focused($fokus)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(Farbe.schrift)
                    .padding(10)
                    .frame(minHeight: 160)
                    .background(Farbe.flaeche, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Farbe.kante, lineWidth: 1))

                if let fehler {
                    Text(fehler)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(Farbe.schlecht)
                }

                Button(fertig ? L("Danke!", "Thanks!") : (sendet ? L("Sendet…", "Sending…") : L("Abschicken", "Send"))) {
                    Task { await abschicken() }
                }
                .buttonStyle(Hauptknopf(farbe: fertig ? Farbe.gut : Farbe.akzent,
                                        aus: text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || sendet))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || sendet || fertig)

                Text(L("Geht direkt an den Entwickler. Ohne Namen, nur mit Bildschirm und App-Version.",
                       "Goes straight to the developer. No name, just the screen and app version."))
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(Farbe.gedaempft)
                Spacer()
            }
            .padding(20)
            .background(Farbe.grund.ignoresSafeArea())
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Abbrechen", "Cancel")) { schliessen() } }
            }
            .onAppear { fokus = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func abschicken() async {
        sendet = true
        fehler = nil
        defer { sendet = false }
        do {
            try await Rueckmeldung.senden(text: text.trimmingCharacters(in: .whitespacesAndNewlines), bildschirm: bildschirm)
            Spuerbar.tipp()
            withAnimation { fertig = true }
            try? await Task.sleep(nanoseconds: 900_000_000)
            schliessen()
        } catch {
            fehler = error.localizedDescription
        }
    }
}
