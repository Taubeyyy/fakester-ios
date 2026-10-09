import SwiftUI

/// The equipped look that colours the whole app, like the browser does with
/// `--acc` and the profile background (`S2`, `xt`): the accent colour and the
/// background behind every screen.
///
/// Changes are staged and only applied on the home screen (or at launch):
/// applying rebuilds the screens, which must not happen in the middle of a
/// game or while the Style screen is open.
/// Not main-actor isolated on purpose: `Palette` reads it from everywhere.
final class CosmeticLook: ObservableObject {
    static let shared = CosmeticLook()

    /// The accent in use (#rrggbb). Read by `Palette` on every draw.
    private(set) var accent: UInt32
    /// The equipped background's CSS class ("bg-b-graphite"), nil = the default blobs.
    private(set) var background: String?
    /// Bumped on every applied change - the root view uses it as its identity.
    @Published private(set) var version: Int = 0

    private var staged: (accent: UInt32, background: String?)?
    private static var catalog: ItemCatalog?
    private let store = UserDefaults.standard

    private init() {
        let saved: Int = store.integer(forKey: "look.accent")
        accent = saved > 0 ? UInt32(saved) : AccentShades.standard
        background = store.string(forKey: "look.background")
    }

    /// Works out the look from the profile and the catalog, and stages it.
    @MainActor
    func sync(_ api: Api) async {
        guard api.isLoggedIn, let me = api.me else {
            stage(accent: AccentShades.standard, background: nil)
            return
        }
        if CosmeticLook.catalog == nil {
            CosmeticLook.catalog = try? await api.fetchAbsolute("https://fakester.app/catalog.json")
        }
        guard let c = CosmeticLook.catalog else { return }
        let accentHex: String? = c.item("accent-color", id: me.equipped_accent_color_id?.text)?.colorHex
        let rgb: UInt32 = CosmeticColor.representative(accentHex).flatMap { CosmeticColor.rgb($0) } ?? AccentShades.standard
        let css: String? = c.item("background", id: me.equipped_background_id?.text)?.cssClass
        stage(accent: rgb, background: css)
    }

    func stage(accent rgb: UInt32, background css: String?) {
        if rgb == accent && css == background {
            staged = nil
        } else {
            staged = (rgb, css)
        }
    }

    /// Applies a staged change. Call only where rebuilding the screen is harmless.
    func commit() {
        guard let s = staged else { return }
        staged = nil
        accent = s.accent
        background = s.background
        store.set(Int(s.accent), forKey: "look.accent")
        store.set(s.background, forKey: "look.background")
        version += 1
    }

    /// Logging out: back to the default purple.
    func reset() {
        stage(accent: AccentShades.standard, background: nil)
        commit()
    }
}
