import SwiftUI

/// "Style" - put on what you own or have unlocked (`rN` in the web bundle):
/// a profile card showing the current look, the category tabs with
/// "unlocked / total", search, filter and every visible item in its group.
/// Measurements from the website at 375 × 812 (k-style-*).
struct StyleView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var catalog: ItemCatalog?
    @State private var wardrobe: Wardrobe?
    @State private var loadError: String = ""
    @State private var type: String = "icon"
    @State private var search: String = ""
    @State private var filter: ItemFilter = .all
    @State private var equipping: String?
    @State private var toast: CosmeticToast?
    @State private var scrolled: CGFloat = 0

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Style", onBack: { close() })
                scroller
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .task { await load() }
    }

    // MARK: Content

    private var scroller: some View {
        ScrollViewReader { reader in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
                .id("top")
                .background(GeometryReader { g in
                    Color.clear.preference(key: ScrollOffsetKey.self, value: -g.frame(in: .named("style")).minY)
                })
            }
            .coordinateSpace(name: "style")
            .onPreferenceChange(ScrollOffsetKey.self) { scrolled = $0 }
            .overlay(alignment: .bottomTrailing) {
                if scrolled > 320 {
                    BackToTopButton { withAnimation(.easeOut(duration: 0.35)) { reader.scrollTo("top", anchor: .top) } }
                        .padding(16)
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: scrolled > 320)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !loadError.isEmpty { CosmeticErrorCard(text: loadError) }
        if let c = catalog, let w = wardrobe {
            StyleProfileCard(catalog: c, wardrobe: w)
            listing(c, w)
        } else if loadError.isEmpty {
            CosmeticNotice(text: "Loading your items…", loading: true)
        }
    }

    private func listing(_ c: ItemCatalog, _ w: Wardrobe) -> some View {
        let tabs: [ItemCategory] = c.categories.filter { $0.inStyle }
        var counts: [String: String] = [:]
        for t in tabs {
            let tally = ItemSelection.tally(c, type: t.type, wardrobe: w)
            counts[t.type] = "\(tally.unlocked)/\(tally.total)"
        }
        let shown: [CatalogItem] = ItemSelection.style(c, type: type, wardrobe: w, search: search, filter: filter)
        let label: String = tabs.first { $0.type == type }?.label ?? ""
        let groups = ItemCatalog.grouped(shown)
        let summary: String = "\(label) · \(shown.count) shown · \(counts[type] ?? "0/0") unlocked"
        return VStack(alignment: .leading, spacing: 16) {
            CategoryTabs(categories: tabs, active: Binding(get: { type }, set: { t in
                type = t
                search = ""
            }), counts: counts)
            VStack(spacing: 8) {
                ItemSearchField(text: $search)
                ItemFilterMenu(choices: ItemFilter.styleChoices, selection: $filter)
            }
            Text(summary.uppercased())
                .font(.brand(11, .bold))
                .tracking(1.1)
                .foregroundColor(Palette.subdued)
            ForEach(0..<groups.count, id: \.self) { gi in
                section(groups[gi].group, groups[gi].items, w)
            }
            if shown.isEmpty {
                CosmeticNotice(text: search.isEmpty ? "Nothing here" : "Nothing matches that search")
            }
        }
    }

    private func section(_ group: ItemGroup, _ items: [CatalogItem], _ w: Wardrobe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ItemGroupHeading(group: group, count: items.count)
            TwoColumnGrid(count: items.count) { i in
                card(items[i], w)
            }
        }
    }

    private func card(_ item: CatalogItem, _ w: Wardrobe) -> StyleCard {
        StyleCard(item: item, type: type,
                  equipped: w.equippedID(type) == item.id,
                  unlocked: w.hasUnlocked(item, type: type),
                  busy: equipping == "\(type):\(item.id)",
                  onEquip: { Task { await equip(item) } })
    }

    // MARK: Data

    @MainActor
    private func load() async {
        async let items: ItemCatalog? = try? await api.fetchAbsolute("https://fakester.app/catalog.json")
        async let profile: Wardrobe? = try? await api.fetch("/profile")
        let c: ItemCatalog? = await items
        var w: Wardrobe? = await profile
        #if DEBUG
        if w == nil { w = ScreenshotScene.sampleWardrobe }
        #endif
        if c == nil || w == nil {
            loadError = "Could not load your items"
        }
        catalog = c
        wardrobe = w
    }

    @MainActor
    private func equip(_ item: CatalogItem) async {
        guard equipping == nil, let field = Wardrobe.equipField[type] else { return }
        equipping = "\(type):\(item.id)"
        let value: Any = Int(item.id) ?? item.id
        let payload: [String: Any] = ["field": field, "value": value]
        do {
            let _: Api.Ack = try await api.call("/profile/equip", body: payload)
            Haptics.tap()
            withAnimation { toast = CosmeticToast(text: "Equipped \(item.displayName)", isError: false) }
            if let fresh: Wardrobe = try? await api.fetch("/profile") { wardrobe = fresh }
            await api.refreshProfile()
            // Accent and background take over the whole app once Style closes.
            await CosmeticLook.shared.sync(api)
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not equip that" : text, isError: true) }
        }
        equipping = nil
    }
}

/// The card at the top (`aN`): 64 avatar with the equipped icon, the name in
/// the equipped colour and name effect, the title pill and the level - all
/// tinted with the equipped accent.
struct StyleProfileCard: View {
    let catalog: ItemCatalog
    let wardrobe: Wardrobe

    var body: some View {
        let accentHex: String? = catalog.item("accent-color", id: wardrobe.equippedID("accent-color"))?.colorHex
        let tint: Color = CosmeticTone.representative(accentHex) ?? Palette.accent
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        HStack(spacing: 16) {
            avatar
                .shadow(color: tint.opacity(0.267), radius: 11)
            VStack(alignment: .leading, spacing: 0) {
                EffectName(text: wardrobe.username, cssClass: nameEffect?.cssClass, size: 22,
                           color: CosmeticTone.plain(nameColor?.colorHex) ?? Palette.foreground)
                if let title = catalog.item("title", id: wardrobe.equippedID("title")), let name = title.name {
                    TitlePill(text: name, colorHex: title.colorHex ?? accentHex ?? "#b15cff")
                }
                Text("Level \(wardrobe.level)")
                    .font(.brand(11))
                    .foregroundColor(Palette.subdued)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .background(
            ZStack {
                shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.55))
                GeometryReader { geo in
                    RadialGradient(colors: [tint.opacity(0.133), tint.opacity(0)], center: .center,
                                   startRadius: 0, endRadius: geo.size.width * 0.6)
                        .frame(width: geo.size.width * 1.2, height: geo.size.width * 1.2)
                        .scaleEffect(x: 1, y: geo.size.height / geo.size.width)
                        .position(x: geo.size.width * 0.12, y: geo.size.height / 2)
                }
                .clipShape(shape)
            }
        )
        .overlay(shape.strokeBorder(tint.opacity(0.333), lineWidth: 1))
    }

    private var icon: CatalogItem? { catalog.item("icon", id: wardrobe.equippedID("icon")) }
    private var nameColor: CatalogItem? { catalog.item("color", id: wardrobe.equippedID("color")) }
    private var nameEffect: CatalogItem? { catalog.item("name-effect", id: wardrobe.equippedID("name-effect")) }

    /// `ct` at 64: picture if there is one, else the icon at 46 % in its colour.
    private var avatar: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.07))
            if let address = pictureURL {
                AsyncImage(url: address) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        glyph
                    }
                }
            } else {
                glyph
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
    }

    private var glyph: some View {
        CosmeticGlyph(iconClass: icon?.iconClass ?? "fa-user", anim: icon?.anim, size: 64 * 0.46,
                      tint: CosmeticTone.representative(icon?.colorHex) ?? CosmeticTone.accentPale)
    }

    private var pictureURL: URL? {
        guard let p = wardrobe.avatarURL, !p.isEmpty else { return nil }
        if p.hasPrefix("http") { return URL(string: p) }
        return URL(string: "https://fakester.app" + (p.hasPrefix("/") ? p : "/" + p))
    }
}

/// One Style card (`sN`): lock badge while locked (dimmed to 45 %), the
/// preview, name + unlock label, and Equip / Equipped once unlocked. The
/// equipped card gets an accent border and glow.
struct StyleCard: View {
    let item: CatalogItem
    let type: String
    let equipped: Bool
    let unlocked: Bool
    let busy: Bool
    let onEquip: () -> Void

    var body: some View {
        let g: ItemGroup = item.itemGroup
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(spacing: 0) {
            ItemPreview(item: item, type: type)
                .frame(maxWidth: .infinity, minHeight: 84 - 28, maxHeight: .infinity)
                .padding(.horizontal, 10)
                .padding(.top, 16)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(item.displayName)
                        .font(.brand(13, .bold))
                        .foregroundColor(equipped ? Palette.foreground : CosmeticTone.nameDim)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                    Text(item.unlockLabel.uppercased())
                        .font(.brand(10, .semibold))
                        .tracking(0.25)
                        .foregroundColor(g.tint)
                        .lineLimit(1)
                        .fixedSize()
                }
                if unlocked { button }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .overlay(alignment: .topTrailing) {
            if !unlocked {
                LucideGlyph(icon: .lock, size: 10)
                    .foregroundColor(Palette.subdued)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.45)))
                    .padding(8)
            }
        }
        .background(shape.fill(CosmeticTone.cardFill)
            .shadow(color: equipped ? Palette.accent.opacity(0.18) : g.glow.color, radius: equipped ? 10 : g.glow.radius))
        .overlay(shape.strokeBorder(equipped ? Palette.accent.opacity(0.55) : g.edge, lineWidth: 1))
        .opacity(unlocked ? 1 : 0.45)
    }

    private var button: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .circular)
        return Button(action: onEquip) {
            HStack(spacing: 6) {
                if equipped {
                    LucideGlyph(icon: .check, size: 12)
                    Text("Equipped")
                } else {
                    Text(busy ? "…" : "Equip")
                }
            }
            .font(.brand(11, .bold))
            .foregroundColor(equipped ? CosmeticTone.accentPale : Palette.onAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(shape.fill(equipped ? Palette.accent.opacity(0.28) : Palette.accent))
            .overlay(shape.strokeBorder(equipped ? Palette.accent.opacity(0.5) : Color.clear, lineWidth: 1))
            .opacity(busy ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .disabled(busy || equipped)
    }
}
