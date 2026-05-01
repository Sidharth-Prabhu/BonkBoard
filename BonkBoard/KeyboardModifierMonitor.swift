//
//  KeyboardModifierMonitor.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import AppKit
import Combine

@MainActor
final class KeyboardModifierMonitor: ObservableObject {
    @Published private(set) var flags: NSEvent.ModifierFlags = []

    private var localMonitor: Any?
    private var globalMonitor: Any?

    func start() {
        guard localMonitor == nil, globalMonitor == nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.flags = event.modifierFlags
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in
                self?.flags = event.modifierFlags
            }
        }
    }

    func stop() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }

        localMonitor = nil
        globalMonitor = nil
    }

    func isSatisfied(_ holdKey: HoldKey) -> Bool {
        switch holdKey {
        case .none:
            true
        case .command:
            flags.contains(.command)
        case .option:
            flags.contains(.option)
        case .control:
            flags.contains(.control)
        case .shift:
            flags.contains(.shift)
        case .function:
            flags.contains(.function)
        }
    }

    deinit {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
    }
}
