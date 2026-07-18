import ActivityKit
import os
import SwiftUI

@MainActor
@Observable
class TimerViewModel {

    nonisolated enum TimerState {
        case idle, running
    }

    private(set) var state: TimerState = .idle
    private(set) var timerInterval: ClosedRange<Date>?
    var selectedMinutes = 25

    var trackHabit = false
    var selectedHabit: TimerHabitDTO?
    private(set) var compatibleHabits: [TimerHabitDTO] = []

    // Fallo de conexión
    var connectionErrorPresented = false
    // Resto de fallos 
    var lastError: String?
    private(set) var isStarting = false

    private let timerService: TimerService
    private var connectionRetry: (() async -> Void)?
    private var timerTask: Task<Void, Never>?
    private var currentActivity: Activity<OruTimerAttributes>?
    private var widgetCancelObserver: Any?

    static let stepMinutes = 5
    static let minMinutes = 5
    static let maxMinutes = 60

    var canDecrease: Bool { selectedMinutes > Self.minMinutes }
    var canIncrease: Bool { selectedMinutes < Self.maxMinutes }

    private nonisolated static let logger = Logger(subsystem: "com.antoniorodriguez.Oru2026", category: "LiveActivity")

    init(timerService: TimerService) {
        self.timerService = timerService
        widgetCancelObserver = NotificationCenter.default.addObserver(
            forName: .timerCancelledFromWidget,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.timerTask?.cancel() // cancel de Swift para interrumpir el Sleep
                try? await self.timerService.cancelSession()
                self.resetSession()
            }
        }
    }

    func loadCompatibleHabits() async {
        do {
            compatibleHabits = try await timerService.loadCompatibleHabits()
        } catch {
            compatibleHabits = []
        }
    }

    func start() async {
        guard !isStarting, state == .idle else { return }
        isStarting = true
        defer { isStarting = false }

        let now = Date.now
        let habitId = trackHabit ? selectedHabit?.id : nil
        do {
            _ = try await timerService.createSession(
                startDate: now,
                selectedMinutes: selectedMinutes,
                habitId: habitId
            )
        } catch let error as APIError where error.isBackendUnreachable {
            connectionRetry = { [weak self] in await self?.start() }
            connectionErrorPresented = true
            return
        } catch let error as APIError {
            lastError = error.errorDescription
            return
        } catch {
            lastError = "No se pudo iniciar la sesión. Inténtalo de nuevo."
            return
        }

        let end = now.addingTimeInterval(Double(selectedMinutes * 60))
        timerInterval = now...end
        state = .running
        UIApplication.shared.isIdleTimerDisabled = true
        startLiveActivity(endDate: end)
        scheduleFinish(after: Double(selectedMinutes * 60))
    }

    func retryConnection() async {
        await connectionRetry?()
    }

    func cancel() async {
        do {
            try await timerService.cancelSession()
        } catch let error as APIError where error.isBackendUnreachable {
            connectionRetry = { [weak self] in await self?.cancel() }
            connectionErrorPresented = true
            return
        } catch let error as APIError {
            lastError = error.errorDescription
            return
        } catch {
            lastError = "No se pudo finalizar la sesión. Inténtalo de nuevo."
            return
        }

        timerTask?.cancel()
        endLiveActivity(dismissImmediately: true)
        withAnimation(.easeInOut(duration: 0.2)) {
            resetSession()
        }
    }

    private func finish() {
        endLiveActivity(dismissImmediately: false)
        Task { try? await timerService.finishSession() }
        resetSession()
    }

    private func scheduleFinish(after seconds: TimeInterval) {
        timerTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func resetSession() {
        timerTask = nil
        timerInterval = nil
        state = .idle
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Live Activity

    private nonisolated static func endActivities(
        content: ActivityContent<OruTimerAttributes.ContentState>?,
        policy: ActivityUIDismissalPolicy
    ) async {
        for activity in Activity<OruTimerAttributes>.activities {
            await activity.end(content, dismissalPolicy: policy)
        }
    }

    private nonisolated static func endActivities(
        ids: Set<String>,
        content: ActivityContent<OruTimerAttributes.ContentState>?,
        policy: ActivityUIDismissalPolicy
    ) async {
        for activity in Activity<OruTimerAttributes>.activities where ids.contains(activity.id) {
            await activity.end(content, dismissalPolicy: policy)
        }
    }

    private func startLiveActivity(endDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let staleIDs = Set(Activity<OruTimerAttributes>.activities.map(\.id))
        if !staleIDs.isEmpty {
            Task { await Self.endActivities(ids: staleIDs, content: nil, policy: .immediate) }
        }

        let attributes = OruTimerAttributes(
            habitName: trackHabit ? selectedHabit?.name : nil,
            habitIcon: trackHabit ? selectedHabit?.icon : nil,
            totalMinutes: selectedMinutes
        )
        let contentState = OruTimerAttributes.ContentState(endDate: endDate)
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
        } catch {
            Self.logger.warning("No se pudo iniciar la Live Activity: \(error.localizedDescription)")
        }
    }

    private func endLiveActivity(dismissImmediately: Bool) {
        Task { await endAllActivities(immediate: dismissImmediately) }
    }

    // Cierra TODAS las Live Activities del temporizador pasando un `ContentState` final
    private func endAllActivities(immediate: Bool) async {
        let finalState = OruTimerAttributes.ContentState(endDate: .now)
        let content = ActivityContent(state: finalState, staleDate: nil)
        let policy: ActivityUIDismissalPolicy = immediate
            ? .immediate
            : .after(.now + 180)
        await Self.endActivities(content: content, policy: policy)
        currentActivity = nil
    }

    // Cierra Live Activities residuales tras cold start (apagar/encender móvil).
    // Usa `activityUpdates` como fallback cuando el daemon aún no ha sincronizado
    // con el proceso recién arrancado y `Activity.activities` está vacío.
    private func endStaleActivities() async {
        // Solo limpiamos si NO hay sesión en curso: nunca cerrar una Live Activity
        // recién iniciada por el usuario (activities/activityUpdates la incluyen).
        guard state == .idle else { return }

        let finalState = OruTimerAttributes.ContentState(endDate: .now)
        let content = ActivityContent(state: finalState, staleDate: nil)

        // Fast path: daemon ya sincronizado
        let current = Activity<OruTimerAttributes>.activities
        if !current.isEmpty {
            Self.logger.notice("endStaleActivities: \(current.count) actividad(es) encontrada(s)")
            await Self.endActivities(content: content, policy: .immediate)
            currentActivity = nil
            return
        }

        // Slow path: cold start, el daemon aún no entregó la activity restaurada.
        Self.logger.notice("endStaleActivities: activities vacío, esperando daemon…")
        let waitTask = Task.detached { [weak self] in
            for await activity in Activity<OruTimerAttributes>.activityUpdates {
                // Si arranca una sesión durante la ventana, NO la cerramos.
                guard let self, await self.state == .idle else { continue }
                Self.logger.notice("endStaleActivities: activity recibida, cerrando…")
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
        try? await Task.sleep(for: .seconds(2))
        waitTask.cancel()
        if state == .idle { currentActivity = nil }
    }
    func recoverSessionIfNeeded() async {
        guard state == .idle else { return }

        let session: TimerSessionDTO?
        do {
            session = try await timerService.getActiveSession()
        } catch {
            return
        }

        // El GET pudo tardar; si el usuario inició una sesión mientras estaba en
        // vuelo, el resultado es obsoleto y NO debemos tocar su Live Activity.
        guard state == .idle else { return }

        let now = Date.now
        guard let session else {
            // Sin sesión activa limpiamos cualquier Live Activity residual.
            await endStaleActivities()
            return
        }

        let end = session.startDate.addingTimeInterval(Double(session.selectedMinutes * 60))
        guard end > now else {
            await endStaleActivities()
            return
        }

        timerInterval = session.startDate...end
        selectedMinutes = session.selectedMinutes
        state = .running
        UIApplication.shared.isIdleTimerDisabled = true
        currentActivity = Activity<OruTimerAttributes>.activities.first
        scheduleFinish(after: end.timeIntervalSince(now))
    }
}
