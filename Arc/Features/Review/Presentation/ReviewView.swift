import SwiftUI

struct ReviewView: View {
    let location: ShootLocation

    var body: some View {
        VStack(spacing: 12) {
            Text("Review")
                .font(.title2.bold())
            Text("Post-shoot coverage and matching will be implemented next.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle(location.name)
    }
}
