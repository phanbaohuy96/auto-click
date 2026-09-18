import Foundation

/// The active **Interface language**, and the lookup that goes with it (`LC-1`…`LC-8`).
///
/// Reading is done through an explicitly loaded `<code>.lproj` sub-bundle rather than through
/// `Bundle.main`, and that is the whole reason this type exists. `Bundle.main` resolves its language **once
/// per process and caches it**: writing `AppleLanguages` into our own defaults domain mid-process leaves
/// `preferredLocalizations` at its launch value and every string unchanged. Holding the bundle ourselves is
/// what makes `LC-6` — switching with no relaunch — possible at all. See [ADR-0010].
@MainActor
final class Localization: ObservableObject {
    /// `LC-1`. `en` is first because it is the development language and the fallback target.
    static let supportedCodes = ["en", "vi", "zh-Hans", "ja", "es"]
    static let developmentCode = "en"

    static let preferenceKey = "interfaceLanguage"

    /// LC-8: each language written **in its own language**, and deliberately not a `StringKey`.
    ///
    /// Someone who picked `日本語` by accident has to find the way back while unable to read anything else on
    /// screen. Translating this list would show them *"ベトナム語"* where they are looking for *"Tiếng Việt"*.
    static func nativeName(of code: String) -> String {
        switch code {
        case "en": return "English"
        case "vi": return "Tiếng Việt"
        case "zh-Hans": return "中文（简体）"
        case "ja": return "日本語"
        case "es": return "Español"
        default: return code
        }
    }

    /// The instance non-view code reads from.
    ///
    /// A mutable global, in a codebase that otherwise injects its seams. It is unavoidable:
    /// `LocalizedError.errorDescription` is a protocol property taking no arguments, so a validator has no
    /// way to be handed a bundle. It is settable so tests can pin it. [ADR-0010] records the cost.
    static var current = Localization()

    /// The active language code — always one of `supportedCodes`.
    @Published private(set) var code: String
    /// The stored preference: `nil` means **follow the system** (`LC-5`).
    @Published private(set) var preference: String?

    private let container: Bundle
    private let defaults: UserDefaults
    private var active: Bundle
    private let fallback: Bundle

    /// A value no translation can equal, used to tell "missing" apart from "translated to this" (`LC-7`).
    private static let missing = "\u{0}AutoClick.missing"

    /// - Parameter container: the bundle holding the `.lproj` directories. `Bundle.main` in the app, where
    ///   `build-app.sh` puts them in `Contents/Resources`; a plain directory in tests. Never a SwiftPM
    ///   resource bundle — `LC-4` explains why `Bundle.module` must not appear in this module.
    init(container: Bundle = .main, defaults: UserDefaults = .standard) {
        self.container = container
        self.defaults = defaults
        let stored = defaults.string(forKey: Self.preferenceKey)
        let resolved = Self.resolve(preference: stored, container: container)
        self.preference = stored
        self.code = resolved
        self.fallback = Self.bundle(for: Self.developmentCode, in: container) ?? container
        self.active = Self.bundle(for: resolved, in: container) ?? self.fallback
    }

    // MARK: - Choosing

    /// `LC-5`, `LC-6`. `nil` follows the system. Takes effect immediately; nothing is relaunched.
    func select(_ preference: String?) {
        let resolved = Self.resolve(preference: preference, container: container)
        if let preference {
            defaults.set(preference, forKey: Self.preferenceKey)
        } else {
            defaults.removeObject(forKey: Self.preferenceKey)
        }
        self.preference = preference
        active = Self.bundle(for: resolved, in: container) ?? fallback
        // Published last: SwiftUI redraws on this, and by then the bundle is already in place.
        code = resolved
    }

    /// `LC-5`: an unset preference goes through `Bundle.main.preferredLocalizations`, which has already done
    /// Apple's own negotiation — on a machine set to `en-VN` it answers `en`.
    private static func resolve(preference: String?, container: Bundle) -> String {
        if let preference, supportedCodes.contains(preference) { return preference }
        for candidate in container.preferredLocalizations where supportedCodes.contains(candidate) {
            return candidate
        }
        return developmentCode
    }

    private static func bundle(for code: String, in container: Bundle) -> Bundle? {
        guard let path = container.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }

    // MARK: - Reading

    /// The translation of `key`, falling back to `en` and never to the raw key (`LC-7`).
    func callAsFunction(_ key: StringKey) -> String {
        let value = active.localizedString(forKey: key.rawValue, value: Self.missing, table: nil)
        guard value == Self.missing else { return value }
        // Foundation's own fallback chain belongs to `Bundle.main`; a sub-bundle asked for a key it does not
        // have hands back the key itself, so `editor.step.delay` would appear on screen. Hence the sentinel.
        return fallback.localizedString(forKey: key.rawValue, value: key.rawValue, table: nil)
    }

    /// A translation with arguments (`LC-9`, `LC-10`).
    ///
    /// The locale is the **active language**, not `Locale.current`: it drives both the plural rule chosen out
    /// of `Localizable.stringsdict` and the shape of the numbers. `String.localizedStringWithFormat` would
    /// take the process locale instead, so a Spanish interface on an English machine would count in English.
    func callAsFunction(_ key: StringKey, _ arguments: any CVarArg...) -> String {
        format(key, arguments)
    }

    func format(_ key: StringKey, _ arguments: [any CVarArg]) -> String {
        String(format: self(key), locale: Locale(identifier: code), arguments: arguments)
    }

    /// A number in the shape the **active language** writes it (`LC-9`).
    ///
    /// `vi` and `es` group with dots and separate decimals with a comma where `en` does the opposite. A limit
    /// written into the sentence instead would also go stale the moment `ScenarioLimits` changes.
    func number(_ value: Int) -> String {
        value.formatted(.number.locale(Locale(identifier: code)))
    }

    /// A decimal in the active language's shape (`LC-9`): `0.85` in `en`, `0,85` in `vi` and `es`.
    func decimal(_ value: Double, fractionDigits: Int = 2) -> String {
        value.formatted(
            .number.precision(.fractionLength(fractionDigits)).locale(Locale(identifier: code))
        )
    }

    /// Whether `code` has its own translation of `key`, rather than reaching the `en` fallback.
    ///
    /// Only the coverage test needs this (`LC-15`).
    func hasOwnTranslation(of key: StringKey, in code: String) -> Bool {
        guard let bundle = Self.bundle(for: code, in: container) else { return false }
        return bundle.localizedString(forKey: key.rawValue, value: Self.missing, table: nil) != Self.missing
    }

    /// Every key `<code>.lproj` declares, whether or not `StringKey` still uses it (`LC-16`).
    ///
    /// Both files count: Foundation merges `Localizable.strings` and `Localizable.stringsdict` into one
    /// table, so a key living in either of them is a key the catalogue declares.
    func declaredKeys(in code: String) -> Set<String> {
        guard let path = container.path(forResource: code, ofType: "lproj") else { return [] }
        let directory = URL(filePath: path)
        var keys = Set<String>()
        for file in ["Localizable.strings", "Localizable.stringsdict"] {
            guard let table = NSDictionary(contentsOf: directory.appending(path: file)) as? [String: Any]
            else { continue }
            keys.formUnion(table.keys)
        }
        return keys
    }
}

/// Reading a translation from a `nonisolated` context.
///
/// `LocalizedError.errorDescription` is a protocol requirement: it takes no arguments, so it cannot be handed
/// a bundle, and it cannot be declared `@MainActor` without breaking the conformance. So the hop is
/// **asserted** rather than awaited. That is sound here because every one of these strings exists to be put
/// on screen: it is built and read while drawing, on the main thread. [ADR-0010] records this as the price of
/// switching language without a relaunch.
nonisolated func localized(_ key: StringKey, _ arguments: any CVarArg...) -> String {
    // Only `String` and `Locale` cross the hop — an array of `any CVarArg` is not `Sendable`, so the
    // formatting itself is done out here, on the caller's side.
    let (format, locale) = MainActor.assumeIsolated {
        (Localization.current(key), Locale(identifier: Localization.current.code))
    }
    guard !arguments.isEmpty else { return format }
    return String(format: format, locale: locale, arguments: arguments)
}

/// A number in the active language's shape, from a `nonisolated` context. See `localized(_:_:)`.
nonisolated func localizedNumber(_ value: Int) -> String {
    MainActor.assumeIsolated { Localization.current.number(value) }
}

/// A decimal in the active language's shape, from a `nonisolated` context. See `localized(_:_:)`.
nonisolated func localizedDecimal(_ value: Double) -> String {
    MainActor.assumeIsolated { Localization.current.decimal(value) }
}
