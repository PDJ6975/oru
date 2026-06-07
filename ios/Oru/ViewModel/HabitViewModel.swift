import SwiftUI
import SwiftData

@Observable
class HabitViewModel {

    private let repository: HabitRepositoryProtocol
    private let habitService: HabitService
    private let unitService: UnitService

    var lastError: String?
    var connectionErrorPresented = false
    var consolidatedHabit: HabitDto?
    var onHabitChanged: ((_ allCompleted: Bool) -> Void)?
    var onHabitCreated: ((HabitDto) -> Void)?
    var onHabitDeleted: ((HabitDto) -> Void)?
    var onHabitUpdated: ((HabitDto) -> Void)?
    var onHabitArchived: ((HabitDto) -> Void)?
    var onHabitToggled: ((HabitDto) -> Void)?

    init(repository: HabitRepositoryProtocol, habitService: HabitService, unitService: UnitService) {
        self.repository = repository
        self.habitService = habitService
        self.unitService = unitService
    }
    
    // Interruptor de hábitos booleanos
    // Si existe un Compliance en el día actual -> lo invierte
    // Si no existe -> Crea un compliance para hoy como completado
    func toggleBoolean(for habit: Habit) {
        if let compliance = todayCompliance(for: habit) {
            compliance.completed.toggle()
        } else {
            let compliance = Compliance(date: .now, completed: true)
            habit.compliances.append(compliance)
        }
        do {
            habit.updateConsolidationStatus()
            try repository.saveChanges()
        } catch {
            lastError = "No se pudo guardar el cambio: \(error.localizedDescription)"
        }
        onHabitChanged?(checkAllCompleted())
    }

    // Si la cantidad es 0 y ya existe un compliance, lo elimina
    // Si la cantidad es > 0, crea o actualiza el compliance
    func recordAmount(_ amount: Double, for habit: Habit) {
        do {
            if amount <= 0 {
                if let compliance = todayCompliance(for: habit) {
                    habit.compliances.removeAll { $0 === compliance }
                    try repository.deleteCompliance(compliance)
                }
            } else if let compliance = todayCompliance(for: habit) {
                compliance.recordedAmount = amount
                compliance.completed = habit.isGoalMet(amount)
            } else {
                let completed = habit.isGoalMet(amount)
                let compliance = Compliance(date: .now, completed: completed, recordedAmount: amount)
                habit.compliances.append(compliance)
            }
            habit.updateConsolidationStatus()
            try repository.saveChanges()
        } catch {
            lastError = "No se pudo registrar la cantidad: \(error.localizedDescription)"
        }
        onHabitChanged?(checkAllCompleted())
    }
    private func checkAllCompleted() -> Bool {
        guard let habits = try? repository.fetchActiveHabits() else { return false }
        let today = currentWeekday()
        let scheduled = habits.filter { $0.scheduledDays.contains(today) }
        return !scheduled.isEmpty && scheduled.allSatisfy { todayCompliance(for: $0)?.completed ?? false }
    }

    func todayCompliance(for habit: Habit) -> Compliance? {
        habit.compliances.first { Calendar.current.isDateInToday($0.date) }
    }

    func todayCompliance(for habit: HabitDto) -> ComplianceDto? {
        habit.compliances.first { Calendar.current.isDateInToday($0.date) }
    }

    func consolidationProgress(for habit: HabitDto) -> Double {
        let completedDays = habit.compliances.filter(\.isCompleted).count
        return min(Double(completedDays) / Double(HabitDto.consolidationThreshold), 1.0)
    }

    func toggleBoolean(for habit: HabitDto) async {
        await toggle(habit, amount: nil)
    }

    func recordAmount(_ amount: Double, for habit: HabitDto) async {
        await toggle(habit, amount: amount)
    }

    private func toggle(_ habit: HabitDto, amount: Double?) async {
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

    func currentWeekday() -> Habit.Weekday {
        weekday(from: .now)
    }

    func currentWeekDay() -> WeekDay {
        WeekDay.today
    }

    // MARK: - Gestión de unidades

    func addCustomUnit(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let allUnits = fetchUnits()
        let customCount = allUnits.filter { $0.origin == .custom }.count
        guard customCount < Unit.maxCustomCount else { return false }
        guard !allUnits.contains(where: { $0.name.lowercased() == trimmed.lowercased() }) else { return false }
        do {
            try repository.addUnit(Unit(name: trimmed, origin: .custom))
            return true
        } catch {
            lastError = "No se pudo crear la unidad: \(error.localizedDescription)"
            return false
        }
    }

    func countHabitsUsingUnit(_ unit: Unit) -> Int {
        do {
            return try repository.countHabitsUsingUnit(unit)
        } catch {
            lastError = "No se pudo verificar el uso de la unidad: \(error.localizedDescription)"
            return 0
        }
    }

    func deleteUnit(_ unit: Unit) {
        do {
            try repository.deleteUnit(unit)
        } catch {
            lastError = "No se pudo eliminar la unidad: \(error.localizedDescription)"
        }
    }

    func renameUnit(_ unit: Unit, to newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let allUnits = fetchUnits()
        guard !allUnits.contains(where: { $0.name.lowercased() == trimmed.lowercased() && $0 !== unit })
        else { return false }
        unit.name = trimmed
        do {
            try repository.saveChanges()
            return true
        } catch {
            lastError = "No se pudo renombrar la unidad: \(error.localizedDescription)"
            return false
        }
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
        String(value.prefix(HabitDto.maxNameLength))
    }

    func clampGoal(_ value: String) -> String {
        String(value.prefix(HabitDto.maxGoalLength))
    }

    func clampNote(_ value: String) -> String {
        String(value.prefix(HabitDto.maxNoteLength))
    }

    // MARK: - Creación y edición de hábitos

    func createHabit(_ request: CreateHabitRequest) async -> Bool {
        do {
            let created = try await habitService.createHabit(request)
            lastError = nil
            onHabitCreated?(created)
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

    func deleteHabit(_ habit: HabitDto) async -> Bool {
        do {
            try await habitService.deleteHabit(id: habit.id)
            onHabitDeleted?(habit)
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch {
            lastError = "No se pudo eliminar el hábito. Inténtalo de nuevo."
            return false
        }
    }

    func archiveHabit(_ habit: HabitDto) async -> Bool {
        do {
            try await habitService.archiveHabit(id: habit.id)
            onHabitArchived?(habit)
            return true
        } catch let error as APIError where error.isBackendUnreachable {
            connectionErrorPresented = true
            return false
        } catch {
            lastError = "No se pudo archivar el hábito. Inténtalo de nuevo."
            return false
        }
    }

    func updateHabit(_ habit: HabitDto, request: UpdateHabitRequest) async -> Bool {
        do {
            let updated = try await habitService.updateHabit(id: habit.id, request: request)
            lastError = nil
            onHabitUpdated?(updated)
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

    func addHabit(_ habit: Habit) {
        do {
            try repository.addHabit(habit)
        } catch {
            lastError = "No se pudo crear el hábito: \(error.localizedDescription)"
        }
    }

    func archiveHabit(_ habit: Habit) {
        habit.status = .archived
        habit.archivedDate = .now
        do {
            try repository.saveChanges()
        } catch {
            lastError = "No se pudo archivar el hábito: \(error.localizedDescription)"
        }
    }

    func deleteHabit(_ habit: Habit) {
        do {
            try repository.deleteHabit(habit)
        } catch {
            lastError = "No se pudo eliminar el hábito: \(error.localizedDescription)"
        }
    }

    func updateHabit(_ habit: Habit, with data: FormData) {
        habit.icon = data.icon
        habit.name = data.name
        habit.type = data.type
        habit.scheduledDays = data.scheduledDays
        habit.dailyGoal = data.dailyGoal
        habit.note = data.note
        habit.unit = data.unit
        do {
            try repository.saveChanges()
        } catch {
            lastError = "No se pudo actualizar el hábito: \(error.localizedDescription)"
        }
    }

    func fetchUnits() -> [Unit] {
        do {
            return try repository.fetchAllUnits()
        } catch {
            lastError = "No se pudieron cargar las unidades: \(error.localizedDescription)"
            return []
        }
    }

    func loadUnits() async -> [UnitDto] {
        do {
            return try await unitService.fetchAllUnits()
        } catch {
            return []
        }
    }

    // MARK: - Tipos auxiliares

    struct FormData {
        let icon: String
        let name: String
        let type: Habit.HabitType
        let scheduledDays: [Habit.Weekday]
        let dailyGoal: Double?
        let note: String?
        let unit: Unit?
    }
}
