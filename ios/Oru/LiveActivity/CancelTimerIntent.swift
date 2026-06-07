import AppIntents
import ActivityKit

struct CancelTimerIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Cancelar sesion"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .timerCancelledFromWidget, object: nil)
        }

        for activity in Activity<OruTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        return .result()
    }
}

extension Notification.Name {
    static let timerCancelledFromWidget = Notification.Name("timerCancelledFromWidget")
}
