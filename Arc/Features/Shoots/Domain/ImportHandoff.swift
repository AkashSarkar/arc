import Foundation
import PDFKit

nonisolated enum ImportHandoff {
    private static let pendingTextKey = "Arc.PendingImportText"

    static func store(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        UserDefaults.standard.set(trimmed, forKey: pendingTextKey)
    }

    static func consumePendingText() -> String? {
        guard let value = UserDefaults.standard.string(forKey: pendingTextKey),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }

        UserDefaults.standard.removeObject(forKey: pendingTextKey)
        return value
    }

    static func readText(from url: URL) throws -> String {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if url.pathExtension.caseInsensitiveCompare("pdf") == .orderedSame {
            return try readPDFText(from: url)
        }

        let data = try Data(contentsOf: url)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        if let text = String(data: data, encoding: .utf16) {
            return text
        }

        throw ImportHandoffError.unsupportedTextEncoding
    }

    static func readDocument(from url: URL) throws -> ArcPlanDocument? {
        guard url.pathExtension.caseInsensitiveCompare("arcguide") == .orderedSame else {
            return nil
        }

        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try ArcDocumentCodec.decodePlanOrGuide(from: Data(contentsOf: url))
    }

    private static func readPDFText(from url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ImportHandoffError.unreadablePDF
        }

        let pages = (0 ..< document.pageCount)
            .compactMap { document.page(at: $0)?.string?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !pages.isEmpty else {
            throw ImportHandoffError.pdfHasNoTextLayer
        }

        return pages.joined(separator: "\n\n")
    }
}

nonisolated enum ImportHandoffError: LocalizedError {
    case unsupportedTextEncoding
    case unreadablePDF
    case pdfHasNoTextLayer

    var errorDescription: String? {
        switch self {
        case .unsupportedTextEncoding:
            return "Arc could not read that file as text."
        case .unreadablePDF:
            return "Arc could not open that PDF."
        case .pdfHasNoTextLayer:
            return "That PDF does not contain selectable text yet. Export the note as Markdown or plain text."
        }
    }
}
