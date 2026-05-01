//
//  ActionRunner.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class ActionRunner: ObservableObject {
    @Published private(set) var lastActionText = "No action run yet"

    private var lastRunByAction: [KnockAction: Date] = [:]

    func run(_ action: KnockAction, settings: AppSettings) {
        guard canRun(action) else {
            lastActionText = "Ignored repeated \(action.title)"
            return
        }

        lastActionText = action.title

        if settings.soundFeedback, action.allowsFeedbackSound {
            playFeedbackSound()
        }

        switch action {
        case .none:
            lastActionText = "No action"
        case .mute:
            sendSystemKey(7)
        case .volumeDown:
            sendSystemKey(1)
        case .volumeUp:
            sendSystemKey(0)
        case .playPause:
            sendSystemKey(16, keyUpDelay: 0.08)
        case .nextDesktop:
            sendKey(.rightArrow, modifiers: [.maskControl])
        case .previousDesktop:
            sendKey(.leftArrow, modifiers: [.maskControl])
        case .missionControl:
            sendKey(.upArrow, modifiers: [.maskControl])
        case .nextTab:
            sendKey(.rightBracket, modifiers: [.maskCommand, .maskShift])
        case .previousTab:
            sendKey(.leftBracket, modifiers: [.maskCommand, .maskShift])
        case .copy:
            sendKey(.c, modifiers: [.maskCommand])
        case .paste:
            sendKey(.v, modifiers: [.maskCommand])
        case .undo:
            sendKey(.z, modifiers: [.maskCommand])
        case .redo:
            sendKey(.z, modifiers: [.maskCommand, .maskShift])
        case .spotlight:
            sendKey(.space, modifiers: [.maskCommand])
        case .appSwitcher:
            sendKey(.tab, modifiers: [.maskCommand])
        case .closeWindow:
            sendKey(.w, modifiers: [.maskCommand])
        case .screenshot:
            sendKey(.five, modifiers: [.maskCommand, .maskShift])
        case .lockScreen:
            sendKey(.q, modifiers: [.maskCommand, .maskControl])
        case .sleepMac:
            runAppleScript("tell application \"System Events\" to sleep")
        case .openFinder:
            openBundle(identifier: "com.apple.finder", fallbackName: "Finder")
        case .openTerminal:
            openBundle(identifier: "com.apple.Terminal", fallbackName: "Terminal")
        case .openApp:
            openApp(named: settings.appName)
        case .runShortcut:
            runShortcut(named: settings.shortcutName)
        case .runCustomCommand:
            runCustomCommand(settings.customCommand)
        }
    }

    private func canRun(_ action: KnockAction) -> Bool {
        let now = Date()
        let minimumInterval: TimeInterval

        switch action {
        case .playPause, .mute, .volumeDown, .volumeUp:
            minimumInterval = 0.7
        default:
            minimumInterval = 0.2
        }

        if let lastRun = lastRunByAction[action],
           now.timeIntervalSince(lastRun) < minimumInterval {
            return false
        }

        lastRunByAction[action] = now
        return true
    }

    private func playFeedbackSound() {
        if let sound = NSSound(named: "Pop") ?? NSSound(named: "Funk") {
            sound.play()
        } else {
            NSSound.beep()
        }
    }

    private func openBundle(identifier: String, fallbackName: String) {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            NSWorkspace.shared.open(url)
        } else {
            openApp(named: fallbackName)
        }
    }

    private func openApp(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastActionText = "Missing app name"
            return
        }

        let candidateURLs = [
            URL(fileURLWithPath: "/Applications/\(trimmed).app"),
            URL(fileURLWithPath: "/System/Applications/\(trimmed).app"),
            URL(fileURLWithPath: "/System/Applications/Utilities/\(trimmed).app")
        ]

        if let url = candidateURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            NSWorkspace.shared.open(url)
        } else {
            lastActionText = "Could not find \(trimmed).app"
        }
    }

    private func runShortcut(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastActionText = "Missing shortcut name"
            return
        }

        runProcess("/usr/bin/shortcuts", arguments: ["run", trimmed])
    }

    private func runCustomCommand(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastActionText = "Missing command"
            return
        }

        runProcess("/bin/zsh", arguments: ["-lc", trimmed])
    }

    private func runAppleScript(_ source: String) {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)

        if let error {
            lastActionText = error.description
        }
    }

    private func runProcess(_ executable: String, arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        do {
            try process.run()
        } catch {
            lastActionText = error.localizedDescription
        }
    }

    private func sendSystemKey(_ keyCode: Int, keyUpDelay: TimeInterval = 0.02) {
        requestAccessibilityIfNeeded()

        let keyDown = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: 0xa00),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: (keyCode << 16) | (0xa << 8),
            data2: -1
        )?.cgEvent

        keyDown?.post(tap: .cghidEventTap)

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(keyUpDelay))

            let keyUp = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: 0xb00),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: (keyCode << 16) | (0xb << 8),
                data2: -1
            )?.cgEvent

            keyUp?.post(tap: .cghidEventTap)
        }
    }

    private func sendKey(_ key: KeyCode, modifiers: CGEventFlags = []) {
        requestAccessibilityIfNeeded()

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key.rawValue, keyDown: false)

        keyDown?.flags = modifiers
        keyUp?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }

        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        lastActionText = "Accessibility permission required for keyboard actions"
    }
}

private enum KeyCode: CGKeyCode {
    case a = 0
    case c = 8
    case v = 9
    case w = 13
    case q = 12
    case z = 6
    case five = 23
    case rightBracket = 30
    case leftBracket = 33
    case tab = 48
    case space = 49
    case leftArrow = 123
    case rightArrow = 124
    case upArrow = 126
}

private extension KnockAction {
    var allowsFeedbackSound: Bool {
        switch self {
        case .playPause, .mute, .volumeDown, .volumeUp:
            false
        default:
            true
        }
    }
}
