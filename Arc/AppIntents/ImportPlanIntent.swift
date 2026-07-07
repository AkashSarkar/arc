import AppIntents
import Foundation

struct ImportPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Import Plan"
    static let description = IntentDescription("Send trip notes or a shoot plan to Arc for import.")
    static var supportedModes: IntentModes { .foreground(.dynamic) }

    @Parameter(title: "Plan Text", description: "The note, itinerary, or markdown plan to import.")
    var planText: AttributedString

    init() {
    }

    init(planText: AttributedString) {
        self.planText = planText
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = String(planText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .result(dialog: "No plan text was provided.")
        }

        ImportHandoff.store(text: text)
        return .result(dialog: "Arc is ready to review this plan.")
    }
}

struct ArcShortcutsProvider: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .blue }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportPlanIntent(),
            phrases: [
                "Import Plan in \(.applicationName)",
                "Send Note to \(.applicationName)"
            ],
            shortTitle: "Import Plan",
            systemImageName: "square.and.arrow.down"
        )
    }
}
