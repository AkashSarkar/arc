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
            Section {
                ArcHeroHeader(
                    systemImage: "sparkles.rectangle.stack",
                    title: "Plan Shoot",
                    subtitle: "Pick timing and output, then generate a draft.",
                    badges: [
                        ArcHeroBadge(label: viewModel.outputIntent.title, systemImage: "square.stack.3d.up"),
                        ArcHeroBadge(label: viewModel.shootWindowMode.title, systemImage: "calendar.badge.clock")
                    ]
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Location") {
                ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "map.fill",
                        title: location.name,
                        subtitle: nil
                    )

                    Label(
                        "\(location.latitude.formatted(.number.precision(.fractionLength(5)))), \(location.longitude.formatted(.number.precision(.fractionLength(5))))",
                        systemImage: "location.north.line"
                    )
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Output") {
                Picker("Intent", selection: $viewModel.outputIntent) {
                    ForEach(OutputIntent.allCases) { intent in
                        Text(intent.title)
                            .tag(intent)
                    }
                }

                Text("Targets \(viewModel.outputIntent.defaultShotCount) suggested shots.")
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

            Section("Notes") {
                TextEditor(text: $viewModel.notes)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(12)
                    .background(ArcPalette.elevatedSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(ArcPalette.surfaceStroke, lineWidth: 1)
                    }

                Text("Optional.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                .buttonStyle(.glassProminent)
                .disabled(viewModel.isLoading)
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !viewModel.response.isEmpty {
                Section("Generated Plan") {
                    ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                        ArcFeatureTitle(
                            systemImage: "text.alignleft",
                            title: "Draft Output",
                            subtitle: nil
                        )

                        Text(viewModel.response)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: viewModel.shootStartTime) { _, _ in
            viewModel.ensureDefaultWindowTimes()
        }
    }
}
