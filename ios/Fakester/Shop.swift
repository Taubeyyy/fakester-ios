import SwiftUI

/// "Shop" - buy titles, icons, backgrounds, accents and name effects with
/// spots or gold spots (`nN` in the web bundle). Only items sold for spots are
/// listed; on weekends everything costs 20 % less.
/// Measurements from the website at 375 × 812 (k-shop-*).
struct ShopView: View {
    @EnvironmentObject private var api: Api
    @Environment(\.dismiss) private var close

    @State private var catalog: ItemCatalog?
    @State private var wardrobe: Wardrobe?
    @State private var loadError: String = ""
    @State private var type: String = "title"
    @State private var search: String = ""
    @State private var filter: ItemFilter = .all
    @State private var buying: CatalogItem?
    @State private var buyBusy = false
    @State private var bought = false
    @State private var toast: CosmeticToast?
    @State private var scrolled: CGFloat = 0

    private let onWeekend: Bool = Pricing.isWeekend()

    var body: some View {
        ZStack {
            Backdrop()
            VStack(spacing: 0) {
                PageHeader(title: "Shop", onBack: { close() }) { balances }
                scroller
            }
            if let item = buying, let w = wardrobe {
                BuySheet(item: item, type: type, wardrobe: w, onWeekend: onWeekend,
                         busy: buyBusy, done: bought,
                         onConfirm: { Task { await buy() } },
                         onClose: { closeSheet() })
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
        .overlay(alignment: .top) { CosmeticToastView(toast: $toast) }
        .animation(.easeOut(duration: 0.18), value: buying != nil)
        .task { await load() }
    }

    // MARK: Header

    private var balances: some View {
        HStack(spacing: 6) {
            HStack(spacing: 6) {
                LucideGlyph(icon: .music2, size: 11)
                Text(groupedNumber(wardrobe?.spots ?? api.me?.spots ?? 0)).monospacedDigit()
            }
            .foregroundColor(CosmeticTone.spots)
            .modifier(BalancePill())
            if (wardrobe?.goldSpots ?? 0) > 0 {
                HStack(spacing: 4) {
                    GoldSpotsIcon(size: 12)
                    Text(groupedNumber(wardrobe?.goldSpots ?? 0)).monospacedDigit()
                }
                .foregroundColor(Color(hex: 0xFBBF24))
                .modifier(BalancePill())
            }
        }
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
                    Color.clear.preference(key: ScrollOffsetKey.self, value: -g.frame(in: .named("shop")).minY)
                })
            }
            .coordinateSpace(name: "shop")
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
        if onWeekend { saleBanner }
        if !loadError.isEmpty { CosmeticErrorCard(text: loadError) }
        if let c = catalog, let w = wardrobe {
            listing(c, w)
        } else if loadError.isEmpty {
            CosmeticNotice(text: "Opening the shop…", loading: true)
        }
    }

    private var saleBanner: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .circular)
        return HStack(spacing: 8) {
            LucideGlyph(icon: .sparkles, size: 12)
            Text("Weekend sale — \(Pricing.weekendDiscount)% off everything")
                .font(.brand(12, .bold))
        }
        .foregroundColor(Palette.good)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(shape.fill(Palette.good.opacity(0.1)))
        .overlay(shape.strokeBorder(Palette.good.opacity(0.3), lineWidth: 1))
    }

    private func listing(_ c: ItemCatalog, _ w: Wardrobe) -> some View {
        let tabs: [ItemCategory] = c.categories.filter { $0.inShop }
        let result = ItemSelection.shop(c, type: type, wardrobe: w, search: search, filter: filter, onWeekend: onWeekend)
        let label: String = tabs.first { $0.type == type }?.label ?? ""
        let groups = ItemCatalog.grouped(result.shown)
        return VStack(alignment: .leading, spacing: 16) {
            CategoryTabs(categories: tabs, active: Binding(get: { type }, set: { t in
                type = t
                search = ""
            }))
            VStack(spacing: 8) {
                ItemSearchField(text: $search)
                ItemFilterMenu(choices: ItemFilter.shopChoices, selection: $filter)
            }
            Text("\(label) · \(result.shown.count) of \(result.total)".uppercased())
                .font(.brand(11, .bold))
                .tracking(1.1)
                .foregroundColor(Palette.subdued)
            ForEach(0..<groups.count, id: \.self) { gi in
                section(groups[gi].group, groups[gi].items, w)
            }
            if result.shown.isEmpty {
                CosmeticNotice(text: search.isEmpty ? "Nothing here" : "Nothing matches that search", icon: .shoppingBag)
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

    private func card(_ item: CatalogItem, _ w: Wardrobe) -> ShopCard {
        let price: ItemPrice = item.price(onWeekend: onWeekend)
        return ShopCard(item: item, type: type,
                        owned: w.hasBought(item, type: type),
                        affordable: price.amount <= w.balance(for: price),
                        price: price,
                        busy: buyBusy && buying?.id == item.id,
                        onBuy: {
                            bought = false
                            buying = item
                        })
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
            loadError = "Could not load the shop"
        }
        catalog = c
        wardrobe = w
    }

    @MainActor
    private func buy() async {
        guard let item = buying, !buyBusy else { return }
        buyBusy = true
        let price: ItemPrice = item.price(onWeekend: onWeekend)
        let itemID: Any = Int(item.id) ?? item.id
        let payload: [String: Any] = [
            "itemId": itemID, "itemType": type, "cost": price.amount, "useGoldSpots": price.isGold
        ]
        do {
            let _: Api.Ack = try await api.call("/shop/buy", body: payload)
            Haptics.correct()
            bought = true
            if let fresh: Wardrobe = try? await api.fetch("/profile") { wardrobe = fresh }
            await api.refreshProfile()
        } catch {
            Haptics.wrong()
            let text: String = error.localizedDescription
            withAnimation { toast = CosmeticToast(text: text.isEmpty ? "Could not buy that" : text, isError: true) }
            buying = nil
        }
        buyBusy = false
    }

    private func closeSheet() {
        guard !buyBusy else { return }
        buying = nil
        bought = false
    }
}

/// The balance pills in the header: 11 pt bold, padding 6/10, glass capsule.
private struct BalancePill: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.brand(11, .bold))
            .padding(.horizontal, 10)
            .frame(height: 31)
            .background(Capsule().fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
            .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
    }
}

/// One shop card (`N3`): unlock label (+ sale badge), the preview, name,
/// price and a bar that says Owned, Buy or Too pricey. Unaffordable cards
/// are dimmed to 45 %; tapping any card that isn't owned opens the sheet.
struct ShopCard: View {
    let item: CatalogItem
    let type: String
    let owned: Bool
    let affordable: Bool
    let price: ItemPrice
    let busy: Bool
    let onBuy: () -> Void

    var body: some View {
        let g: ItemGroup = item.itemGroup
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        VStack(alignment: .leading, spacing: 0) {
            topRow(g)
            // min-height 78 in the browser includes the 20 + 20 padding (border-box).
            ItemPreview(item: item, type: type)
                .frame(maxWidth: .infinity, minHeight: 78 - 40, maxHeight: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 20)
            VStack(alignment: .leading, spacing: 4) {
                if type != "title" {
                    Text(item.displayName)
                        .font(.brand(13, .bold))
                        .foregroundColor(Palette.foreground)
                        .lineLimit(1)
                }
                PriceTag(price: price, showsFull: !owned)
                bar
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
        .background(shape.fill(CosmeticTone.cardFill).shadow(color: g.glow.color, radius: g.glow.radius))
        .overlay(shape.strokeBorder(g.edge, lineWidth: 1))
        .opacity(owned || affordable ? 1 : 0.45)
        .contentShape(shape)
        .onTapGesture {
            if !owned && !busy { onBuy() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(owned ? [] : .isButton)
    }

    private func topRow(_ g: ItemGroup) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(item.unlockLabel.uppercased())
                .font(.brand(9, .bold))
                .tracking(0.225)
                .foregroundColor(g.tint)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(Capsule().strokeBorder(g.edge, lineWidth: 1))
            Spacer(minLength: 0)
            if price.isDiscounted && !owned {
                Text("-\(Pricing.weekendDiscount)%")
                    .font(.brand(9, .bold))
                    .foregroundColor(Palette.good)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.good.opacity(0.18)))
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
    }

    private var bar: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .circular)
        let fill: Color = owned ? Color.white.opacity(0.05) : (affordable ? CosmeticTone.spots : Color(hex: 0xEF4444).opacity(0.1))
        let ink: Color = owned ? Palette.subdued : (affordable ? CosmeticTone.buyInk : Palette.bad)
        return HStack(spacing: 6) {
            if owned {
                LucideGlyph(icon: .check, size: 12)
                Text("Owned")
            } else {
                Text(busy ? "…" : (affordable ? "Buy" : "Too pricey"))
            }
        }
        .font(.brand(11, .bold))
        .foregroundColor(ink)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(shape.fill(fill))
        .overlay(shape.strokeBorder(owned ? Palette.border : Color.clear, lineWidth: 1))
        .opacity(busy ? 0.6 : 1)
    }
}

/// The purchase dialog (`tN`): label + close, big preview, name, a box with
/// price / balance / balance after, then Cancel and Buy. After buying the
/// preview turns into a green tick with "Yours" and Cancel into Done.
struct BuySheet: View {
    let item: CatalogItem
    let type: String
    let wardrobe: Wardrobe
    let onWeekend: Bool
    let busy: Bool
    let done: Bool
    let onConfirm: () -> Void
    let onClose: () -> Void

    var body: some View {
        let g: ItemGroup = item.itemGroup
        let shape = RoundedRectangle(cornerRadius: 24, style: .circular)
        ZStack {
            Color(.sRGB, red: 4 / 255, green: 4 / 255, blue: 10 / 255, opacity: 0.72)
                .ignoresSafeArea()
                .onTapGesture { if !busy { onClose() } }
            VStack(spacing: 0) {
                header(g)
                preview
                    .frame(maxWidth: .infinity, minHeight: 104)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                if type != "title" {
                    Text(item.displayName)
                        .font(.brand(17, .heavy))
                        .foregroundColor(Palette.foreground)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                }
                facts
                buttons
            }
            .frame(maxWidth: 340)
            .background(shape.fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.98)))
            .overlay(shape.strokeBorder(g.edge, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 24)
            .padding(16)
        }
    }

    private var price: ItemPrice { item.price(onWeekend: onWeekend) }
    private var balance: Int { wardrobe.balance(for: price) }
    private var after: Int { balance - price.amount }

    private func header(_ g: ItemGroup) -> some View {
        HStack {
            Text(item.unlockLabel.uppercased())
                .font(.brand(10, .bold))
                .tracking(1)
                .foregroundColor(g.tint)
            Spacer(minLength: 0)
            Button(action: onClose) {
                LucideGlyph(icon: .x, size: 12)
                    .foregroundColor(Palette.subdued)
                    .frame(width: 24, height: 24)
                    .background(RoundedRectangle(cornerRadius: 8, style: .circular).fill(Color.white.opacity(0.05)))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .opacity(busy ? 0.4 : 1)
            .accessibilityLabel(Text("Close"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var preview: some View {
        if done {
            VStack(spacing: 8) {
                LucideGlyph(icon: .check, size: 26)
                    .foregroundColor(Palette.good)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Palette.good.opacity(0.15)))
                    .overlay(Circle().strokeBorder(Palette.good.opacity(0.45), lineWidth: 1))
                Text("Yours")
                    .font(.brand(13, .bold))
                    .foregroundColor(Palette.good)
            }
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        } else if type == "title" {
            titleText
        } else {
            ItemPreview(item: item, type: type, size: 44)
        }
    }

    @ViewBuilder
    private var titleText: some View {
        let words = Text(item.displayName).font(.brand(19, .heavy))
        if item.isGradient, let fill = CosmeticTone.paint(item.colorHex) {
            words.foregroundColor(.clear)
                .overlay(Rectangle().fill(fill).mask(words))
                .multilineTextAlignment(.center)
        } else {
            words.foregroundColor(CosmeticTone.plain(item.colorHex) ?? Palette.foreground)
                .multilineTextAlignment(.center)
        }
    }

    private var facts: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        return VStack(spacing: 8) {
            factRow("Price") {
                HStack(spacing: 6) {
                    PriceTag(price: price, size: 11, textSize: 12, spotsTint: Palette.accent)
                    if price.isDiscounted {
                        Text("-\(Pricing.weekendDiscount)%")
                            .font(.brand(10, .bold))
                            .foregroundColor(Palette.good)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Palette.good.opacity(0.18)))
                    }
                }
            }
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            factRow(price.isGold ? "Your GoldSpots" : "Your Spots") {
                Text(groupedNumber(balance)).font(.brand(12, .semibold)).monospacedDigit()
                    .foregroundColor(Palette.foreground)
            }
            factRow("After") {
                Text(groupedNumber(after)).font(.brand(12, .bold)).monospacedDigit()
                    .foregroundColor(after < 0 ? Palette.bad : Palette.good)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(shape.fill(Color.white.opacity(0.03)))
        .overlay(shape.strokeBorder(Color.white.opacity(0.06), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func factRow<Value: View>(_ label: String, @ViewBuilder value: () -> Value) -> some View {
        HStack {
            Text(label).font(.brand(12)).foregroundColor(Palette.subdued)
            Spacer(minLength: 8)
            value()
        }
    }

    private var buttons: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .circular)
        let short: Bool = after < 0
        return HStack(spacing: 8) {
            Button(action: onClose) {
                Text(done ? "Done" : "Cancel")
                    .font(.brand(13, .bold))
                    .foregroundColor(Palette.foreground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(shape.fill(Color.white.opacity(0.03)))
                    .overlay(shape.strokeBorder(Palette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .opacity(busy ? 0.5 : 1)
            if !done {
                Button(action: onConfirm) {
                    Text(busy ? "Buying…" : (short ? "Not enough Spots" : "Buy"))
                        .font(.brand(13, .bold))
                        .foregroundColor(short ? Palette.bad : Palette.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(shape.fill(short ? Color(hex: 0xEF4444).opacity(0.15) : Palette.accent))
                }
                .buttonStyle(.plain)
                .disabled(busy || short)
                .opacity(busy ? 0.7 : 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}
