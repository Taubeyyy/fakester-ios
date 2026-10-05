import SwiftUI

/// "Browse public lobbies" inside the join dialog, as in the browser (`J3`):
/// refreshed every 5 s, one row per lobby (mode tile, playlist, host · mode,
/// players/max, Join or Full), "Refresh" and - with more than one lobby -
/// "Quick join" for the fullest one. The app only plays Quiz, so lobbies in
/// other modes show "Web" instead of Join.
struct PublicLobbyList: View {
    @EnvironmentObject private var api: Api
    let join: (String) -> Void

    @State private var lobbies: [PublicLobby]?
    @State private var refreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
            footer
        }
        .task {
            while !Task.isCancelled {
                await load(quietly: lobbies != nil)
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let list = lobbies {
            if list.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 6) {
                        ForEach(list) { lobby in
                            PublicLobbyRow(lobby: lobby, join: { join(lobby.pin) })
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        } else {
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .circular)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 64)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 18))
                .foregroundColor(Color(hex: 0x2A2848))
            Text("No public lobbies right now")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Palette.subdued)
            Text("Create one and pick Public — it shows up here for everyone.")
                .font(.system(size: 11))
                .foregroundColor(Palette.subdued)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                Task { await load(quietly: false) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                    Text(refreshing ? "Refreshing…" : "Refresh")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(Palette.subdued)
            }
            .buttonStyle(.plain)
            .disabled(refreshing)
            Spacer(minLength: 0)
            if let best = quickJoinTarget {
                Button {
                    join(best.pin)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill").font(.system(size: 10))
                        Text("Quick join").font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(Palette.accent)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Capsule().fill(Palette.accent.opacity(0.15)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The fullest lobby the app can play and still join - only offered with more than one.
    private var quickJoinTarget: PublicLobby? {
        guard let list = lobbies, list.count > 1 else { return nil }
        let open: [PublicLobby] = list.filter { $0.appCanPlay && !$0.isFull }
        return open.max { a, b in a.players < b.players }
    }

    @MainActor
    private func load(quietly: Bool) async {
        if !quietly { refreshing = true }
        defer { refreshing = false }
        if let answer: PublicLobbies = try? await api.fetch("/lobbies/public") {
            lobbies = answer.lobbies
        } else if lobbies == nil {
            lobbies = []
        }
    }
}

/// One lobby: 32 tile with the mode icon, playlist name 12 bold, "host · mode"
/// 10 grey, "2/8" (red when full), Join / Full / Web.
private struct PublicLobbyRow: View {
    let lobby: PublicLobby
    let join: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .circular)
        HStack(spacing: 10) {
            Image(systemName: modeSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(modeTint)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .circular).fill(modeTint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(lobby.playlistName ?? "No playlist yet")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Palette.foreground)
                    .lineLimit(1)
                Text(lobby.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(Palette.subdued)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("\(lobby.players)/\(lobby.maxPlayers)")
                .font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundColor(lobby.isFull ? Palette.bad : Color(hex: 0xB0AED2))
            joinButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(shape.fill(Color.white.opacity(0.03)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
    }

    private var joinButton: some View {
        let usable: Bool = lobby.appCanPlay && !lobby.isFull
        let label: String = lobby.isFull ? "Full" : (lobby.appCanPlay ? "Join" : "Web")
        return Button(action: { if usable { join() } }) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(usable ? Color.white : Palette.subdued)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: 10, style: .circular)
                    .fill(usable ? Palette.accent : Color.white.opacity(0.05)))
        }
        .buttonStyle(.plain)
        .disabled(!usable)
        .accessibilityLabel(Text(usable ? "Join \(lobby.playlistName ?? "lobby")" : label))
    }

    private var modeSymbol: String {
        switch lobby.mode {
        case "timeline": return "calendar"
        case "higherlower": return "chevron.up.chevron.down"
        case "reverse": return "arrow.uturn.left"
        default: return "questionmark.circle"
        }
    }

    private var modeTint: Color {
        switch lobby.mode {
        case "timeline": return Palette.good
        case "higherlower": return Palette.gold
        case "reverse": return Color(hex: 0xF472B6)
        default: return Palette.accent
        }
    }
}
