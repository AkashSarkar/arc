import SwiftUI

struct AddLocationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var latitudeText: String = ""
    @State private var longitudeText: String = ""
    @State private var errorMessage: String?

    let onSave: (ShootLocation) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    TextField("Name", text: $name)
                    TextField("Latitude", text: $latitudeText)
                        .keyboardType(.decimalPad)
                    TextField("Longitude", text: $longitudeText)
                        .keyboardType(.decimalPad)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Location")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveLocation()
                    }
                }
            }
        }
    }

    private func saveLocation() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            errorMessage = "Name is required."
            return
        }

        guard let latitude = Double(latitudeText), (-90 ... 90).contains(latitude) else {
            errorMessage = "Latitude must be between -90 and 90."
            return
        }

        guard let longitude = Double(longitudeText), (-180 ... 180).contains(longitude) else {
            errorMessage = "Longitude must be between -180 and 180."
            return
        }

        onSave(ShootLocation(name: cleanName, latitude: latitude, longitude: longitude))
        dismiss()
    }
}
