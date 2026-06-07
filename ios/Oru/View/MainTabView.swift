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
                    if let habitVM, let homeVM {
                        HomeView(gamificationVM: $gamificationVM, habitVM: habitVM, homeVM: homeVM)
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
                homeVM = HomeViewModel(userService: dependencies.userService)
            }
            if gamificationVM == nil {
                let gvm = GamificationViewModel(
                    origamiRepository: OrigamiRepository(modelContext: modelContext)
                )
                gvm.loadOrigami()
                gamificationVM = gvm
            }
            if habitVM == nil {
                let hvm = HabitViewModel(
                    repository: HabitRepository(modelContext: modelContext)
                )
                hvm.onHabitChanged = { [weak gamificationVM] allCompleted in
                    gamificationVM?.updateDailyProgress(allCompleted: allCompleted)
                }
                habitVM = hvm
            }
            if statsVM == nil {
                statsVM = StatsViewModel(
                    repository: HabitRepository(modelContext: modelContext),
                    origamiRepository: OrigamiRepository(modelContext: modelContext)
                )
            }
            if timerVM == nil, let habitVM {
                let tvm = TimerViewModel(
                    repository: HabitRepository(modelContext: modelContext),
                    habitVM: habitVM
                )
                tvm.onSessionCompleted = { [weak gamificationVM] minutes in
                    gamificationVM?.applySessionBonus(durationMinutes: minutes)
                }
                timerVM = tvm
                Task { await tvm.recoverSessionIfNeeded() }
            }
        }
    }
}

#Preview(traits: .sampleData) {
    MainTabView(dependencies: AppDependencies())
}
