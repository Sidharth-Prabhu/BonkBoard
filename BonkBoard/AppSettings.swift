//
//  AppSettings.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { save(isEnabled, for: Keys.isEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet { save(launchAtLogin, for: Keys.launchAtLogin) }
    }

    @Published var soundFeedback: Bool {
        didSet { save(soundFeedback, for: Keys.soundFeedback) }
    }

    @Published var showInDock: Bool {
        didSet { save(showInDock, for: Keys.showInDock) }
    }

    @Published var sensitivity: Double {
        didSet { save(sensitivity, for: Keys.sensitivity) }
    }

    @Published var tapSpeed: TapSpeed {
        didSet { save(tapSpeed.rawValue, for: Keys.tapSpeed) }
    }

    @Published var holdKey: HoldKey {
        didSet { save(holdKey.rawValue, for: Keys.holdKey) }
    }

    @Published var singleKnockAction: KnockAction {
        didSet { save(singleKnockAction.rawValue, for: Keys.singleKnockAction) }
    }

    @Published var doubleKnockAction: KnockAction {
        didSet { save(doubleKnockAction.rawValue, for: Keys.doubleKnockAction) }
    }

    @Published var tripleKnockAction: KnockAction {
        didSet { save(tripleKnockAction.rawValue, for: Keys.tripleKnockAction) }
    }

    @Published var shortcutName: String {
        didSet { save(shortcutName, for: Keys.shortcutName) }
    }

    @Published var appName: String {
        didSet { save(appName, for: Keys.appName) }
    }

    @Published var customCommand: String {
        didSet { save(customCommand, for: Keys.customCommand) }
    }

    var impactThreshold: Double {
        let clamped = min(max(sensitivity, 0), 1)
        return 0.18 - (clamped * 0.155)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        soundFeedback = defaults.object(forKey: Keys.soundFeedback) as? Bool ?? true
        showInDock = defaults.object(forKey: Keys.showInDock) as? Bool ?? true
        sensitivity = defaults.object(forKey: Keys.sensitivity) as? Double ?? 0.82
        tapSpeed = TapSpeed(rawValue: defaults.string(forKey: Keys.tapSpeed) ?? "") ?? .balanced
        holdKey = HoldKey(rawValue: defaults.string(forKey: Keys.holdKey) ?? "") ?? .none
        singleKnockAction = KnockAction(rawValue: defaults.string(forKey: Keys.singleKnockAction) ?? "") ?? .playPause
        doubleKnockAction = KnockAction(rawValue: defaults.string(forKey: Keys.doubleKnockAction) ?? "") ?? .nextDesktop
        tripleKnockAction = KnockAction(rawValue: defaults.string(forKey: Keys.tripleKnockAction) ?? "") ?? .openFinder
        shortcutName = defaults.string(forKey: Keys.shortcutName) ?? ""
        appName = defaults.string(forKey: Keys.appName) ?? ""
        customCommand = defaults.string(forKey: Keys.customCommand) ?? ""
    }

    private let defaults: UserDefaults

    private func save(_ value: Any, for key: String) {
        defaults.set(value, forKey: key)
    }

    private enum Keys {
        static let isEnabled = "settings.isEnabled"
        static let launchAtLogin = "settings.launchAtLogin"
        static let soundFeedback = "settings.soundFeedback"
        static let showInDock = "settings.showInDock"
        static let sensitivity = "settings.sensitivity"
        static let tapSpeed = "settings.tapSpeed"
        static let holdKey = "settings.holdKey"
        static let singleKnockAction = "settings.singleKnockAction"
        static let doubleKnockAction = "settings.doubleKnockAction"
        static let tripleKnockAction = "settings.tripleKnockAction"
        static let shortcutName = "settings.shortcutName"
        static let appName = "settings.appName"
        static let customCommand = "settings.customCommand"
    }
}

enum TapSpeed: String, CaseIterable, Identifiable {
    case fast
    case balanced
    case relaxed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: "Fast (600ms)"
        case .balanced: "Balanced (900ms)"
        case .relaxed: "Relaxed (1200ms)"
        }
    }

    var interval: TimeInterval {
        switch self {
        case .fast: 0.6
        case .balanced: 0.9
        case .relaxed: 1.2
        }
    }
}

enum HoldKey: String, CaseIterable, Identifiable {
    case none
    case command
    case option
    case control
    case shift
    case function

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .command: "Command"
        case .option: "Option"
        case .control: "Control"
        case .shift: "Shift"
        case .function: "Fn"
        }
    }
}

enum KnockAction: String, CaseIterable, Identifiable {
    case mute
    case nextTab
    case previousTab
    case runShortcut
    case lockScreen
    case volumeUp
    case volumeDown
    case sleepMac
    case nextDesktop
    case previousDesktop
    case missionControl
    case playPause
    case screenshot
    case openFinder
    case openTerminal
    case openApp
    case runCustomCommand
    case copy
    case paste
    case undo
    case redo
    case spotlight
    case appSwitcher
    case closeWindow
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mute: "Mute"
        case .nextTab: "Next Tab"
        case .previousTab: "Previous Tab"
        case .runShortcut: "Run Shortcut..."
        case .lockScreen: "Lock Screen"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .sleepMac: "Sleep Mac"
        case .nextDesktop: "Next Desktop"
        case .previousDesktop: "Previous Desktop"
        case .missionControl: "Mission Control"
        case .playPause: "Play/Pause"
        case .screenshot: "Screenshot"
        case .openFinder: "Open Finder"
        case .openTerminal: "Open Terminal"
        case .openApp: "Open App..."
        case .runCustomCommand: "Run Custom Command..."
        case .copy: "Copy"
        case .paste: "Paste"
        case .undo: "Undo"
        case .redo: "Redo"
        case .spotlight: "Spotlight"
        case .appSwitcher: "App Switcher"
        case .closeWindow: "Close Window"
        case .none: "None"
        }
    }

    var needsShortcutName: Bool { self == .runShortcut }
    var needsAppName: Bool { self == .openApp }
    var needsCustomCommand: Bool { self == .runCustomCommand }
}
