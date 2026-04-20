import SwiftUI

struct FieldView: View {
    let location: ShootLocation

    var body: some View {
        VStack(spacing: 12) {
            Text("Field Mode")
                .font(.title2.bold())
            Text("In-field checklist UI will be implemented next.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .navigationTitle(location.name)
    }
}
