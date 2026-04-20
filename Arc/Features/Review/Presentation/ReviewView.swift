import SwiftUI

struct ReviewView: View {
    let location: ShootLocation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ArcHeroHeader(
                    systemImage: "photo.on.rectangle.angled",
                    title: "Review Coverage",
                    subtitle: "This screen will turn captured photos back into useful feedback: what you got, what you missed, and what still needs another pass.",
                    badges: [
                        ArcHeroBadge(label: location.name, systemImage: "mappin.and.ellipse"),
                        ArcHeroBadge(label: "Post-shoot", systemImage: "checkmark.circle")
                    ]
                )

                ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "photo.stack",
                        title: "Coverage Summary",
                        subtitle: "The upcoming review flow will separate captured, missed, and unmatched shots so the result is immediately actionable."
                    )
                }

                ArcFeatureCard(accent: ArcPalette.glowPrimary) {
                    ArcFeatureTitle(
                        systemImage: "brain.head.profile",
                        title: "On-device matching",
                        subtitle: "The next feature step here is Vision plus Foundation Models to classify imported photos against the planned narrative roles."
                    )
                }
            }
            .padding(20)
        }
        .background(ArcSceneBackground())
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
    }
}
