import SwiftUI

@Observable
class HabitViewModel {

    private let habitService: HabitService
    private let unitService: UnitService

    var lastError: String?
    var connectionErrorPresented = false
    var consolidatedHabit: HabitDTO?
    var onHabitToggled: ((HabitDTO) -> Void)?
    var onHabitsChanged: (() -> Void)?

    init(habitService: HabitService, unitService: UnitService) {
        self.habitService = habitService
        self.unitService = unitService
    }

    func todayCompliance(for habit: HabitDTO) -> ComplianceDTO? {
        habit.compliances.first { Calendar.current.isDateInToday($0.date) }
    }

    func consolidationProgress(for habit: HabitDTO) -> Double {
        let completedDays = habit.compliances.filter(\.isCompleted).count
        return min(Double(completedDays) / Double(HabitDTO.consolidationThreshold), 1.0)
    }

    func toggleBoolean(for habit: HabitDTO) async {
        await toggle(habit, amount: nil)
    }

    func recordAmount(_ amount: Double, for habit: HabitDTO) async {
        await toggle(habit, amount: amount)
    }

    private func toggle(_ habit: HabitDTO, amount: Double?) async {
        do {
            let updated = try await habitService.toggleHabit(id: habit.id, amount: amount)
            lastError = nil
            // El hábito acaba de consolidarse (66ª vez): dispara la celebración.
            if !habit.isConsolidated && updated.isConsolidated {
                consolidatedHabit = updated
            }
            onHabitToggled?(updated)
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
        } catch {
            lastError = "No se pudo registrar el cambio. Inténtalo de nuevo."
        }
    }

    func currentWeekDay() -> WeekDay {
        WeekDay.today
    }

    // MARK: - Validación

    func isValidHabit(
        name: String,
        selectedDays: Set<WeekDay>,
        type: HabitType,
        dailyGoal: Double?
    ) -> Bool {
        let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
        let hasDays = !selectedDays.isEmpty
        let hasGoalIfNeeded = type == .boolean || (dailyGoal ?? 0) > 0
        return hasName && hasDays && hasGoalIfNeeded
    }

    func clampName(_ value: String) -> String {
        String(value.prefix(HabitDTO.maxNameLength))
    }

    func clampGoal(_ value: String) -> String {
        String(value.prefix(HabitDTO.maxGoalLength))
    }

    func clampNote(_ value: String) -> String {
        String(value.prefix(HabitDTO.maxNoteLength))
    }

    // MARK: - Creación y edición de hábitos

    func createHabit(_ request: CreateHabitRequest) async -> Bool {
        do {
            _ = try await habitService.createHabit(request)
            lastError = nil
            onHabitsChanged?()
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch let error as APIError {
            lastError = error.errorDescription
            return false
        } catch {
            lastError = "No se pudo crear el hábito. Inténtalo de nuevo."
            return false
        }
    }

    func deleteHabit(_ habit: HabitDTO) async -> Bool {
        do {
            try await habitService.deleteHabit(id: habit.id)
            onHabitsChanged?()
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch {
            lastError = "No se pudo eliminar el hábito. Inténtalo de nuevo."
            return false
        }
    }

    func archiveHabit(_ habit: HabitDTO) async -> Bool {
        do {
            try await habitService.archiveHabit(id: habit.id)
            onHabitsChanged?()
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch {
            lastError = "No se pudo archivar el hábito. Inténtalo de nuevo."
            return false
        }
    }

    func updateHabit(_ habit: HabitDTO, request: UpdateHabitRequest) async -> Bool {
        do {
            _ = try await habitService.updateHabit(id: habit.id, request: request)
            lastError = nil
            onHabitsChanged?()
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch let error as APIError {
            lastError = error.errorDescription
            return false
        } catch {
            lastError = "No se pudo actualizar el hábito. Inténtalo de nuevo."
            return false
        }
    }

    func loadUnits() async -> [UnitDTO] {
        do {
            return try await unitService.fetchAllUnits()
        } catch {
            return []
        }
    }

    /// Carga las unidades para la pantalla de gestión
    func loadManagedUnits() async -> (units: [UnitDTO], connectionError: Bool) {
        do {
            return (try await unitService.fetchAllUnits(), false)
        } catch let error as APIError where error.isBackendUnreachable {
            return ([], true)
        } catch {
            return ([], false)
        }
    }
    
    // MARK: - Gestión de unidades

    /// Resultado de una operación de unidad. La vista gestiona sus
    /// propias alertas para no chocar con el estado vigilado
    /// por la home view.
    enum UnitActionOutcome {
        case success
        case connectionError
        case failure(String)
    }

    func createUnit(name: String) async -> UnitActionOutcome {
        do {
            _ = try await unitService.createUnit(name: name)
            return .success
        } catch let error as APIError where error.isBackendUnreachable {
            return .connectionError
        } catch let error as APIError {
            return .failure(error.errorDescription ?? "No se pudo crear la unidad. Inténtalo de nuevo.")
        } catch {
            return .failure("No se pudo crear la unidad. Inténtalo de nuevo.")
        }
    }

    func updateUnit(id: Int, name: String) async -> UnitActionOutcome {
        do {
            try await unitService.updateUnit(id: id, name: name)
            return .success
        } catch let error as APIError where error.isBackendUnreachable {
            return .connectionError
        } catch let error as APIError {
            return .failure(error.errorDescription ?? "No se pudo renombrar la unidad. Inténtalo de nuevo.")
        } catch {
            return .failure("No se pudo renombrar la unidad. Inténtalo de nuevo.")
        }
    }

    func deleteUnit(id: Int, name: String) async -> UnitActionOutcome {
        do {
            try await unitService.deleteUnit(id: id)
            return .success
        } catch let error as APIError where error.isBackendUnreachable {
            return .connectionError
        } catch let error as APIError {
            if case .validation = error {
                return .failure("«\(name)» está en uso por algún hábito. Cambia su unidad antes de eliminarla.")
            }
            return .failure("No se pudo eliminar la unidad. Inténtalo de nuevo.")
        } catch {
            return .failure("No se pudo eliminar la unidad. Inténtalo de nuevo.")
        }
    }
}
