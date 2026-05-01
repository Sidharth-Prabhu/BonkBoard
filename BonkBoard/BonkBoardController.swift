//
//  BonkBoardController.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import AppKit
import Combine
import ServiceManagement

@MainActor
final class BonkBoardController: ObservableObject {
    let settings = AppSettings()
    let impactMonitor = AppleSiliconImpactMonitor()
    let keyboardMonitor = KeyboardModifierMonitor()
    let gestureCoordinator = KnockGestureCoordinator()
    let actionRunner = ActionRunner()

    @Published private(set) var appMessage = ""

    private var cancellables: Set<AnyCancellable> = []
    private var hasStarted = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        keyboardMonitor.start()
        applyDockVisibility(settings.showInDock)
        impactMonitor.updateImpactThreshold(settings.impactThreshold)

        if settings.isEnabled {
            impactMonitor.start()
        }

        settings.$isEnabled
            .removeDuplicates()
            .sink { [weak self] isEnabled in
                guard let self else { return }
                isEnabled ? self.impactMonitor.start() : self.impactMonitor.stop()
            }
            .store(in: &cancellables)

        settings.$sensitivity
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                self.impactMonitor.updateImpactThreshold(self.settings.impactThreshold)
            }
            .store(in: &cancellables)

        settings.$launchAtLogin
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] launchAtLogin in
                self?.setLaunchAtLogin(launchAtLogin)
            }
            .store(in: &cancellables)

        settings.$showInDock
            .removeDuplicates()
            .sink { [weak self] showInDock in
                self?.applyDockVisibility(showInDock)
            }
            .store(in: &cancellables)

        impactMonitor.$impactEventID
            .removeDuplicates()
            .sink { [weak self] eventID in
                guard let self, eventID > 0 else { return }

                self.gestureCoordinator.registerKnock(
                    settings: self.settings,
                    keyboard: self.keyboardMonitor,
                    actionRunner: self.actionRunner
                )
            }
            .store(in: &cancellables)
    }

    func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettingsWindow() {
        activateApp()

        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "BonkBoardSettingsWindow" }) {
            window.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func quit() {
        impactMonitor.stop()
        keyboardMonitor.stop()
        NSApp.terminate(nil)
    }

    private func setLaunchAtLogin(_ launchAtLogin: Bool) {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
                appMessage = "BonkBoard will launch at login."
            } else {
                try SMAppService.mainApp.unregister()
                appMessage = "Launch at login disabled."
            }
        } catch {
            settings.launchAtLogin.toggle()
            appMessage = error.localizedDescription
        }
    }

    private func applyDockVisibility(_ showInDock: Bool) {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }
}
