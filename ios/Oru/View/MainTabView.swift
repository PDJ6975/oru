import SwiftUI
import SwiftData

struct MainTabView: View {

    let dependencies: AppDependencies

    @Environment(\.modelContext) private var modelContext
    @State private var gamificationVM: GamificationViewModel?
    @State private var habitVM: HabitViewModel?
    @State private var statsVM: StatsViewModel?
    @State private var timerVM: TimerViewModel?
    @State private var homeVM: HomeViewModel?

    var body: some View {
        TabView {
            Tab("Inicio", systemImage: "apple.homekit") {
                NavigationStack {
                    if let habitVM, let homeVM, let gamificationVM {
                        HomeView(gamificationVM: gamificationVM, habitVM: habitVM, homeVM: homeVM)
                    }
                }
                .oruDefaultTint()
            }

            Tab("Estadísticas", systemImage: "waveform.mid") {
                NavigationStack {
                    if let statsVM {
                        StatsView(viewModel: statsVM)
                    }
                }
                .oruDefaultTint()
            }

            Tab("Temporizador", systemImage: "tachometer") {
                Group {
                    if let timerVM {
                        TimerView(viewModel: timerVM)
                    }
                }
                .oruDefaultTint()
            }
        }
        .tint(Color.oruPrimary)
        .onAppear {
            if homeVM == nil {
                homeVM = HomeViewModel(
                    userService: dependencies.userService,
                    habitService: dependencies.habitService
                )
            }
            if gamificationVM == nil {
                gamificationVM = GamificationViewModel(
                    service: dependencies.origamiService
                )
            }
            if habitVM == nil {
                let hvm = HabitViewModel(
                    repository: HabitRepository(modelContext: modelContext),
                    habitService: dependencies.habitService,
                    unitService: dependencies.unitService
                )
                // Cualquier mutación requiere la reevaluación del progreso
                hvm.onHabitCreated = { [weak homeVM, weak gamificationVM] habit in
                    homeVM?.addCreatedHabit(habit)
                    Task { await gamificationVM?.load() }
                }
                hvm.onHabitDeleted = { [weak homeVM, weak gamificationVM] habit in
                    homeVM?.removeHabit(habit)
                    Task { await gamificationVM?.load() }
                }
                hvm.onHabitUpdated = { [weak homeVM, weak gamificationVM] habit in
                    homeVM?.updateHabit(habit)
                    Task { await gamificationVM?.load() }
                }
                hvm.onHabitArchived = { [weak homeVM, weak gamificationVM] habit in
                    homeVM?.removeHabit(habit)
                    Task { await gamificationVM?.load() }
                }
                hvm.onHabitToggled = { [weak homeVM, weak gamificationVM] habit in
                    homeVM?.replaceHabit(habit)
                    Task { await gamificationVM?.load() }
                }
                habitVM = hvm
            }
            if statsVM == nil {
                statsVM = StatsViewModel(
                    statsService: dependencies.statsService,
                    origamiService: dependencies.origamiService
                )
            }
            if timerVM == nil {
                let tvm = TimerViewModel(timerService: dependencies.timerService)
                timerVM = tvm
                Task { await tvm.recoverSessionIfNeeded() }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    MainTabView(dependencies: AppDependencies())
}
