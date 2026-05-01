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
        NavigationSplitView {
            Sidebar(selectedSection: $selectedSection)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    selectedContent
                    statusCard
                }
                .padding(32)
                .frame(maxWidth: 720, alignment: .leading)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 560)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedSection {
        case .general:
            settingsCard { generalSettings }
        case .detection:
            settingsCard { detectionSettings }
        case .gestures:
            settingsCard { gestureSettings }
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            content()
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "General", subtitle: "App behavior and launch options")

            SettingsToggle(title: "Enabled", isOn: $settings.isEnabled)
            SettingsToggle(title: "Launch at Login", isOn: $settings.launchAtLogin)
            SettingsToggle(title: "Sound Feedback", isOn: $settings.soundFeedback)
            SettingsToggle(title: "Show in Dock", isOn: $settings.showInDock)

            if !controller.appMessage.isEmpty {
                Text(controller.appMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var detectionSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "Detection", subtitle: "Sensitivity and timing")

            VStack(alignment: .leading, spacing: 8) {
                Text("Sensitivity")
                    .font(.headline)

                Slider(value: $settings.sensitivity, in: 0...1)
                    .controlSize(.large)
            }

            PickerRow(title: "Tap Speed", selection: $settings.tapSpeed) {
                ForEach(TapSpeed.allCases) {
                    Text($0.title).tag($0)
                }
            }

            PickerRow(title: "Hold Key", selection: $settings.holdKey) {
                ForEach(HoldKey.allCases) {
                    Text($0.title).tag($0)
                }
            }
        }
    }

    private var gestureSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeader(title: "Gestures", subtitle: "Assign actions")

            ActionPicker(title: "Single Knock", selection: $settings.singleKnockAction)
            ActionPicker(title: "Double Knock", selection: $settings.doubleKnockAction)
            ActionPicker(title: "Triple Knock", selection: $settings.tripleKnockAction)

            actionConfigurationFields
        }
    }

    @ViewBuilder
    private var actionConfigurationFields: some View {
        if settings.singleKnockAction.needsShortcutName ||
            settings.doubleKnockAction.needsShortcutName ||
            settings.tripleKnockAction.needsShortcutName {

            TextField("Shortcut name", text: $settings.shortcutName)
        }

        if settings.singleKnockAction.needsAppName ||
            settings.doubleKnockAction.needsAppName ||
            settings.tripleKnockAction.needsAppName {

            TextField("Application name", text: $settings.appName)
        }

        if settings.singleKnockAction.needsCustomCommand ||
            settings.doubleKnockAction.needsCustomCommand ||
            settings.tripleKnockAction.needsCustomCommand {

            TextField("Shell command", text: $settings.customCommand)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(impactMonitor.impactDetected ? .red : .green)
                    .frame(width: 10, height: 10)

                Text(impactMonitor.impactDetected ? "Impact detected" : impactMonitor.statusText)
                    .font(.headline)

                Spacer()
            }

            Text("\(gestureCoordinator.lastGestureText) • \(actionRunner.lastActionText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let a = impactMonitor.latestAcceleration {
                Text(String(format: "x %.2f  y %.2f  z %.2f", a.x, a.y, a.z))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, detection, gestures
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .detection: return "Detection"
        case .gestures: return "Gestures"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .detection: return "slider.horizontal.3"
        case .gestures: return "hand.tap"
        }
    }
}

private struct Sidebar: View {
    @Binding var selectedSection: SettingsSection

    var body: some View {
        List {
            ForEach(SettingsSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    Label(section.title, systemImage: section.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selectedSection == section ? Color.accentColor.opacity(0.15) : .clear)
                )
            }
        }
        .listStyle(.sidebar)
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
            .toggleStyle(.switch)
    }
}

private struct PickerRow<Selection: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: $selection, content: content)
                .pickerStyle(.menu)
        }
    }
}

private struct ActionPicker: View {
    let title: String
    @Binding var selection: KnockAction

    var body: some View {
        PickerRow(title: title, selection: $selection) {
            ForEach(KnockAction.allCases) {
                Text($0.title).tag($0)
            }
        }
    }
}
