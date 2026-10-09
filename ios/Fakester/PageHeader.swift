import SwiftUI

/// The header every account screen shares in the browser (`rn`): 65 tall,
/// rgba(7,7,14,.82) with a line below, a round 36 back button with the purple
/// arrow, the title 25 pt extra bold set tight, and an optional view on the
/// right (spots pill, slot counter ...).
struct PageHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Palette.accent)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.04)))
                    .overlay(Circle().strokeBorder(Palette.border, lineWidth: 1))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Back"))
            Text(title)
                .font(.brand(25, .heavy))
                .tracking(-0.625)
                .foregroundColor(Palette.foreground)
                .lineLimit(1)
            Spacer(minLength: 0)
            trailing
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 15)
        .background(Color(.sRGB, red: 7 / 255, green: 7 / 255, blue: 14 / 255, opacity: 0.82).ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.border).frame(height: 1)
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

/// The spots pill on the right of Shop / Path: ♪ 170 in purple, capsule
/// rgba(24,23,39,.9) with a 7 % border.
struct HeaderSpotsPill: View {
    @EnvironmentObject private var api: Api

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 10, weight: .bold))
            Text("\(api.me?.spots ?? 0)")
                .font(.brand(11, .bold))
        }
        .foregroundColor(Palette.accent)
        .padding(.horizontal, 10)
        .frame(height: 31)
        .background(Capsule().fill(Color(.sRGB, red: 24 / 255, green: 23 / 255, blue: 39 / 255, opacity: 0.9)))
        .overlay(Capsule().strokeBorder(Palette.border, lineWidth: 1))
    }
}
