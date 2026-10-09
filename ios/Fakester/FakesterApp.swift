import SwiftUI

@main
struct FakesterApp: App {
    @StateObject private var api = Api.shared
    @StateObject private var game = Game()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(api)
                .environmentObject(game)
                .preferredColorScheme(.dark)
        }
    }
}

/// Decides which screen is up. The state comes from the server - the app has
/// no opinion of its own about which part of the game you are in.
struct RootView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game
    @ObservedObject private var look = CosmeticLook.shared
    @State private var feedbackOpen = false

    var body: some View {
        ZStack {
            Backdrop()
            currentScreen
        }
        // A new accent or background rebuilds the screens in the new colours.
        .id(look.version)
        .tint(Palette.accent)
        .animation(.easeInOut(duration: 0.22), value: game.currentPhase)
        // The server talks in short notices ("Game not found!"), which would
        // otherwise get lost.
        .overlay(alignment: .top) { ToastBanner() }
        .overlay(alignment: .top) { InvitationBanner() }
        .alert("Kicked", isPresented: .constant(game.kick != nil)) {
            Button("Ok") { game.leave() }
        } message: {
            Text(kickText)
        }
        .task {
            #if DEBUG
            ScreenshotScene.run(game)
            #endif
            await api.refreshProfile()
            await look.sync(api)
            if game.currentPhase == .disconnected { look.commit() }
            await Updater.shared.checkForUpdate()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await Updater.shared.checkForUpdate() }
        }
        // Shake = feedback to the developer, from anywhere
        .onReceive(NotificationCenter.default.publisher(for: .deviceShaken)) { _ in feedbackOpen = true }
        .sheet(isPresented: $feedbackOpen) {
            FeedbackSheet(currentScreen: "\(game.currentPhase)")
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        #if DEBUG
        if ScreenshotScene.sceneName == "create" {
            CreateGameView()
        } else if ScreenshotScene.sceneName == "leaderboard" {
            LeaderboardView()
        } else if ScreenshotScene.sceneName == "stats" {
            StatsView()
        } else if ScreenshotScene.sceneName == "settings" {
            SettingsView()
        } else if ScreenshotScene.sceneName == "shop" {
            ShopView()
        } else if ScreenshotScene.sceneName == "style" {
            StyleView()
        } else if ScreenshotScene.sceneName == "path" {
            PathView()
        } else if ScreenshotScene.sceneName == "quests" {
            QuestsView()
        } else if ScreenshotScene.sceneName == "awards" {
            QuestsView(initialTab: "Awards")
        } else if ScreenshotScene.sceneName == "friends" {
            FriendsView()
        } else if ScreenshotScene.sceneName == "playlists" {
            PlaylistsView()
        } else if ScreenshotScene.sceneName == "daily" {
            DailyView()
        } else if let bonus = ScreenshotScene.sampleBonus {
            HomeView()
                .sheet(isPresented: .constant(true)) { DailyBonusSheet(bonus: bonus) }
        } else {
            gameScreen
        }
        #else
        gameScreen
        #endif
    }

    @ViewBuilder
    private var gameScreen: some View {
        switch game.currentPhase {
        case .disconnected:
            if api.identity == nil { LoginView() } else { HomeView() }
        case .connecting:
            WaitingView(text: "Connecting…")
        case .lobby:
            LobbyView()
        case .loading:
            LoadingView()
        case .activeRound:
            RoundView()
        case .reveal:
            RevealView()
        case .end:
            GameOverView()
        }
    }

    private var kickText: String {
        guard let r = game.kick else { return "" }
        var lines: [String] = []
        if r.banned { lines.append("You are banned.") }
        if let g = r.reason, !g.isEmpty { lines.append(g) }
        if let m = r.minutesLeft { lines.append("\(m) minutes left.") }
        return lines.isEmpty ? "The host removed you." : lines.joined(separator: "\n")
    }
}

struct WaitingView: View {
    let text: String
    var body: some View {
        VStack(spacing: 14) {
            ProgressView().tint(Palette.accent)
            Text(text)
                .font(.brand(15, .medium))
                .foregroundColor(Palette.subdued)
        }
    }
}

/// Short notice at the top that goes away by itself.
struct ToastBanner: View {
    @EnvironmentObject private var game: Game

    var body: some View {
        if let text = game.notice {
            Text(text)
                .font(.brand(14, .semibold))
                .foregroundColor(Palette.foreground)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(GlassPanel(radius: 999))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(nanoseconds: 2_800_000_000)
                    withAnimation { game.notice = nil }
                }
        }
    }
}

/// "Ana invited you to a game." with Join / Not now, for 20 seconds - the
/// browser's `timer-confirm` toast for `friend-invite`. Joining leaves the
/// current lobby first, like the browser does.
struct InvitationBanner: View {
    @EnvironmentObject private var game: Game
    @EnvironmentObject private var api: Api

    var body: some View {
        if let invite = game.invitation {
            VStack(alignment: .leading, spacing: 10) {
                Text("\(invite.from) invited you to a game.")
                    .font(.brand(14, .semibold))
                    .foregroundColor(Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button {
                        withAnimation { game.invitation = nil }
                    } label: {
                        Text("Not now")
                            .font(.brand(13, .bold))
                            .foregroundColor(Palette.subdued)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                    Button {
                        accept(invite)
                    } label: {
                        Text("Join")
                            .font(.brand(13, .bold))
                            .foregroundColor(Palette.onAccent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                            .background(Capsule().fill(Palette.accent))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(GlassPanel(radius: 20))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: invite) {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if game.invitation == invite {
                    withAnimation { game.invitation = nil }
                }
            }
        }
    }

    private func accept(_ invite: FriendInvite) {
        game.invitation = nil
        guard let who = api.identity else { return }
        game.leave()
        game.join(pin: invite.pin, asPlayer: who)
    }
}

