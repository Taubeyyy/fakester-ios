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
                .tint(Palette.accent)
        }
    }
}

/// Decides which screen is up. The state comes from the server - the app has
/// no opinion of its own about which part of the game you are in.
struct RootView: View {
    @EnvironmentObject private var api: Api
    @EnvironmentObject private var game: Game
    @State private var feedbackOpen = false

    var body: some View {
        ZStack {
            Backdrop()
            currentScreen
        }
        .animation(.easeInOut(duration: 0.22), value: game.currentPhase)
        // The server talks in short notices ("Game not found!"), which would
        // otherwise get lost.
        .overlay(alignment: .top) { ToastBanner() }
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
