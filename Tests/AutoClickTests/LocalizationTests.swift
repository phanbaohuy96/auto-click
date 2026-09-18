import Foundation
import Testing
@testable import AutoClick

/// The `.lproj` directories as they sit in the repository.
///
/// `Bundle.main` is the app in production and the `xctest` runner here, so the container has to be injected.
/// Note what is **not** used: `Bundle.module`. `LC-4` and [ADR-0010] record that SwiftPM's accessor falls back
/// to an absolute path into the build machine's `.build/`, which works here and crashes everywhere else.
@MainActor
enum Catalogs {
    static let directory = URL(filePath: #filePath)
        .deletingLastPathComponent()   // AutoClickTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repository root
        .appending(path: "Resources")

    static func container() throws -> Bundle {
        try #require(Bundle(path: directory.path()), "no bundle at \(directory.path())")
    }

    /// Pins the global `Localization.current` to English, once, for the whole test run.
    ///
    /// Tests run in parallel, so the global is never *switched* during a run — a test that needs another
    /// language builds its own instance instead. Without pinning, `Localization.current` would be reading
    /// `Bundle.main`, which under `swift test` is the xctest runner and carries no catalogue at all.
    static let pinnedToEnglish: Void = {
        // Deliberately no `#require` here: this runs inside a lazy global initialiser that the first test to
        // touch it triggers, which is not a place an expectation belongs.
        guard let container = Bundle(path: directory.path()) else {
            fatalError("no catalogue directory at \(directory.path())")
        }
        let localization = Localization(
            container: container,
            defaults: UserDefaults(suiteName: "AutoClickPinned-\(UUID().uuidString)")!
        )
        localization.select("en")
        Localization.current = localization
    }()

    static func localization(preference: String? = nil) throws -> Localization {
        let defaults = UserDefaults(suiteName: "AutoClickLocalization-\(UUID().uuidString)")!
        let localization = Localization(container: try container(), defaults: defaults)
        if let preference { localization.select(preference) }
        return localization
    }
}

/// `LC-15`: the completeness rule is **asymmetric** on purpose.
@MainActor
struct CatalogCompletenessTests {
    /// `en` is the source of truth and the target every other language falls back to, so a gap here is a gap
    /// with nothing behind it.
    @Test func everyKeyIsTranslatedIntoEnglish() throws {
        let localization = try Catalogs.localization()
        let missing = StringKey.allCases.filter { !localization.hasOwnTranslation(of: $0, in: "en") }
        #expect(missing.isEmpty, "en.lproj is missing: \(missing.map(\.rawValue).sorted())")
    }

    /// `vi` is the only language besides `en` with a reviewer, so it is held to the same standard.
    @Test func everyKeyIsTranslatedIntoVietnamese() throws {
        let localization = try Catalogs.localization()
        let missing = StringKey.allCases.filter { !localization.hasOwnTranslation(of: $0, in: "vi") }
        #expect(missing.isEmpty, "vi.lproj is missing: \(missing.map(\.rawValue).sorted())")
    }

    /// The machine-translated languages **report** their coverage and never fail.
    ///
    /// Holding them to the same standard would turn the build red every time a label is added, until it had
    /// been machine-translated into three languages nobody here can check — and it would contradict `LC-7`,
    /// which exists so that a partial translation is a safe thing to ship.
    @Test func theMachineTranslatedLanguagesOnlyReportCoverage() throws {
        let localization = try Catalogs.localization()
        for code in ["zh-Hans", "ja", "es"] {
            let covered = StringKey.allCases.count { localization.hasOwnTranslation(of: $0, in: code) }
            print("localisation coverage — \(code): \(covered)/\(StringKey.allCases.count)")
        }
    }

    /// `LC-16`: a key left in the catalogue after its last use is dead weight translators keep paying for.
    @Test func englishDeclaresNoKeyTheInterfaceNoLongerUses() throws {
        let localization = try Catalogs.localization()
        let used = Set(StringKey.allCases.map(\.rawValue))
        let orphans = localization.declaredKeys(in: "en").subtracting(used)
        #expect(orphans.isEmpty, "en.lproj declares unused keys: \(orphans.sorted())")
    }
}

/// `LC-5`…`LC-7`: choosing a language, and what happens where a translation runs out.
@MainActor
struct LanguageSelectionTests {
    @Test func switchingLanguageChangesTheStringsWithNoRelaunch() throws {
        let localization = try Catalogs.localization(preference: "en")
        #expect(localization(.menuQuit) == "Quit")

        localization.select("vi")

        #expect(localization.code == "vi")
        #expect(localization(.menuQuit) == "Thoát")
    }

    /// The whole reason this type holds its own bundle. Asking `Bundle.main` instead would answer with the
    /// language chosen when the process started, however many times the preference changed since.
    @Test func switchingBackAgainIsAlsoImmediate() throws {
        let localization = try Catalogs.localization(preference: "vi")
        localization.select("en")
        #expect(localization(.menuQuit) == "Quit")
    }

    @Test func anUnsupportedPreferenceFallsBackToTheDevelopmentLanguage() throws {
        let localization = try Catalogs.localization(preference: "kl")
        #expect(localization.code == Localization.developmentCode)
    }

    /// `LC-5`: an unset preference is not "English", it is "whatever the system negotiated".
    @Test func anUnsetPreferenceIsNotStored() throws {
        let localization = try Catalogs.localization(preference: "vi")
        #expect(localization.preference == "vi")

        localization.select(nil)

        #expect(localization.preference == nil)
        #expect(Localization.supportedCodes.contains(localization.code))
    }

    /// `LC-7`. The failure this guards against only ever appears in a language the author cannot read, which
    /// is why it is a test and not an eyeball check.
    @Test func aMissingTranslationFallsBackToEnglishRatherThanShowingTheKey() throws {
        let root = URL(filePath: NSTemporaryDirectory())
            .appending(path: "AutoClickCatalog-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }

        for (code, body) in [
            ("en", "\"menu.quit\" = \"Quit\";\n\"menu.mode.label\" = \"Mode\";\n"),
            ("ja", "\"menu.quit\" = \"終了\";\n")   // deliberately missing menu.mode.label
        ] {
            let directory = root.appending(path: "\(code).lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data(body.utf8).write(to: directory.appending(path: "Localizable.strings"))
        }

        let container = try #require(Bundle(path: root.path()))
        let localization = Localization(
            container: container,
            defaults: UserDefaults(suiteName: "AutoClickGap-\(UUID().uuidString)")!
        )
        localization.select("ja")

        #expect(localization(.menuQuit) == "終了")
        #expect(localization(.menuModeLabel) == "Mode", "a gap must reach en, not the raw key")
        #expect(localization(.menuModeLabel) != "menu.mode.label")
    }
}
