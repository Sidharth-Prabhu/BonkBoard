//
//  KnockGestureCoordinator.swift
//  BonkBoard
//
//  Created by Sidharth Prabhu on 2026-05-01.
//

import Combine
import Foundation

@MainActor
final class KnockGestureCoordinator: ObservableObject {
    @Published private(set) var lastGestureText = "No gesture yet"

    private var knockDates: [Date] = []
    private var recognitionTask: Task<Void, Never>?

    func registerKnock(settings: AppSettings, keyboard: KeyboardModifierMonitor, actionRunner: ActionRunner) {
        guard settings.isEnabled else { return }

        guard keyboard.isSatisfied(settings.holdKey) else {
            lastGestureText = "Hold \(settings.holdKey.title) to arm"
            return
        }

        let now = Date()
        knockDates.append(now)
        knockDates = knockDates.filter { now.timeIntervalSince($0) <= settings.tapSpeed.interval }

        let count = min(knockDates.count, 3)
        lastGestureText = "\(count) knock\(count == 1 ? "" : "s")..."

        // After 2 knocks, wait a shorter grace window for a potential third
        let tripleGrace = settings.tapSpeed.interval * 0.35
        let delay: TimeInterval = (count >= 2) ? tripleGrace : settings.tapSpeed.interval

        recognitionTask?.cancel()
        recognitionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self?.finishGesture(settings: settings, actionRunner: actionRunner)
            }
        }
    }

    private func finishGesture(settings: AppSettings, actionRunner: ActionRunner) {
        let knockCount = min(knockDates.count, 3)
        knockDates.removeAll()

        let action: KnockAction
        switch knockCount {
        case 1:
            action = settings.singleKnockAction
            lastGestureText = "Single Knock"
        case 2:
            action = settings.doubleKnockAction
            lastGestureText = "Double Knock"
        case 3:
            action = settings.tripleKnockAction
            lastGestureText = "Triple Knock"
        default:
            lastGestureText = "No gesture"
            return
        }

        actionRunner.run(action, settings: settings)
    }
}
