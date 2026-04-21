import Foundation
import SwiftData
import SwiftUI

struct SettingsView: View {
    let apiKeyStore: any APIKeyProviding
    let defaultAIConfiguration: AIConfiguration

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LLMProfile.createdAt, order: .forward) private var profiles: [LLMProfile]

    @State private var editingProfile: LLMProfile?
    @State private var isPresentingNewProfile = false
    @State private var errorMessage: String?

    private var heroBadges: [ArcHeroBadge] {
        var badges = [ArcHeroBadge(label: "\(profiles.count) profiles", systemImage: "switch.2")]

        if let activeProfile = profiles.first(where: \.isActive) {
            badges.append(ArcHeroBadge(label: activeProfile.name, systemImage: "checkmark.circle.fill"))
        }

        return badges
    }

    var body: some View {
        List {
            Section {
                ArcHeroHeader(
                    systemImage: "gearshape.2.fill",
                    title: "LLM Profiles",
                    subtitle: "Store local and cloud model endpoints as named profiles, then keep one active for planning.",
                    badges: heroBadges
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let errorMessage {
                Section {
                    ArcFeatureCard(accent: .red) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            if profiles.isEmpty {
                Section {
                    ArcFeatureCard {
                        ArcFeatureTitle(
                            systemImage: "switch.2",
                            title: "Add your first profile",
                            subtitle: "Use LM Studio locally or save a cloud provider configuration."
                        )

                        Button("Create Profile") {
                            isPresentingNewProfile = true
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.glassProminent)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section("Profiles") {
                    ForEach(profiles) { profile in
                        SettingsProfileCard(
                            profile: profile,
                            hasStoredAPIKey: hasStoredAPIKey(for: profile),
                            activateAction: { activate(profile) },
                            editAction: { editingProfile = profile },
                            deleteAction: { delete(profile) }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(ArcSceneBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isPresentingNewProfile = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add LLM profile")
            }
        }
        .sheet(isPresented: $isPresentingNewProfile) {
            NavigationStack {
                LLMProfileEditorView(
                    profile: nil,
                    apiKeyStore: apiKeyStore,
                    defaultAIConfiguration: defaultAIConfiguration,
                    shouldDefaultToActive: profiles.allSatisfy { !$0.isActive }
                )
            }
        }
        .sheet(item: $editingProfile) { profile in
            NavigationStack {
                LLMProfileEditorView(
                    profile: profile,
                    apiKeyStore: apiKeyStore,
                    defaultAIConfiguration: defaultAIConfiguration,
                    shouldDefaultToActive: false
                )
            }
        }
    }

    private func hasStoredAPIKey(for profile: LLMProfile) -> Bool {
        guard profile.requiresAPIKey, let account = profile.apiKeyAccount else {
            return false
        }

        guard let key = try? apiKeyStore.apiKey(for: account) else {
            return false
        }

        return !key.isEmpty
    }

    private func activate(_ profile: LLMProfile) {
        errorMessage = nil

        for candidate in profiles {
            candidate.isActive = candidate.id == profile.id
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func delete(_ profile: LLMProfile) {
        errorMessage = nil

        if let account = profile.apiKeyAccount {
            do {
                try apiKeyStore.deleteAPIKey(for: account)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        let wasActive = profile.isActive
        let fallbackProfile = profiles.first(where: { $0.id != profile.id })
        modelContext.delete(profile)

        if wasActive {
            fallbackProfile?.isActive = true
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SettingsProfileCard: View {
    let profile: LLMProfile
    let hasStoredAPIKey: Bool
    let activateAction: () -> Void
    let editAction: () -> Void
    let deleteAction: () -> Void

    private var hostLabel: String {
        profile.baseURL.host() ?? profile.baseURL.absoluteString
    }

    private var keyStatusLabel: String {
        if !profile.requiresAPIKey {
            return "No key required"
        }

        return hasStoredAPIKey ? "Key stored" : "Missing API key"
    }

    private var keyStatusColor: Color {
        if !profile.requiresAPIKey {
            return .secondary
        }

        return hasStoredAPIKey ? ArcPalette.glowPrimary : .red
    }

    private var keyStatusImage: String {
        if !profile.requiresAPIKey {
            return "checkmark.shield"
        }

        return hasStoredAPIKey ? "key.fill" : "exclamationmark.triangle.fill"
    }

    var body: some View {
        ArcFeatureCard(accent: profile.isActive ? ArcPalette.tint : ArcPalette.glowSecondary) {
            HStack(alignment: .top, spacing: 12) {
                ArcFeatureTitle(
                    systemImage: profile.isActive ? "checkmark.circle.fill" : "cpu",
                    title: profile.name,
                    subtitle: "\(profile.modelName) on \(hostLabel)",
                    accent: profile.isActive ? ArcPalette.tint : ArcPalette.glowSecondary
                )

                if profile.isActive {
                    Text("Active")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ArcPalette.tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(ArcPalette.tint)
                }
            }

            HStack(spacing: 12) {
                Label(keyStatusLabel, systemImage: keyStatusImage)
                    .font(.caption)
                    .foregroundStyle(keyStatusColor)

                Label(
                    profile.useStructuredOutput ? "JSON mode on" : "JSON mode off",
                    systemImage: profile.useStructuredOutput ? "curlybraces.square.fill" : "curlybraces.square"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Label("\(Int(profile.timeoutSeconds.rounded()))s", systemImage: "timer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(profile.isActive ? "Active" : "Use This Profile") {
                    activateAction()
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.glassProminent)
                .disabled(profile.isActive)

                Button("Edit") {
                    editAction()
                }
                .buttonStyle(.glass)

                Button("Delete", role: .destructive) {
                    deleteAction()
                }
                .buttonStyle(.glass)
            }
        }
    }
}

private struct LLMProfileEditorView: View {
    let profile: LLMProfile?
    let apiKeyStore: any APIKeyProviding
    let defaultAIConfiguration: AIConfiguration
    let shouldDefaultToActive: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LLMProfile.createdAt, order: .forward) private var existingProfiles: [LLMProfile]

    @State private var name: String
    @State private var baseURLString: String
    @State private var modelName: String
    @State private var requiresAPIKey: Bool
    @State private var useStructuredOutput: Bool
    @State private var timeoutText: String
    @State private var apiKey: String = ""
    @State private var isActive: Bool
    @State private var hasStoredAPIKey: Bool
    @State private var errorMessage: String?

    init(
        profile: LLMProfile?,
        apiKeyStore: any APIKeyProviding,
        defaultAIConfiguration: AIConfiguration,
        shouldDefaultToActive: Bool
    ) {
        self.profile = profile
        self.apiKeyStore = apiKeyStore
        self.defaultAIConfiguration = defaultAIConfiguration
        self.shouldDefaultToActive = shouldDefaultToActive

        _name = State(initialValue: profile?.name ?? "")
        _baseURLString = State(initialValue: profile?.baseURLString ?? defaultAIConfiguration.baseURL.absoluteString)
        _modelName = State(initialValue: profile?.modelName ?? defaultAIConfiguration.modelName)
        _requiresAPIKey = State(initialValue: profile?.requiresAPIKey ?? false)
        _useStructuredOutput = State(initialValue: profile?.useStructuredOutput ?? false)
        _timeoutText = State(initialValue: String(Int((profile?.timeoutSeconds ?? defaultAIConfiguration.timeoutSeconds).rounded())))
        _isActive = State(initialValue: profile?.isActive ?? shouldDefaultToActive)

        if let account = profile?.apiKeyAccount,
           let storedKey = try? apiKeyStore.apiKey(for: account),
           !storedKey.isEmpty {
            _hasStoredAPIKey = State(initialValue: true)
        } else {
            _hasStoredAPIKey = State(initialValue: false)
        }
    }

    private var isEditing: Bool {
        profile != nil
    }

    var body: some View {
        Form {
            Section {
                ArcHeroHeader(
                    systemImage: isEditing ? "slider.horizontal.3" : "plus.circle.fill",
                    title: isEditing ? "Edit Profile" : "New Profile",
                    subtitle: "Define the endpoint, model, and key requirements for one LLM target."
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 12, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard {
                    ArcFeatureTitle(
                        systemImage: "switch.2",
                        title: "Profile",
                        subtitle: nil
                    )

                    TextField("Profile name", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Base URL", text: $baseURLString)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    Text("Use the OpenAI-compatible base URL. For LM Studio, entering just the host like http://192.168.0.119:1234 is fine; Arc will use /v1 automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Model name", text: $modelName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Timeout seconds", text: $timeoutText)
                        .keyboardType(.numberPad)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ArcFeatureCard(accent: ArcPalette.glowSecondary) {
                    ArcFeatureTitle(
                        systemImage: "gearshape.2",
                        title: "Options",
                        subtitle: nil,
                        accent: ArcPalette.glowSecondary
                    )

                    Toggle("Requires API key", isOn: $requiresAPIKey)
                    Toggle("Prefer structured output", isOn: $useStructuredOutput)
                    Toggle("Make active profile", isOn: $isActive)

                    if requiresAPIKey {
                        SecureField(hasStoredAPIKey ? "Leave blank to keep stored API key" : "API key", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Text(hasStoredAPIKey ? "A key is already stored on this device." : "This profile will fail until an API key is stored.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Use this for local runners like LM Studio when no authentication is required.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let errorMessage {
                Section {
                    ArcFeatureCard(accent: .red) {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.red)
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
        .navigationTitle(isEditing ? "Edit Profile" : "New Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Save" : "Add") {
                    saveProfile()
                }
            }
        }
    }

    private func saveProfile() {
        errorMessage = nil

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBaseURL = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanModelName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Profile name is required."
            return
        }

        guard let baseURL = URL(string: cleanBaseURL), baseURL.scheme != nil, baseURL.host() != nil else {
            errorMessage = "Enter a valid base URL."
            return
        }

        let normalizedBaseURL = AIConfiguration.normalizedOpenAICompatibleBaseURL(baseURL)

        guard !cleanModelName.isEmpty else {
            errorMessage = "Model name is required."
            return
        }

        guard let timeoutSeconds = TimeInterval(timeoutText), timeoutSeconds > 0 else {
            errorMessage = "Timeout must be a positive number of seconds."
            return
        }

        let targetProfile = profile ?? LLMProfile(
            name: cleanName,
            baseURLString: normalizedBaseURL.absoluteString,
            modelName: cleanModelName,
            requiresAPIKey: requiresAPIKey,
            useStructuredOutput: useStructuredOutput,
            timeoutSeconds: timeoutSeconds,
            isActive: false
        )
        let existingAccount = targetProfile.apiKeyAccount
        let resolvedAccount = requiresAPIKey ? (existingAccount ?? LLMProfile.keychainAccount(for: targetProfile.id)) : nil

        if requiresAPIKey && cleanAPIKey.isEmpty && !hasStoredAPIKey {
            errorMessage = "API key is required for this profile. Turn off Requires API key for local runners like LM Studio."
            return
        }

        do {
            if !requiresAPIKey, let existingAccount {
                try apiKeyStore.deleteAPIKey(for: existingAccount)
                hasStoredAPIKey = false
            }

            if let resolvedAccount, !cleanAPIKey.isEmpty {
                try apiKeyStore.saveAPIKey(cleanAPIKey, for: resolvedAccount)
                hasStoredAPIKey = true
            }

            targetProfile.name = cleanName
            targetProfile.baseURLString = normalizedBaseURL.absoluteString
            targetProfile.modelName = cleanModelName
            targetProfile.apiKeyAccount = resolvedAccount
            targetProfile.requiresAPIKey = requiresAPIKey
            targetProfile.useStructuredOutput = useStructuredOutput
            targetProfile.timeoutSeconds = timeoutSeconds

            let otherProfiles = existingProfiles.filter { $0.id != targetProfile.id }
            let shouldActivateProfile = isActive || !otherProfiles.contains(where: \.isActive)
            targetProfile.isActive = shouldActivateProfile

            if shouldActivateProfile {
                for otherProfile in otherProfiles {
                    otherProfile.isActive = false
                }
            }

            if profile == nil {
                modelContext.insert(targetProfile)
            }

            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}