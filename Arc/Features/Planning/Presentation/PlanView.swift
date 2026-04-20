import SwiftUI

struct PlanView: View {
    let location: ShootLocation

    @State private var viewModel: PlanViewModel

    init(location: ShootLocation, aiService: any AIServicing) {
        self.location = location
        _viewModel = State(initialValue: PlanViewModel(aiService: aiService))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Prompt")
                .font(.headline)

            TextEditor(text: $viewModel.prompt)
                .frame(minHeight: 140)
                .padding(8)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                }

            Button {
                Task {
                    await viewModel.generatePlan()
                }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isLoading ? "Generating..." : "Generate Plan")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            if !viewModel.response.isEmpty {
                Text("Response")
                    .font(.headline)
                ScrollView {
                    Text(viewModel.response)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Plan")
        .onAppear {
            viewModel.applyDefaultPromptIfNeeded(for: location)
        }
    }
}
