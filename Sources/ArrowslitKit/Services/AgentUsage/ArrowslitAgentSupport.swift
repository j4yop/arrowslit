// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
//
// Compatibility layer for the Vorssaint AI-usage reader ported into Arrowslit.
// The reader itself is unchanged; this file supplies the small amount of
// app-level configuration it expects.

import Foundation

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}

enum DefaultsKey {
    static let notchAgentsClaudeProfile = "arrowslit.agents.claudeProfile"
    static let notchAgentsCodexProfiles = "arrowslit.agents.codexProfiles"
}

/// Small, owner-only cache used by the AI reader for its archive and price list.
enum PrivateFileStore {
    static var containerURL: URL? {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bundle = Bundle.main.bundleIdentifier ?? "com.j4yop.arrowslit"
        return base.appendingPathComponent(bundle, isDirectory: true)
    }

    @discardableResult
    static func createDirectory(at url: URL, container: URL? = nil) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func write(_ data: Data, to url: URL) -> Bool {
        do {
            try data.write(to: url, options: [.atomic])
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            return false
        }
    }
}

/// The reader's small set of app-level knobs. Arrowslit enables the section
/// whenever the AI page is visible; the settings toggles live in the page.
enum NotchAgentSupport {
    static let idleTurn: TimeInterval = 10 * 60
    static let defaultLimitThreshold = 80.0
    static let finishMinimums: [TimeInterval] = [0, 30, 60, 120, 300]
    static let limitThresholds = [50.0, 75.0, 80.0, 90.0, 95.0]
    static let budgets = [0.0, 5, 10, 25, 50, 100, 250]

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: "arrowslit.agents.enabled") as? Bool ?? true
    }

    static func providers(in defaults: UserDefaults = .standard) -> [AgentProvider] {
        AgentProvider.allCases.filter { provider in
            defaults.object(forKey: "arrowslit.agents.provider.\(provider.rawValue)") as? Bool ?? true
        }
    }

    static func showsCodexAccounts(in defaults: UserDefaults = .standard) -> Bool {
        false
    }

    static func dailyBudget(in defaults: UserDefaults = .standard) -> Double? {
        let value = defaults.double(forKey: "arrowslit.agents.dailyBudget")
        return value > 0 ? value : nil
    }

    static func finishMinimum(in defaults: UserDefaults = .standard) -> TimeInterval? {
        let value = defaults.object(forKey: "arrowslit.agents.finishMinimum") as? Double ?? 60
        return value > 0 ? value : nil
    }

    static func limitThreshold(in defaults: UserDefaults = .standard) -> Double? {
        let value = defaults.object(forKey: "arrowslit.agents.limitThreshold") as? Double ?? defaultLimitThreshold
        return value > 0 ? value : nil
    }

    static func limitsInUse(pageShown: Bool) -> Bool {
        pageShown
    }

    /// Arrowslit ships a reviewed list inside the app and does not fetch a
    /// second copy from another project's repository.
    static func updatesPrices(in defaults: UserDefaults = .standard) -> Bool {
        false
    }
}

/// Minimal shell-environment helpers used by the Codex reader. Arrowslit has
/// no Homebrew manager, so the login shell's PATH is the only thing needed.
enum HomebrewEnvironment {
    static func loginShellExports(shellPath: String) -> [String: String] {
        ["PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"]
    }
}

enum HomebrewCommandBuilder {
    static var currentShellPath: String {
        ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    }
}
