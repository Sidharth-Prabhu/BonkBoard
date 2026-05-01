//
//  ContentView.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: BonkBoardController
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var impactMonitor: AppleSiliconImpactMonitor
    @ObservedObject private var gestureCoordinator: KnockGestureCoordinator
    @ObservedObject private var actionRunner: ActionRunner

    @State private var selectedSection = SettingsSection.general

    init(controller: BonkBoardController) {
        self.controller = controller
        settings = controller.settings
        impactMonitor = controller.impactMonitor
        gestureCoordinator = controller.gestureCoordinator
        actionRunner = controller.actionRunner
    }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(selectedSection: $selectedSection)

            Divider()
                .opacity(0)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    selectedContent
                    liveStatus
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(32)
            }
        }
        .frame(minWidth: 820, minHeight: 540)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .general:
            generalSettings
        case .detection:
            detectionSettings
        case .gestures:
            gestureSettings
        }
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "General", subtitle: "App behavior and launch options")

            SettingsToggle(title: "Enabled", isOn: $settings.isEnabled)
            SettingsToggle(title: "Launch at Login", isOn: $settings.launchAtLogin)
            SettingsToggle(title: "Sound Feedback", isOn: $settings.soundFeedback)
            SettingsToggle(title: "Show in Dock", isOn: $settings.showInDock)

            if !controller.appMessage.isEmpty {
                Text(controller.appMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var detectionSettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(title: "Detection", subtitle: "Sensitivity, timing, and hold key")

            VStack(alignment: .leading, spacing: 10) {
                Text("How much force is needed")
                    .font(.headline)

                HStack {
                    Text("Less sensitive")
                    Spacer()
                    Text("More sensitive")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                Slider(value: $settings.sensitivity, in: 0...1)
                    .tint(.blue)
            }

            PickerRow(title: "Tap Speed", selection: $settings.tapSpeed) {
                ForEach(TapSpeed.allCases) { speed in
                    Text(speed.title).tag(speed)
                }
            }

            Text("Tap Speed sets the gesture timing window for Mac body taps.")
                .font(.callout)
                .foregroundStyle(.secondary)

            PickerRow(title: "Hold key for Knock and Trackpad Tap Mode", selection: $settings.holdKey) {
                ForEach(HoldKey.allCases) { key in
                    Text(key.title).tag(key)
                }
            }

            Text("The selected hold key is used to arm Knock gestures. Choose None to allow knocks without a key.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var gestureSettings: some View {
        VStack(alignment: .leading, spacing: 22) {
            SectionHeader(title: "Gestures", subtitle: "Assign actions to Mac body knocks")

            ActionPicker(title: "Single Knock", selection: $settings.singleKnockAction)
            ActionPicker(title: "Double Knock", selection: $settings.doubleKnockAction)
            ActionPicker(title: "Triple Knock", selection: $settings.tripleKnockAction)

            actionConfigurationFields
        }
    }

    @ViewBuilder
    private var actionConfigurationFields: some View {
        let selectedActions = [
            settings.singleKnockAction,
            settings.doubleKnockAction,
            settings.tripleKnockAction
        ]

        if selectedActions.contains(where: \.needsShortcutName) {
            TextField("Shortcut name", text: $settings.shortcutName)
                .textFieldStyle(.roundedBorder)
        }

        if selectedActions.contains(where: \.needsAppName) {
            TextField("Application name, for example Safari", text: $settings.appName)
                .textFieldStyle(.roundedBorder)
        }

        if selectedActions.contains(where: \.needsCustomCommand) {
            TextField("Shell command", text: $settings.customCommand)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var liveStatus: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(impactMonitor.impactDetected ? Color.red : Color.green)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.6))
                    )

                Image(systemName: impactMonitor.impactDetected ? "exclamationmark.triangle.fill" : "waveform.path.ecg")
                    .foregroundStyle(impactMonitor.impactDetected ? .red : .blue)

                Text(impactMonitor.impactDetected ? "Impact detected" : impactMonitor.statusText)
                    .font(.system(size: 18, weight: .semibold))
            }

            Text("\(gestureCoordinator.lastGestureText)  •  \(actionRunner.lastActionText)")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let acceleration = impactMonitor.latestAcceleration {
                Text(String(format: "x %.2fg   y %.2fg   z %.2fg   spike %.3fg   threshold %.3fg",
                            acceleration.x,
                            acceleration.y,
                            acceleration.z,
                            impactMonitor.latestSpike,
                            settings.impactThreshold))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case detection
    case gestures

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .detection: "Detection"
        case .gestures: "Gestures"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .detection: "slider.horizontal.3"
        case .gestures: "hand.tap"
        }
    }
}

private struct Sidebar: View {
    @Binding var selectedSection: SettingsSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .foregroundStyle(selectedSection == section ? .primary : .secondary)
                        .background(
                            Capsule()
                                .fill(selectedSection == section ? Color.blue.opacity(0.22) : Color.secondary.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.top, 62)
        .padding(.horizontal, 22)
        .frame(width: 286)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 28, weight: .bold))
            Text(subtitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
                .padding(.top, 8)
        }
    }
}

private struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.checkbox)
            .font(.system(size: 22, weight: .semibold))
    }
}

private struct PickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)

            Picker(title, selection: $selection, content: content)
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .controlSize(.large)
        }
    }
}

private struct ActionPicker: View {
    let title: String
    @Binding var selection: KnockAction

    var body: some View {
        PickerRow(title: title, selection: $selection) {
            ForEach(KnockAction.allCases) { action in
                Text(action.title).tag(action)
            }
        }
    }
}
