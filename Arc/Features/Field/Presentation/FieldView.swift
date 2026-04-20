import SwiftUI

struct FieldView: View {
    let location: ShootLocation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                FieldHeroCard(location: location)

                FieldModeCard(
                    title: "Readable outdoors",
                    subtitle: "Field mode should prioritize contrast, oversized tap targets, and a calm layout that still works in direct sunlight.",
                    systemImage: "sun.max.fill"
                )

                FieldModeCard(
                    title: "Checklist-first workflow",
                    subtitle: "The next step here is a shot checklist with progress, quick completion toggles, and minimal friction while moving through a real location.",
                    systemImage: "checklist"
                )
            }
            .padding(20)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Field")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FieldHeroCard: View {
    let location: ShootLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ArcFeatureTitle(
                systemImage: "checklist.checked",
                title: "Field Mode",
                subtitle: "Built for quick decisions on location, with sturdy controls and strong readability instead of delicate effects.",
                accent: ArcPalette.tint
            )

            HStack(spacing: 12) {
                Text(location.name)
                    .font(.headline)
                Spacer()
                Text("Preview")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ArcPalette.tint.opacity(0.16), in: Capsule())
            }
        }
        .padding(22)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}

private struct FieldModeCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ArcFeatureTitle(
                systemImage: systemImage,
                title: title,
                subtitle: subtitle,
                accent: ArcPalette.tint
            )
        }
        .padding(20)
        .background(ArcPalette.solidFieldSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
        }
    }
}
