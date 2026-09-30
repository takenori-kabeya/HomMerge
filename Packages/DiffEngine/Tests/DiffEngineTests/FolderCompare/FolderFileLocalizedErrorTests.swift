import Foundation
import Testing
@testable import DiffEngine

@Suite("Folder file LocalizedError catalogs")
struct FolderFileLocalizedErrorTests {
    @Test("Copy errors resolve English and Japanese catalog values")
    func copyErrorsHaveEnglishAndJapaneseCatalogEntries() throws {
        let catalog = try loadCatalog()
        let keys = [
            "The source file could not be found.",
            "The source path is not a file.",
            "The destination file already exists.",
        ]
        for key in keys {
            #expect(catalogValue(catalog, key: key, locale: "en") == key)
            #expect(!catalogValue(catalog, key: key, locale: "ja").isEmpty)
        }
    }

    @Test("Trash errors resolve English and Japanese catalog values")
    func trashErrorsHaveEnglishAndJapaneseCatalogEntries() throws {
        let catalog = try loadCatalog()
        let key = "The file could not be found."
        #expect(catalogValue(catalog, key: key, locale: "en") == key)
        #expect(!catalogValue(catalog, key: key, locale: "ja").isEmpty)
    }

    @Test("Copy errorDescription uses localized source strings")
    func copyErrorDescriptionMatchesLocalizedSource() {
        #expect(
            FolderFileCopy.Error.sourceMissing.errorDescription
                == String(localized: "The source file could not be found.", bundle: .module)
        )
        #expect(
            FolderFileCopy.Error.sourceNotFile.errorDescription
                == String(localized: "The source path is not a file.", bundle: .module)
        )
        #expect(
            FolderFileCopy.Error.destinationExists.errorDescription
                == String(localized: "The destination file already exists.", bundle: .module)
        )
    }

    @Test("Trash errorDescription uses localized source strings")
    func trashErrorDescriptionMatchesLocalizedSource() {
        #expect(
            FolderFileTrash.Error.missing.errorDescription
                == String(localized: "The file could not be found.", bundle: .module)
        )
    }

    private func loadCatalog() throws -> [String: Any] {
        let url = repositoryRoot()
            .appendingPathComponent(
                "Packages/DiffEngine/Sources/DiffEngine/Resources/Localizable.xcstrings"
            )
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let catalog = object as? [String: Any] else {
            Issue.record("Catalog JSON root must be an object")
            return [:]
        }
        return catalog
    }

    private func catalogValue(_ catalog: [String: Any], key: String, locale: String) -> String {
        guard
            let strings = catalog["strings"] as? [String: Any],
            let entry = strings[key] as? [String: Any],
            let localizations = entry["localizations"] as? [String: Any],
            let localeEntry = localizations[locale] as? [String: Any],
            let stringUnit = localeEntry["stringUnit"] as? [String: Any],
            let value = stringUnit["value"] as? String
        else {
            return ""
        }
        return value
    }

    private func repositoryRoot() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.pathComponents.count > 1 {
            let candidate = url.appendingPathComponent("project.yml")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
