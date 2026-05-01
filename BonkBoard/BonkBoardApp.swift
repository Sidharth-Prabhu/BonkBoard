//
//  BonkBoardApp.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import SwiftUI

@main
struct BonkBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = BonkBoardController()

    var body: some Scene {
        WindowGroup("BonkBoard", id: "settings") {
            ContentView(controller: controller)
                .task {
                    controller.start()
                }
                .onAppear {
                    NSApp.keyWindow?.identifier = NSUserInterfaceItemIdentifier("BonkBoardSettingsWindow")
                }
        }
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit BonkBoard") {
                    controller.quit()
                }
                .keyboardShortcut("q", modifiers: .command)
            }
        }

        MenuBarExtra("BonkBoard", systemImage: controller.settings.isEnabled ? "hand.tap.fill" : "hand.tap") {
            MenuBarControls(controller: controller)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

private struct MenuBarControls: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var controller: BonkBoardController
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var impactMonitor: AppleSiliconImpactMonitor
    @ObservedObject private var gestureCoordinator: KnockGestureCoordinator
    @ObservedObject private var actionRunner: ActionRunner

    init(controller: BonkBoardController) {
        self.controller = controller
        settings = controller.settings
        impactMonitor = controller.impactMonitor
        gestureCoordinator = controller.gestureCoordinator
        actionRunner = controller.actionRunner
    }

    var body: some View {
        Toggle("Enabled", isOn: $settings.isEnabled)
        Toggle("Sound Feedback", isOn: $settings.soundFeedback)

        Divider()

        Button("Open BonkBoard Settings") {
            controller.activateApp()
            openWindow(id: "settings")
        }

        Picker("Tap Speed", selection: $settings.tapSpeed) {
            ForEach(TapSpeed.allCases) { speed in
                Text(speed.title).tag(speed)
            }
        }

        Picker("Hold Key", selection: $settings.holdKey) {
            ForEach(HoldKey.allCases) { key in
                Text(key.title).tag(key)
            }
        }

        Divider()

        Text(impactMonitor.impactDetected ? "Impact detected" : impactMonitor.statusText)
        Text("\(gestureCoordinator.lastGestureText) | \(actionRunner.lastActionText)")
        Text(String(format: "Spike %.3fg | Threshold %.3fg", impactMonitor.latestSpike, settings.impactThreshold))

        Divider()

        Button("Quit BonkBoard") {
            controller.quit()
        }
    }
}
