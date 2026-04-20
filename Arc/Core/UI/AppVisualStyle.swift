import SwiftUI
import UIKit

enum ArcPalette {
    static let tint = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.58, green: 0.84, blue: 0.80, alpha: 1)
        default:
            return UIColor(red: 0.20, green: 0.46, blue: 0.45, alpha: 1)
        }
    })

    static let backgroundTop = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.09, green: 0.12, blue: 0.14, alpha: 1)
        default:
            return UIColor(red: 0.95, green: 0.97, blue: 0.96, alpha: 1)
        }
    })

    static let backgroundBottom = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.05, green: 0.08, blue: 0.10, alpha: 1)
        default:
            return UIColor(red: 0.88, green: 0.92, blue: 0.93, alpha: 1)
        }
    })

    static let glowPrimary = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.24, green: 0.48, blue: 0.46, alpha: 1)
        default:
            return UIColor(red: 0.59, green: 0.78, blue: 0.73, alpha: 1)
        }
    })

    static let glowSecondary = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.22, green: 0.32, blue: 0.40, alpha: 1)
        default:
            return UIColor(red: 0.69, green: 0.78, blue: 0.89, alpha: 1)
        }
    })

    static let surfaceFill = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.12, green: 0.16, blue: 0.18, alpha: 0.82)
        default:
            return UIColor(red: 1, green: 1, blue: 1, alpha: 0.72)
        }
    })

    static let elevatedSurface = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.14, green: 0.18, blue: 0.21, alpha: 0.94)
        default:
            return UIColor(red: 0.98, green: 0.99, blue: 0.99, alpha: 0.94)
        }
    })

    static let surfaceStroke = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(white: 1, alpha: 0.10)
        default:
            return UIColor(red: 0.74, green: 0.80, blue: 0.82, alpha: 0.55)
        }
    })

    static let solidFieldSurface = Color(uiColor: UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0.10, green: 0.12, blue: 0.13, alpha: 0.97)
        default:
            return UIColor(red: 0.96, green: 0.97, blue: 0.95, alpha: 0.97)
        }
    })
}

struct ArcSceneBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ArcPalette.backgroundTop, ArcPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(ArcPalette.glowPrimary.opacity(0.34))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -120, y: -240)

            Circle()
                .fill(ArcPalette.glowSecondary.opacity(0.26))
                .frame(width: 320, height: 320)
                .blur(radius: 96)
                .offset(x: 140, y: 220)
        }
        .ignoresSafeArea()
    }
}

struct ArcHeroBadge: Identifiable, Hashable {
    let label: String
    let systemImage: String

    var id: String {
        "\(systemImage)-\(label)"
    }
}

struct ArcHeroHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var badges: [ArcHeroBadge] = []

    private let cardShape = RoundedRectangle(cornerRadius: 32, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ArcIconOrb(systemImage: systemImage)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(badges) { badge in
                            ArcHeroBadgeView(badge: badge)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(alignment: .topTrailing) {
            Circle()
                .fill(ArcPalette.glowPrimary.opacity(0.24))
                .frame(width: 140, height: 140)
                .blur(radius: 32)
                .offset(x: 28, y: -30)
        }
        .background(ArcPalette.surfaceFill, in: cardShape)
        .glassEffect(in: cardShape)
        .overlay {
            cardShape
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 20, y: 12)
    }
}

struct ArcFeatureCard<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content

    private let cardShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    init(accent: Color = ArcPalette.tint, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(ArcPalette.surfaceFill, in: cardShape)
        .glassEffect(in: cardShape)
        .overlay {
            cardShape
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
        .background(alignment: .topTrailing) {
            Circle()
                .fill(accent.opacity(0.18))
                .frame(width: 120, height: 120)
                .blur(radius: 26)
                .offset(x: 26, y: -24)
        }
    }
}

struct ArcFeatureTitle: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var accent: Color = ArcPalette.tint

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ArcMiniIconBadge(systemImage: systemImage, tint: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ArcMiniIconBadge: View {
    let systemImage: String
    var tint: Color = ArcPalette.tint

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(tint.opacity(0.14))
            )
    }
}

private struct ArcIconOrb: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title2.weight(.semibold))
            .foregroundStyle(ArcPalette.tint)
            .frame(width: 52, height: 52)
            .background(
                Circle()
                    .fill(ArcPalette.tint.opacity(0.14))
            )
    }
}

private struct ArcHeroBadgeView: View {
    let badge: ArcHeroBadge

    var body: some View {
        Label(badge.label, systemImage: badge.systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(in: Capsule())
    }
}