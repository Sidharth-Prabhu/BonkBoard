//
//  AboutPanelController.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import SwiftUI
import AppKit

final class AboutPanelController {

    static let shared = AboutPanelController()
    private var panel: NSPanel?

    func show() {
        if panel == nil {
            let hostingView = NSHostingView(rootView: AboutView())

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )

            panel.center()
            panel.title = "About BonkBoard"
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.fullScreenAuxiliary]
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true

            // 🔥 macOS native blur look
            let visualEffect = NSVisualEffectView()
            visualEffect.material = .hudWindow
            visualEffect.state = .active
            visualEffect.blendingMode = .behindWindow

            hostingView.translatesAutoresizingMaskIntoConstraints = false
            visualEffect.addSubview(hostingView)

            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
                hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor)
            ])

            panel.contentView = visualEffect

            self.panel = panel
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
