import XCTest
@testable import HomMerge

/// Asserts String Catalogs ship complete English and Japanese entries for required keys.
final class LocalizationCatalogTests: XCTestCase {
    func testAppLocalizableCatalogContainsRequiredKeysInEnglishAndJapanese() throws {
        let catalog = try loadCatalog(relativePath: "HomMerge/Localizable.xcstrings")
        let requiredKeys = [
            "About HomMerge",
            "Compare",
            "Discard unsaved changes?",
            "Discard",
            "Cancel",
            "Copy →",
            "End User License Agreement (EULA)",
            "Open two folders to compare",
            "Move to Trash",
        ]
        assertCatalog(catalog, contains: requiredKeys, file: "Localizable.xcstrings")
    }

    func testInfoPlistCatalogContainsRequiredKeysInEnglishAndJapanese() throws {
        let catalog = try loadCatalog(relativePath: "HomMerge/InfoPlist.xcstrings")
        let requiredKeys = [
            "Any File",
        ]
        assertCatalog(catalog, contains: requiredKeys, file: "InfoPlist.xcstrings")
    }

    func testServicesMenuCatalogContainsRequiredKeysInEnglishAndJapanese() throws {
        let catalog = try loadCatalog(relativePath: "HomMerge/ServicesMenu.xcstrings")
        let requiredKeys = [
            "Compare with HomMerge",
        ]
        assertCatalog(catalog, contains: requiredKeys, file: "ServicesMenu.xcstrings")
    }

    func testDiffEngineLocalizableCatalogContainsRequiredKeysInEnglishAndJapanese() throws {
        let catalog = try loadCatalog(
            relativePath: "Packages/DiffEngine/Sources/DiffEngine/Resources/Localizable.xcstrings"
        )
        let requiredKeys = [
            "The source file could not be found.",
            "The source path is not a file.",
            "The destination file already exists.",
            "The file could not be found.",
            "Left",
            "Right",
        ]
        assertCatalog(catalog, contains: requiredKeys, file: "DiffEngine Localizable.xcstrings")
    }

    func testToolbarTitlesResolveThroughLocalization() {
        let appBundle = Bundle(for: AppViewModel.self)
        XCTAssertEqual(
            FileCompareToolbarItem.copyRight.title,
            String(localized: "Copy →", bundle: appBundle)
        )
        // Locale-specific values are asserted via Localizable.xcstrings JSON in other tests.
        // String(localized:locale:) does not reliably override the process preferred language.
    }

    // MARK: - Helpers

    private func loadCatalog(relativePath: String) throws -> [String: Any] {
        let url = repositoryRoot().appendingPathComponent(relativePath)
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let catalog = object as? [String: Any] else {
            XCTFail("Catalog JSON root must be an object: \(relativePath)")
            return [:]
        }
        return catalog
    }

    private func assertCatalog(
        _ catalog: [String: Any],
        contains keys: [String],
        file: String
    ) {
        guard let strings = catalog["strings"] as? [String: Any] else {
            XCTFail("\(file) is missing a strings dictionary")
            return
        }

        for key in keys {
            guard let entry = strings[key] as? [String: Any] else {
                XCTFail("\(file) is missing key: \(key)")
                continue
            }
            guard let localizations = entry["localizations"] as? [String: Any] else {
                XCTFail("\(file) key \(key) is missing localizations")
                continue
            }
            XCTAssertFalse(
                localizationValue(in: localizations, locale: "en").isEmpty,
                "\(file) key \(key) must have a non-empty en value"
            )
            XCTAssertFalse(
                localizationValue(in: localizations, locale: "ja").isEmpty,
                "\(file) key \(key) must have a non-empty ja value"
            )
        }
    }

    private func localizationValue(in localizations: [String: Any], locale: String) -> String {
        guard
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
    }
}
