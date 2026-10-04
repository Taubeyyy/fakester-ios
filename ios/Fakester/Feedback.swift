import SwiftUI
import UIKit

// Feedback: shake the phone (or tap "Feedback" on the home screen) -> a short text goes to the
// developer's server. It lands in a list there; the developer decides what gets implemented.
// No account needed, the server rate-limits (5 per hour).

extension Notification.Name {
    static let deviceShaken = Notification.Name("deviceShaken")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceShaken, object: nil)
        }
    }
}

enum Feedback {
    static let goal = URL(string: "https://dopa.taubey.com/api/hub/feedback/fakester")!

    struct RequestError: LocalizedError {
        let text: String
        var errorDescription: String? { text }
    }

    static func transmit(text: String, currentScreen: String) async throws {
        struct RequestBody: Encodable { let text: String; let screen: String; let build: String; let device: String }
        struct Answer: Decodable { let error: String? }
        var request = URLRequest(url: goal)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let deviceInfo = "\(UIDevice.current.model) iOS \(UIDevice.current.systemVersion)"
        request.httpBody = try JSONEncoder().encode(RequestBody(text: text, screen: currentScreen, build: build, device: deviceInfo))
        let (bytes, answer) = try await URLSession.shared.data(for: request)
        let status = (answer as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let errorMessage = try? JSONDecoder().decode(Answer.self, from: bytes)
            throw RequestError(text: errorMessage?.error ?? "Didn't work right now (\(status)).")
        }
    }
}

/// The sheet for writing feedback.
struct FeedbackSheet: View {
    let currentScreen: String
    @Environment(\.dismiss) private var close
    @State private var text = ""
    @State private var sending = false
    @State private var errorMessage: String?
    @State private var finished = false
    @FocusState private var focus: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("What's broken, what's missing, what's annoying? Short is fine.")
                    .font(.brand(14))
                    .foregroundColor(Palette.subdued)

                TextEditor(text: $text)
                    .focused($focus)
                    .scrollContentBackground(.hidden)
                    .font(.brand(16))
                    .foregroundColor(Palette.foreground)
                    .padding(10)
                    .frame(minHeight: 160)
                    .background(Palette.muted, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.rim, lineWidth: 1))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.brand(13))
                        .foregroundColor(Palette.bad)
                }

                Button(finished ? "Thanks!" : (sending ? "Sending…" : "Send")) {
                    Task { await submit() }
                }
                .buttonStyle(PrimaryButtonStyle(hue: finished ? Palette.good : Palette.accent,
                                        dimmed: text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || sending))
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || sending || finished)

                Text("Goes straight to the developer. No name, just the screen and app version.")
                    .font(.brand(12))
                    .foregroundColor(Palette.subdued)
                Spacer()
            }
            .padding(20)
            .background(Palette.base.ignoresSafeArea())
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() } }
            }
            .onAppear { focus = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func submit() async {
        sending = true
        errorMessage = nil
        defer { sending = false }
        do {
            try await Feedback.transmit(text: text.trimmingCharacters(in: .whitespacesAndNewlines), currentScreen: currentScreen)
            Haptics.tap()
            withAnimation { finished = true }
            try? await Task.sleep(nanoseconds: 900_000_000)
            close()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
