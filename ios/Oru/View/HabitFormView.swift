import SwiftUI
import SwiftData

// MARK: - Teclado de emojis (rawValue no público pero funcional y estable)

private extension UIKeyboardType {
    static let emoji = UIKeyboardType(rawValue: 124) ?? .default
}

private extension Character {
    var isEmoji: Bool {
        unicodeScalars.first?.properties.isEmoji == true
    }
}

struct HabitFormView: View {

    @Bindable var viewModel: HabitViewModel
    var habitToEdit: HabitDto?
    @Environment(\.dismiss) private var dismiss

    // MARK: - Estado del formulario

    @State private var icon = "🌟"
    @State private var iconSelection: TextSelection?
    @State private var name = ""
    @State private var selectedDays: Set<WeekDay> = Set(WeekDay.allCases)
    @State private var habitType: HabitType
    @State private var dailyGoal = ""
    @State private var selectedUnit: UnitDto?
    @State private var note = ""
    @State private var confirmTap = false
    @State private var isSaving = false
    @State private var units: [UnitDto] = []
    @State private var unitsLoaded = false
    @State private var showUnitManagement = false

    private var isEditing: Bool { habitToEdit != nil }

    init(viewModel: HabitViewModel, habitToEdit: HabitDto? = nil) {
        self.viewModel = viewModel
        self.habitToEdit = habitToEdit
        _habitType = State(initialValue: habitToEdit?.type ?? .boolean)
    }

    @FocusState private var focusedField: Field?

    private enum Field {
        case emoji, name, goal, note
    }

    private var isValid: Bool {
        let normalized = dailyGoal.replacingOccurrences(of: ",", with: ".")
        let goal = Double(normalized)
        return viewModel.isValidHabit(
            name: name,
            selectedDays: selectedDays,
            type: habitType,
            dailyGoal: goal
        )
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                iconAndNameSection
                    .padding(.top, 16)
                daysSection
                typeSection
                if habitType == .quantity {
                    goalSection
                        .transition(.blurReplace)
                }
                noteSection
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
        }
        .scrollDismissesKeyboard(.immediately)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 18) {
                confirmButton
                consolidationHint
            }
        }
        .ignoresSafeArea(.keyboard)
        .onTapGesture { focusedField = nil }
        .sensoryFeedback(.selection, trigger: focusedField)
        .task {
            await loadUnits()
            if let habit = habitToEdit {
                icon = habit.icon
                name = habit.name
                selectedDays = Set(habit.scheduledDays.map(\.day))
                habitType = habit.type
                if let goal = habit.dailyGoal {
                    dailyGoal = goal.formatted
                }
                selectedUnit = units.first { $0.id == habit.unitId }
                note = habit.note ?? ""
            }
        }
        .connectionErrorAlert(
            isPresented: $viewModel.connectionErrorPresented,
            onRetry: saveHabit
        )
    }

    // MARK: - Icono + Nombre

    private var iconAndNameSection: some View {
        HStack(spacing: 14) {
            TextField("", text: $icon, selection: $iconSelection)
                .keyboardType(.emoji)
                .font(.system(size: 30))
                .multilineTextAlignment(.center)
                .tint(.clear)
                .frame(width: 46, height: 46)
                .focused($focusedField, equals: .emoji)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .onChange(of: focusedField) { _, newValue in
                    if newValue == .emoji {
                        iconSelection = TextSelection(
                            range: icon.startIndex..<icon.endIndex
                        )
                    }
                }
                .onChange(of: icon) { _, newValue in
                    let emojis = newValue.filter { $0.isEmoji }
                    icon = emojis.isEmpty ? "🌟" : String(emojis.suffix(1))
                }

            TextField("Añade tu nuevo hábito...", text: $name)
                .oruInputBig()
                .focused($focusedField, equals: .name)
                .onChange(of: name) { _, newValue in
                    name = viewModel.clampName(newValue)
                }
        }
    }

    // MARK: - Días

    private var daysSection: some View {
        DaysSectionView(selectedDays: $selectedDays)
    }

    // MARK: - Tipo de hábito

    private var typeSection: some View {
        HStack(spacing: 12) {
            Text("Selecciona un tipo:")
                .oruLabel()
                .fixedSize()

            Picker("Tipo", selection: $habitType) {
                Text("Sí/No").tag(HabitType.boolean)
                Text("Cantidad").tag(HabitType.quantity)
            }
            .pickerStyle(.segmented)
            .disabled(isEditing)
            .sensoryFeedback(.selection, trigger: habitType)
            .onChange(of: habitType) { _, newValue in
                if newValue == .boolean {
                    dailyGoal = ""
                    selectedUnit = nil
                } else {
                    selectedUnit = units.first { $0.name == UnitDto.defaultName }
                }
            }
        }
        .animation(.smooth, value: habitType)
    }

    // MARK: - Objetivo

    private var goalSection: some View {
        HStack(spacing: 12) {
            Text("¿Tienes un objetivo?:")
                .oruLabel()
                .fixedSize()

            HStack(spacing: 8) {
                TextField("Número/meta", text: $dailyGoal)
                    .keyboardType(.decimalPad)
                    .oruInputSmall()
                    .focused($focusedField, equals: .goal)
                    .onChange(of: dailyGoal) { _, newValue in
                        dailyGoal = viewModel.clampGoal(newValue)
                    }

                Spacer()

                unitPicker
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
    }

    private var unitPicker: some View {
        Menu {
            ForEach(units) { unit in
                Button(unit.name) { selectedUnit = unit }
            }

            if unitsLoaded {
                Divider()

                Button {
                    showUnitManagement = true
                } label: {
                    Label("Añadir nueva medida", systemImage: "plus.circle.dashed")
                }
            }
        } label: {
            HStack(spacing: 2) {
                Text(selectedUnit?.name ?? "")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.oruPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.oruPrimary)
            }
        }
        .sheet(isPresented: $showUnitManagement, onDismiss: refreshUnits) {
            UnitManagementView(viewModel: viewModel)
        }
    }

    // MARK: - Nota

    private var noteSection: some View {
        VStack(spacing: 8) {
            TextField(
                "Deja aquí una nota, estado de ánimo...",
                text: $note,
                axis: .vertical
            )
            .oruInputSmall()
            .focused($focusedField, equals: .note)
            .onChange(of: note) { _, newValue in
                note = viewModel.clampNote(newValue)
            }
            .padding(16)
            .frame(minHeight: 160, alignment: .topLeading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))

            if let error = viewModel.lastError {
                Text(error)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Botón confirmar

    private var confirmButton: some View {
        Button {
            confirmTap.toggle()
            saveHabit()
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: 150)
                .padding(.vertical, 16)
                .background(
                    isValid ? Color.oruPrimary : Color.oruPrimary.opacity(0.4),
                    in: .rect(cornerRadius: 16)
                )
        }
        .disabled(!isValid || isSaving)
        .sensoryFeedback(.success, trigger: confirmTap)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Hint 66 días

    private var consolidationHint: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isEditing ? "heart" : "lightbulb.max")
                .font(.system(size: 11))
                .foregroundStyle(Color.oruPrimary)
            Text(isEditing
                 ? "Moldea este hábito a tu propio ritmo."
                 : "Este hábito se considerará consolidado y parte de tu identidad tras cumplirlo por 66 días.")
                .oruTip()
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Cargar unidades

    private func loadUnits() async {
        units = await viewModel.loadUnits()
        unitsLoaded = !units.isEmpty
        if selectedUnit == nil {
            selectedUnit = units.first { $0.name == UnitDto.defaultName }
        }
    }

    private func refreshUnits() {
        Task {
            units = await viewModel.loadUnits()
            unitsLoaded = !units.isEmpty
            if let selected = selectedUnit,
               !units.contains(where: { $0.id == selected.id }) {
                selectedUnit = units.first { $0.name == UnitDto.defaultName }
            }
        }
    }

    // MARK: - Guardar (creación o edición)

    private func saveHabit() {
        guard !isSaving else { return }
        isSaving = true
        viewModel.lastError = nil

        Task {
            let normalized = dailyGoal.replacingOccurrences(of: ",", with: ".")
            let goal = habitType == .quantity ? Double(normalized) : nil
            let unit = habitType == .quantity ? selectedUnit : nil
            let trimmedNote = note.trimmingCharacters(in: .whitespaces)
            let sortedDays = Array(selectedDays).sorted { $0.rawValue < $1.rawValue }

            if let habit = habitToEdit {
                let request = UpdateHabitRequest(
                    icon: icon,
                    name: name.trimmingCharacters(in: .whitespaces),
                    dailyGoal: goal,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    unitId: unit?.id,
                    scheduledDays: sortedDays
                )
                if await viewModel.updateHabit(habit, request: request) {
                    dismiss()
                } else {
                    isSaving = false
                }
            } else {
                let request = CreateHabitRequest(
                    icon: icon,
                    name: name.trimmingCharacters(in: .whitespaces),
                    type: habitType,
                    dailyGoal: goal,
                    note: trimmedNote.isEmpty ? nil : trimmedNote,
                    unitId: unit?.id,
                    scheduledDays: sortedDays
                )
                if await viewModel.createHabit(request) {
                    dismiss()
                } else {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Sección de días

private struct DaysSectionView: View {

    @Binding var selectedDays: Set<WeekDay>

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Text("¿Qué días quieres realizarlo?")
                .oruLabel()

            HStack(spacing: 8) {
                ForEach(WeekDay.allCases, id: \.self) { day in
                    dayPill(day)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func dayPill(_ day: WeekDay) -> some View {
        let isSelected = selectedDays.contains(day)
        return Button {
            if isSelected {
                selectedDays.remove(day)
            } else {
                selectedDays.insert(day)
            }
        } label: {
            Text(day.shortName)
                .oruPillCircle()
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 42, height: 42)
                .background(isSelected ? Color.oruPrimary : .clear, in: .circle)
        }
        .glassEffect(.regular, in: .circle)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Weekday nombres cortos para pills

extension WeekDay {
    var shortName: String {
        switch self {
        case .monday: "lun"
        case .tuesday: "mar"
        case .wednesday: "mie"
        case .thursday: "jue"
        case .friday: "vie"
        case .saturday: "sab"
        case .sunday: "dom"
        }
    }
}

// MARK: - Preview

#Preview(traits: .sampleData) {
    @Previewable @Environment(\.modelContext) var context
    let client = APIClient(tokenStore: TokenStore())
    let habitService = HabitService(client: client)
    let unitService = UnitService(client: client)
    HabitFormView(
        viewModel: HabitViewModel(
            repository: HabitRepository(modelContext: context),
            habitService: habitService,
            unitService: unitService
        )
    )
}
