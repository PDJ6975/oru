import SwiftUI

@Observable
@MainActor
final class HomeViewModel {

    private static let defaultName = "user"

    private(set) var userName = defaultName
    private(set) var todayHabits: [HabitDto] = []
    private(set) var pausedHabits: [HabitDto] = []
    var connectionErrorPresented = false

    private let userService: UserService
    private let habitService: HabitService

    init(userService: UserService, habitService: HabitService) {
        self.userService = userService
        self.habitService = habitService
    }

    /// Carga los datos de la pantalla de inicio.
    func load() async {
        do {
            try await loadUserName()
            try await loadHabits()
            // Aquí irán futuros GETs de la home (origami...).
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
        } catch {
            // Otros errores ya quedan resueltos en cada sub-carga.
        }
    }

    /// Carga el nombre del usuario para el saludo.
    private func loadUserName() async throws {
        do {
            userName = try await userService.fetchMe().name
        } catch let error as APIError where error.isBackendUnreachable {
            throw error
        } catch {
            userName = Self.defaultName
        }
    }

    /// Carga los hábitos activos y los reparte entre hoy y en pausa.
    private func loadHabits() async throws {
        do {
            let habits = try await habitService.fetchHabits()
            let today = WeekDay.today
            todayHabits = habits.filter { habit in
                habit.scheduledDays.contains { $0.day == today }
            }
            pausedHabits = habits.filter { habit in
                !habit.scheduledDays.contains { $0.day == today }
            }
        } catch let error as APIError where error.isBackendUnreachable {
            throw error
        } catch {
            todayHabits = []
            pausedHabits = []
        }
    }

    func addCreatedHabit(_ habit: HabitDto) {
        let today = WeekDay.today
        if habit.scheduledDays.contains(where: { $0.day == today }) {
            todayHabits.append(habit)
        } else {
            pausedHabits.append(habit)
        }
    }

    func removeHabit(_ habit: HabitDto) {
        todayHabits.removeAll { $0.id == habit.id }
        pausedHabits.removeAll { $0.id == habit.id }
    }

    func updateHabit(_ habit: HabitDto) {
        removeHabit(habit)
        let today = WeekDay.today
        if habit.scheduledDays.contains(where: { $0.day == today }) {
            todayHabits.append(habit)
        } else {
            pausedHabits.append(habit)
        }
    }

    /// Reemplaza un hábito en su sitio sin reordenar tras un toggle.
    func replaceHabit(_ habit: HabitDto) {
        if let index = todayHabits.firstIndex(where: { $0.id == habit.id }) {
            todayHabits[index] = habit
        } else if let index = pausedHabits.firstIndex(where: { $0.id == habit.id }) {
            pausedHabits[index] = habit
        }
    }
}
