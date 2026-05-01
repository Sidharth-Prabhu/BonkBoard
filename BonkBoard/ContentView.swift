import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: BonkBoardController
    @ObservedObject private var settings: AppSettings
    @ObservedObject private var impactMonitor: AppleSiliconImpactMonitor
    @ObservedObject private var gestureCoordinator: KnockGestureCoordinator
    @ObservedObject private var actionRunner: ActionRunner

    @State private var selectedSection: SettingsSection = .general

    init(controller: BonkBoardController) {
        self.controller = controller
        settings = controller.settings
        impactMonitor = controller.impactMonitor
        gestureCoordinator = controller.gestureCoordinator
        actionRunner = controller.actionRunner
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .frame(minWidth: 600, minHeight: 560)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    selectedSection == section
                    ? Color.accentColor.opacity(0.2)
                    : Color.clear
                )
            }
        }
        .listStyle(.sidebar)
    }

    // MARK: - Detail

    private var detailView: some View {
        Group {
            switch selectedSection {
            case .general:
                generalView
            case .detection:
                detectionView
            case .gestures:
                gestureView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Views

extension ContentView {

    private var generalView: some View {
        Form {
            Section("General") {
                Toggle("Enabled", isOn: $settings.isEnabled)
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                Toggle("Sound Feedback", isOn: $settings.soundFeedback)
                Toggle("Show in Dock", isOn: $settings.showInDock)
            }

            if !controller.appMessage.isEmpty {
                Section {
                    Text(controller.appMessage)
                        .foregroundStyle(.secondary)
                }
            }

            statusSection
        }
        .formStyle(.grouped)
    }

    private var detectionView: some View {
        Form {
            Section("Sensitivity") {
                Slider(value: $settings.sensitivity, in: 0...1)
            }

            Section("Timing") {
                Picker("Tap Speed", selection: $settings.tapSpeed) {
                    ForEach(TapSpeed.allCases) {
                        Text($0.title).tag($0)
                    }
                }

                Picker("Hold Key", selection: $settings.holdKey) {
                    ForEach(HoldKey.allCases) {
                        Text($0.title).tag($0)
                    }
                }
            }

            statusSection
        }
        .formStyle(.grouped)
    }

    private var gestureView: some View {
        Form {
            Section("Knock Actions") {
                Picker("Single Knock", selection: $settings.singleKnockAction) {
                    ForEach(KnockAction.allCases) {
                        Text($0.title).tag($0)
                    }
                }

                Picker("Double Knock", selection: $settings.doubleKnockAction) {
                    ForEach(KnockAction.allCases) {
                        Text($0.title).tag($0)
                    }
                }

                Picker("Triple Knock", selection: $settings.tripleKnockAction) {
                    ForEach(KnockAction.allCases) {
                        Text($0.title).tag($0)
                    }
                }
            }

            actionFields
            statusSection
        }
        .formStyle(.grouped)
    }

    private var actionFields: some View {
        Group {
            if settings.singleKnockAction.needsShortcutName ||
                settings.doubleKnockAction.needsShortcutName ||
                settings.tripleKnockAction.needsShortcutName {

                Section("Shortcut") {
                    TextField("Shortcut name", text: $settings.shortcutName)
                }
            }

            if settings.singleKnockAction.needsAppName ||
                settings.doubleKnockAction.needsAppName ||
                settings.tripleKnockAction.needsAppName {

                Section("Application") {
                    TextField("App name (e.g. Safari)", text: $settings.appName)
                }
            }

            if settings.singleKnockAction.needsCustomCommand ||
                settings.doubleKnockAction.needsCustomCommand ||
                settings.tripleKnockAction.needsCustomCommand {

                Section("Command") {
                    TextField("Shell command", text: $settings.customCommand)
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Live Status") {
            HStack {
                Circle()
                    .fill(impactMonitor.impactDetected ? .red : .green)
                    .frame(width: 10, height: 10)

                Text(impactMonitor.impactDetected ? "Impact detected" : impactMonitor.statusText)
            }

            Text("\(gestureCoordinator.lastGestureText) • \(actionRunner.lastActionText)")
                .foregroundStyle(.secondary)

            if let a = impactMonitor.latestAcceleration {
                Text(String(format: "x %.2f  y %.2f  z %.2f", a.x, a.y, a.z))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Enum

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, detection, gestures

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
