import AppKit
import Foundation

enum ClickTargetMode: String, CaseIterable, Identifiable, Sendable {
    case cursor
    case fixedPoint

    var id: String { rawValue }
}

struct RunningApplicationOption: Identifiable, Hashable, Sendable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }

    @MainActor
    static func processIdentifier(forBundleIdentifier bundleIdentifier: String) -> pid_t? {
        guard !bundleIdentifier.isEmpty else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleIdentifier == bundleIdentifier && !$0.isTerminated
        }?.processIdentifier
    }

    /// Ứng dụng đang chạy có giao diện, bỏ chính Auto Click ra.
    @MainActor
    static func current() -> [RunningApplicationOption] {
        var seenBundleIdentifiers = Set<String>()
        return NSWorkspace.shared.runningApplications
            .filter { application in
                application.activationPolicy == .regular
                    && !application.isTerminated
                    && application.processIdentifier != ProcessInfo.processInfo.processIdentifier
                    && application.bundleIdentifier != nil
            }
            .compactMap { application -> RunningApplicationOption? in
                guard let bundleIdentifier = application.bundleIdentifier,
                      seenBundleIdentifiers.insert(bundleIdentifier).inserted else { return nil }
                return RunningApplicationOption(
                    bundleIdentifier: bundleIdentifier,
                    name: application.localizedName ?? bundleIdentifier
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

enum ApplicationLockValidationError: LocalizedError, Equatable {
    case missingSelection
    case applicationNotRunning

    var errorDescription: String? {
        switch self {
        case .missingSelection:
            return "Hãy chọn ứng dụng cần khóa."
        case .applicationNotRunning:
            return "Ứng dụng đã chọn hiện không chạy."
        }
    }
}

enum ApplicationLockValidator {
    static func validate(
        isEnabled: Bool,
        selectedBundleIdentifier: String,
        isApplicationRunning: Bool
    ) -> ApplicationLockValidationError? {
        guard isEnabled else { return nil }
        guard !selectedBundleIdentifier.isEmpty else { return .missingSelection }
        guard isApplicationRunning else { return .applicationNotRunning }
        return nil
    }
}

struct AutoClickSettings: Equatable, Sendable {
    let intervalMilliseconds: Int
    let repeatCount: Int
}

enum SettingsValidationError: LocalizedError, Equatable {
    case invalidInterval
    case intervalOutOfRange
    case invalidRepeatCount
    case repeatCountOutOfRange

    var errorDescription: String? {
        switch self {
        case .invalidInterval:
            return "Interval phải là số nguyên."
        case .intervalOutOfRange:
            return "Interval phải từ 10 đến 3.600.000 ms."
        case .invalidRepeatCount:
            return "Repeat phải là số nguyên."
        case .repeatCountOutOfRange:
            return "Repeat phải từ 1 đến 1.000.000."
        }
    }
}

enum SettingsValidator {
    static func validate(
        intervalText: String,
        repeatText: String
    ) -> Result<AutoClickSettings, SettingsValidationError> {
        guard let interval = Int(intervalText) else {
            return .failure(.invalidInterval)
        }
        guard (10...3_600_000).contains(interval) else {
            return .failure(.intervalOutOfRange)
        }
        guard let repeatCount = Int(repeatText) else {
            return .failure(.invalidRepeatCount)
        }
        guard (1...1_000_000).contains(repeatCount) else {
            return .failure(.repeatCountOutOfRange)
        }

        return .success(
            AutoClickSettings(
                intervalMilliseconds: interval,
                repeatCount: repeatCount
            )
        )
    }
}
