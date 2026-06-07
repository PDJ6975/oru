import Foundation

@Observable
@MainActor
final class StatsViewModel {

    private let statsService: StatsService
    private let origamiService: OrigamiService

    let minYear = 2020
    let maxYear: Int

    var selectedYear: Int {
        didSet {
            guard selectedYear != oldValue else { return }
            Task { await loadStats() }
        }
    }

    // Métricas globales
    private(set) var complianceRate: Double = 0
    private(set) var currentStreak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var habitsCompleted: Int = 0
    private(set) var perfectDays: Int = 0

    // Métricas por hábito
    private(set) var habitStats: [HabitStatsDto] = []
    private(set) var archivedHabitStats: [HabitStatsDto] = []

    // Galería de figuras completadas en el año seleccionado.
    private(set) var completedOrigamis: [CompletedOrigamiDto] = []

    var connectionErrorPresented = false

    init(
        statsService: StatsService,
        origamiService: OrigamiService,
        currentDate: Date = .now
    ) {
        self.statsService = statsService
        self.origamiService = origamiService
        let year = Calendar.current.component(.year, from: currentDate)
        self.maxYear = year
        self.selectedYear = year
    }

    /// Carga las estadísticas y los origamis completados del año seleccionado.
    func loadStats() async {
        do {
            async let stats = statsService.fetchStats(year: selectedYear)
            async let origamis = origamiService.fetchCompletedOrigamis(year: selectedYear)
            apply(try await stats)
            completedOrigamis = try await origamis
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
        } catch {
            resetMetrics()
        }
    }

    /// Reparte la respuesta en resumen global y hábitos activos/archivados.
    private func apply(_ stats: StatsDto) {
        complianceRate = stats.userStats.complianceRate
        currentStreak = stats.userStats.currentStreak
        bestStreak = stats.userStats.bestStreak
        habitsCompleted = stats.userStats.habitsCompleted
        perfectDays = stats.userStats.perfectDays

        // Se preserva el orden por score que entrega el backend.
        habitStats = stats.habitStats.filter { $0.habitStatus == .active }
        archivedHabitStats = stats.habitStats.filter { $0.habitStatus == .archived }
    }

    private func resetMetrics() {
        complianceRate = 0
        currentStreak = 0
        bestStreak = 0
        habitsCompleted = 0
        perfectDays = 0
        habitStats = []
        archivedHabitStats = []
        completedOrigamis = []
    }
}
