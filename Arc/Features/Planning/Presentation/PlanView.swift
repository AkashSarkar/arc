import SwiftUI

struct PlanView: View {
    let location: ShootLocation

    @State private var viewModel: PlanViewModel

    init(location: ShootLocation, aiService: any AIServicing) {
        self.location = location
        _viewModel = State(initialValue: PlanViewModel(aiService: aiService))
    }

    var body: some View {
        Form {
            Section("Output") {
                Picker("Intent", selection: $viewModel.outputIntent) {
                    ForEach(OutputIntent.allCases) { intent in
                        Text(intent.title)
                            .tag(intent)
                    }
                }

                Text("The generated plan will target a \(viewModel.outputIntent.promptLabel) with \(viewModel.outputIntent.defaultShotCount) suggested shots.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shoot Window") {
                Picker("Timing", selection: $viewModel.shootWindowMode) {
                    ForEach(ShootWindowMode.allCases) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if viewModel.shootWindowMode == .custom {
                    DatePicker("Date", selection: $viewModel.shootDate, displayedComponents: .date)
                    DatePicker("Start", selection: $viewModel.shootStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $viewModel.shootEndTime, displayedComponents: .hourAndMinute)
                }

                Text(viewModel.shootWindowSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Creative Notes") {
                TextEditor(text: $viewModel.notes)
                    .frame(minHeight: 140)
            }

            Section {
                Button {
                    Task {
                        await viewModel.generatePlan(for: location)
                    }
                } label: {
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        }

                        Text(viewModel.isLoading ? "Generating..." : "Generate Plan")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !viewModel.response.isEmpty {
                Section("Response") {
                    Text(viewModel.response)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("Plan")
        .onChange(of: viewModel.shootStartTime) { _, _ in
            viewModel.ensureDefaultWindowTimes()
        }
    }
}
