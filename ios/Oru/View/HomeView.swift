import SwiftUI
import SwiftData

struct HomeView: View {

    @Binding var gamificationVM: GamificationViewModel?
    @Bindable var habitVM: HabitViewModel
    @Bindable var homeVM: HomeViewModel
    var illustrationOverride: String?

    @State private var revealingName: String?
    @State private var revealOpacity: Double = 0
    @State private var imageOpacity: Double = 1
    @State private var showNextAlert = false
    @State private var trayDetent: HomeTrayDetent = .peek
    @State private var showCreateForm = false
    @State private var habitToEdit: HabitDto?
    @State private var habitToDelete: HabitDto?

    private var todayHabits: [HabitDto] { homeVM.todayHabits }

    private var otherHabits: [HabitDto] { homeVM.pausedHabits }

    private var hasNoHabits: Bool {
        todayHabits.isEmpty && otherHabits.isEmpty
    }

    private var breathingActive: Bool {
        (gamificationVM?.hasPendingReveal ?? false) && revealingName == nil
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            origamiHero

            HomeTray(detent: $trayDetent) {
                summaryHeader
            } content: {
                todaySection
                if !otherHabits.isEmpty {
                    pausedSection
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateForm = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            await homeVM.load()
        }
        .connectionErrorAlert(
            isPresented: $homeVM.connectionErrorPresented,
            onRetry: { Task { await homeVM.load() } }
        )
        .connectionErrorAlert(
            isPresented: $habitVM.connectionErrorPresented
        )
        .overlay(alignment: .topLeading) {
            Text("Hola, \(homeVM.userName)!")
                .font(.system(size: 24, weight: .regular, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(.secondary)
                .padding(.leading, 30)
                .padding(.top, -40)
        }
        .sheet(isPresented: $showCreateForm) {
            HabitFormView(viewModel: habitVM)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $habitToEdit) { habit in
            HabitFormView(viewModel: habitVM, habitToEdit: habit)
                .presentationDragIndicator(.visible)
        }
        .alert(
            "Eliminar hábito",
            isPresented: Binding(
                get: { habitToDelete != nil },
                set: { if !$0 { habitToDelete = nil } }
            )
        ) {
            Button("Eliminar", role: .destructive) {
                if let habit = habitToDelete {
                    Task {
                        await habitVM.deleteHabit(habit)
                    }
                }
            }
            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Se eliminará el hábito y todo su historial. Esta acción no se puede deshacer.")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { habitVM.lastError != nil },
                set: { if !$0 { habitVM.lastError = nil } }
            )
        ) {
            Button("Aceptar", role: .cancel) { }
        } message: {
            Text(habitVM.lastError ?? "")
        }
        .alert(
            "¡Hábito consolidado! 🎉",
            isPresented: Binding(
                get: { habitVM.consolidatedHabit != nil },
                set: { if !$0 { habitVM.consolidatedHabit = nil } }
            )
        ) {
            Button("Aceptar") {
                habitVM.consolidatedHabit = nil
            }
        } message: {
            if let habit = habitVM.consolidatedHabit {
                let intro = "¡Enhorabuena! \(habit.name) ya es parte de ti."
                let detail = "Puedes mantenerlo en tu día a día o, cuando sientas"
                    + " que ya no necesitas registrarlo,"
                    + " deslízalo para archivarlo en tus estadísticas."
                Text("\(intro) \(detail)")
            }
        }
        .alert("¡Figura completada!", isPresented: $showNextAlert) {
            Button("Comenzar") {
                withAnimation(.easeOut(duration: 0.8)) {
                    imageOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    gamificationVM?.completeAndAssignNext()
                    withAnimation(.easeIn(duration: 0.8)) {
                        imageOpacity = 1
                    }
                }
            }
            Button("Seguir disfrutando", role: .cancel) { }
        } message: {
            Text("¿Quieres guardar esta figura en tu colección y comenzar un nuevo origami?")
        }
    }

    // MARK: - Origami Hero

    private var origamiHero: some View {
        ZStack(alignment: .bottomTrailing) {
            origamiImage
                .frame(maxWidth: .infinity)

            Group {
                if let gvm = gamificationVM,
                   gvm.currentOrigami != nil,
                   gvm.isOrigamiCompleted,
                   gvm.hasNextOrigamiAvailable {
                    nextOrigamiButton
                        .transition(.opacity)
                        .padding(.trailing, 15)
                        .padding(.bottom, 350)
                }
            }
            .animation(.easeIn(duration: 0.5), value: gamificationVM?.isOrigamiCompleted)
        }
        .frame(height: 400)
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(todayDay())
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(todayWeekday())
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(gamificationVM?.progressPercentage ?? 0))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text("Realizado")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    // MARK: - Habit Sections

    private var todaySection: some View {
        Section {
            if hasNoHabits {
                noHabitsRow
            } else if todayHabits.isEmpty {
                todayEmptyRow
            } else {
                ForEach(todayHabits) { habit in
                    TodayHabitRow(habit: habit, viewModel: habitVM)
                        .oruConsolidationCard(
                            progress: habitVM.consolidationProgress(for: habit)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                habitToDelete = habit
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            .tint(.red)
                            Button {
                                habitToEdit = habit
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            .tint(.oruPrimary)
                            if habit.isConsolidated {
                                Button {
                                    Task {
                                        await habitVM.archiveHabit(habit)
                                    }
                                } label: {
                                    Label("Archivar", systemImage: "archivebox")
                                }
                                .tint(.orange)
                            }
                        }
                        .labelStyle(.iconOnly)
                }
            }
        } header: {
            Text("Para hoy")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .tracking(0.8)
                .listRowInsets(EdgeInsets(top: 8, leading: 6, bottom: 10, trailing: 20))
        }
    }

    private var pausedSection: some View {
        Section {
            ForEach(otherHabits) { habit in
                HabitRow(habit: habit, today: habitVM.currentWeekDay())
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button {
                            habitToDelete = habit
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                        .tint(.red)
                        Button {
                            habitToEdit = habit
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(.oruPrimary)
                    }
                    .labelStyle(.iconOnly)
            }
        } header: {
            Text("En pausa")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .tracking(0.8)
                .listRowInsets(EdgeInsets(top: 8, leading: 6, bottom: 10, trailing: 20))
        }
    }

    // MARK: - Origami Components

    @ViewBuilder
    private var origamiImage: some View {
        let currentName = illustrationOverride
            ?? gamificationVM?.currentIllustrationName
            ?? "mariposa"

        ZStack {
            Image(currentName)
                .resizable()
                .scaledToFit()

            if let nextName = revealingName {
                Image(nextName)
                    .resizable()
                    .scaledToFit()
                    .opacity(revealOpacity)
            }
        }
        .opacity(imageOpacity)
        .scaleEffect(breathingActive ? 1.05 : 1.0)
        .animation(
            breathingActive
                ? .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
                : .easeInOut(duration: 0.8),
            value: breathingActive
        )
        .onTapGesture {
            if gamificationVM?.hasPendingReveal == true {
                revealingName = gamificationVM?.nextIllustrationName
                withAnimation(.easeIn(duration: 2.5)) {
                    revealOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    gamificationVM?.revealNextPhase()
                    revealOpacity = 0
                    revealingName = nil
                }
            }
        }
    }

    private var nextOrigamiButton: some View {
        Button {
            showNextAlert = true
        } label: {
            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(width: 45, height: 45)
        .glassEffect(.regular, in: .circle)
    }

    // MARK: - Empty & Rest States

    private var noHabitsRow: some View {
        HStack(spacing: 10) {
            Text("👋🏼")
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                Text("Sin hábitos aún")
                    .oruTextPrimary()

                Text("Construye tu rutina creando tu primer hábito.")
                    .oruTextSecondary()
            }
        }
        .padding(.vertical, 8)
    }

    private var todayEmptyRow: some View {
        HStack(spacing: 10) {
            Text("😌")
                .font(.system(size: 22))

            VStack(alignment: .leading, spacing: 4) {
                Text("Día de descanso")
                    .oruTextPrimary()

                Text("Recarga energía y disfruta de tu tiempo.")
                    .oruTextSecondary()
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - TodayHabitRow

private struct TodayHabitRow: View {

    let habit: HabitDto
    var viewModel: HabitViewModel

    var body: some View {
        switch habit.type {
        case .boolean:
            BooleanHabitRow(habit: habit, viewModel: viewModel)
        case .quantity:
            QuantityHabitRow(habit: habit, viewModel: viewModel)
        }
    }
}

// MARK: - BooleanHabitRow

private struct BooleanHabitRow: View {

    let habit: HabitDto
    var viewModel: HabitViewModel

    private var isCompleted: Bool {
        viewModel.todayCompliance(for: habit)?.isCompleted ?? false
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await viewModel.toggleBoolean(for: habit) }
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(
                        isCompleted
                            ? Color.oruPrimary.opacity(0.8)
                            : Color.secondary.opacity(0.35)
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .sensoryFeedback(.success, trigger: isCompleted)
            }
            .buttonStyle(.plain)
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(habit.icon)
                        .font(.system(size: 16))

                    Text(habit.name)
                        .oruTextPrimary()
                        .lineLimit(1)
                        .strikethrough(isCompleted)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                }

                if let note = habit.note, !note.isEmpty {
                    Text(note)
                        .oruTextSecondary()
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QuantityHabitRow

private struct QuantityHabitRow: View {

    let habit: HabitDto
    var viewModel: HabitViewModel

    @State private var isEntering = false
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    private var todayCompliance: ComplianceDto? {
        viewModel.todayCompliance(for: habit)
    }

    private var hasRecordedAmount: Bool {
        todayCompliance?.recordedAmount != nil && todayCompliance?.recordedAmount != 0
    }

    private var isCompleted: Bool {
        todayCompliance?.isCompleted ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button {
                    if isEntering {
                        save()
                    } else {
                        inputText = (todayCompliance?.recordedAmount ?? 0).formatted
                        isEntering = true
                    }
                } label: {
                    Image(systemName: isEntering
                          ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(
                            isEntering || hasRecordedAmount
                                ? Color.oruPrimary.opacity(0.8)
                                : Color.secondary.opacity(0.35)
                        )
                        .contentTransition(.symbolEffect(.replace))
                        .sensoryFeedback(.success, trigger: hasRecordedAmount)
                }
                .buttonStyle(.plain)
                .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(habit.icon)
                            .font(.system(size: 16))

                        Text(habit.name)
                            .oruTextPrimary()
                            .lineLimit(1)
                            .strikethrough(isCompleted)
                            .foregroundStyle(isCompleted ? .secondary : .primary)
                    }

                    if let note = habit.note, !note.isEmpty {
                        Text(note)
                            .oruTextSecondary()
                            .lineLimit(1)
                    }
                }

                Spacer()

                progressLabel
            }
            .padding(.vertical, 4)

            if isEntering {
                HStack(spacing: 8) {
                    TextField("0", text: $inputText)
                        .keyboardType(.decimalPad)
                        .focused($isFocused)
                        .oruTextPrimary()
                        .onChange(of: inputText) { _, newValue in
                            inputText = String(newValue.prefix(Habit.maxGoalLength))
                        }

                    if let unit = habit.unit {
                        Text(unit.name)
                            .oruTextSecondary()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 10))
                .padding(.leading, 40)
                .task { isFocused = true }
            }
        }
        .animation(.easeOut(duration: 0.2), value: isEntering)
        .onChange(of: isFocused) { _, focused in
            if !focused && isEntering { isEntering = false }
        }
    }

    private func save() {
        let normalized = inputText.replacingOccurrences(of: ",", with: ".")
        let value = Double(normalized) ?? 0
        Task { await viewModel.recordAmount(value, for: habit) }
        isEntering = false
        isFocused = false
    }

    private var progressLabel: some View {
        let amount = (todayCompliance?.recordedAmount ?? 0).formatted
        let text: String

        if let goal = habit.dailyGoal {
            let suffix = habit.unit.map { " \($0.name)" } ?? ""
            text = "\(amount) / \(goal.formatted)\(suffix)"
        } else {
            text = habit.unit.map { "\(amount) \($0.name)" } ?? amount
        }

        return Text(text)
            .oruPillCircle()
            .foregroundStyle(
                hasRecordedAmount
                    ? Color.oruPrimary.opacity(0.8)
                    : Color.secondary.opacity(0.35)
            )
    }
}

// MARK: - HabitRow (En pausa)

private struct HabitRow: View {

    let habit: HabitDto
    let today: WeekDay

    var body: some View {
        HStack(spacing: 8) {
            Text(habit.icon)
                .font(.system(size: 19))
                .frame(width: 28)

            Text(habit.name)
                .oruTextPrimary()
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                ForEach(WeekDay.allCases, id: \.self) { day in
                    Text(day.shortLabel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(dayColor(day: day))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func dayColor(day: WeekDay) -> Color {
        guard habit.scheduledDays.contains(where: { $0.day == day }) else {
            return .secondary.opacity(0.3)
        }
        return day == today ? .oruPrimary : .primary
    }
}

// MARK: - Weekday Short Label

extension WeekDay {
    var shortLabel: String {
        switch self {
        case .monday: "L"
        case .tuesday: "M"
        case .wednesday: "X"
        case .thursday: "J"
        case .friday: "V"
        case .saturday: "S"
        case .sunday: "D"
        }
    }
}

// MARK: - Preview

#Preview(traits: .sampleData) {
    @Previewable @Environment(\.modelContext) var context
    HomePreview(context: context)
}

/// Contenedor de la preview: construye los view models a partir del `context`
/// inyectado en su `init` (no se puede hacer en el default de un `@Previewable`).
private struct HomePreview: View {
    private let context: ModelContext
    @State private var gamificationVM: GamificationViewModel?
    @State private var habitVM: HabitViewModel

    init(context: ModelContext) {
        self.context = context
        let client = APIClient(tokenStore: TokenStore())
        _habitVM = State(initialValue: HabitViewModel(
            repository: HabitRepository(modelContext: context),
            habitService: HabitService(client: client),
            unitService: UnitService(client: client)
        ))
    }

    var body: some View {
        let client = APIClient(tokenStore: TokenStore())
        NavigationStack {
            HomeView(
                gamificationVM: $gamificationVM,
                habitVM: habitVM,
                homeVM: HomeViewModel(
                    userService: UserService(client: client),
                    habitService: HabitService(client: client)
                )
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        guard let gvm = gamificationVM,
                              let userOrigami = gvm.currentOrigami else { return }
                        userOrigami.progressPercentage = gvm.nextPhaseThreshold ?? 100
                    } label: {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .onAppear {
            let gvm = GamificationViewModel(
                origamiRepository: OrigamiRepository(modelContext: context)
            )
            gvm.loadOrigami()
            gamificationVM = gvm
        }
    }
}
